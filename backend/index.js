const {initializeApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {getMessaging} = require('firebase-admin/messaging');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {defineSecret} = require('firebase-functions/params');
const {randomInt} = require('node:crypto');
const {DHIKR, hash, sameSecret, partner, validCode, availableCode} = require('./policy');
initializeApp();
const db = getFirestore();
const pairRef = db.doc('private/pair');
const setupKey = defineSecret('PAIRING_SETUP_KEY');
const options = {region: 'us-central1', enforceAppCheck: true, maxInstances: 2};
const fail = (code, message) => { throw new HttpsError(code, message); };
function uidOf(request) {
  if (!request.auth) fail('unauthenticated', 'Device authentication required.');
  return request.auth.uid;
}
// Persistent, transactional rate limits also count failed pairing attempts.
async function limit(uid, action, interval) {
  const ref = db.doc(`limits/${uid}_${action}`);
  await db.runTransaction(async tx => {
    const snap = await tx.get(ref);
    const now = Date.now();
    if (now - (snap.data()?.at || 0) < interval) fail('resource-exhausted', 'Please wait before trying again.');
    tx.set(ref, {at: now});
  });
}
exports.createPair = onCall({...options, secrets: [setupKey]}, async request => {
  const uid = uidOf(request);
  await limit(uid, 'create', 10000);
  // An out-of-band setup key prevents anyone else claiming the private installation.
  if (!sameSecret(request.data?.setupKey, setupKey.value())) fail('permission-denied', 'Invalid setup key.');
  const code = String(randomInt(100000, 1000000));
  await db.runTransaction(async tx => {
    const pair = (await tx.get(pairRef)).data();
    if (pair && (pair.members[0] !== uid || pair.members.length === 2)) {
      fail('failed-precondition', 'This installation already has its two devices or another owner.');
    }
    tx.set(pairRef, {members: [uid], codeHash: hash(code), expiresAt: Date.now() + 10 * 60000});
  });
  return {code, expiresIn: 600};
});
exports.joinPair = onCall(options, async request => {
  const uid = uidOf(request);
  await limit(uid, 'join', 10000);
  // Global throttle limits guessing even across fresh anonymous accounts.
  await limit('global', 'join', 3000);
  const code = request.data?.code;
  if (!validCode(code)) fail('invalid-argument', 'Use six digits.');
  await db.runTransaction(async tx => {
    const pair = (await tx.get(pairRef)).data();
    if (pair?.members.includes(uid)) {
      if (pair.members.length === 2) return; // Safe retry after a lost response.
      fail('failed-precondition', 'Use the other iPhone.');
    }
    if (!availableCode(pair, code, Date.now())) fail('failed-precondition', 'Invalid, expired, or used code.');
    tx.set(pairRef, {members: [...pair.members, uid], expiresAt: 0});
  });
  return {paired: true};
});
exports.pairStatus = onCall(options, async request => {
  const uid = uidOf(request);
  await limit(uid, 'status', 1000);
  const pair = (await pairRef.get()).data();
  return {paired: !!partner(pair, uid)}; // Never expose identifiers or tokens.
});
exports.registerToken = onCall(options, async request => {
  const uid = uidOf(request);
  const token = request.data?.token;
  if (typeof token !== 'string' || token.length < 20 || token.length > 4096) fail('invalid-argument', 'Invalid token.');
  await db.runTransaction(async tx => {
    const pair = (await tx.get(pairRef)).data();
    if (!pair?.members.includes(uid)) fail('permission-denied', 'Pair this device first.');
    tx.set(db.doc(`devices/${uid}`), {token});
  });
  return {registered: true};
});
exports.sendDhikr = onCall(options, async request => {
  const uid = uidOf(request);
  const id = request.data?.dhikrID;
  if (!Number.isInteger(id) || !DHIKR[id]) fail('invalid-argument', 'Unknown dhikr.');
  const token = await db.runTransaction(async tx => {
    const pair = (await tx.get(pairRef)).data();
    const other = partner(pair, uid);
    if (!other) fail('failed-precondition', 'Pair both devices first.');
    const rateRef = db.doc(`limits/${uid}_send`);
    const [device, rate] = await Promise.all([tx.get(db.doc(`devices/${other}`)), tx.get(rateRef)]);
    if (!device.data()?.token) fail('failed-precondition', 'Other device must enable notifications and open the app.');
    if (Date.now() - (rate.data()?.at || 0) < 2000) fail('resource-exhausted', 'Please wait.');
    tx.set(rateRef, {at: Date.now()});
    return device.data().token;
  });
  try {
    await getMessaging().send({token, notification: {title: 'تذكير ❤️', body: DHIKR[id]},
      apns: {headers: {'apns-push-type': 'alert', 'apns-priority': '10',
        'apns-expiration': String(Math.floor(Date.now() / 1000) + 3600)}, payload: {aps: {sound: 'default'}}}});
  } catch (_) {
    // Do not log private tokens; do not retry an ambiguous send automatically.
    fail('unavailable', 'Notification could not be accepted. Open the app on both devices and try again.');
  }
  return {accepted: true}; // Acceptance by FCM is not a delivery receipt.
});
