// Exercise actual callable handlers against an atomic in-memory Firestore double.
// Firebase Auth/App Check middleware and real APNs still require integration testing.
const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
function harness() {
  const data = new Map();
  const sends = [];
  let clock = 100000;
  let lock = Promise.resolve();
  let failSend = false;
  const snapshot = path => ({data: () => data.get(path)});
  const db = {
    doc: path => ({path, get: async () => snapshot(path)}),
    runTransaction: work => {
      const result = lock.then(async () => {
        const pending = [];
        const answer = await work({get: async ref => snapshot(ref.path), set: (ref, value) => pending.push([ref.path, value])});
        pending.forEach(([path,value]) => data.set(path,value));
        return answer;
      });
      lock = result.catch(() => {});
      return result;
    }
  };
  class HttpsError extends Error { constructor(code,message) { super(message); this.code=code; } }
  const modules = {
    'firebase-admin/app': {initializeApp() {}},
    'firebase-admin/firestore': {getFirestore: () => db},
    'firebase-admin/messaging': {getMessaging: () => ({send: async msg => {
      if (failSend) throw new Error('FCM unavailable');
      sends.push(msg); return 'message-id';
    }})},
    'firebase-functions/v2/https': {HttpsError, onCall: (options, handler) => {
      assert.equal(options.enforceAppCheck,true); return handler;
    }},
    'firebase-functions/params': {defineSecret: () => ({value: () => 'private-setup-key-at-least-32-characters'})},
    'node:crypto': require('node:crypto'), './policy': require('../policy')
  };
  const context = {exports: {}, require: name => modules[name], Date: {now: () => clock}};
  vm.runInNewContext(fs.readFileSync(require.resolve('../index'), 'utf8'), context);
  return {api:context.exports, data,sends, tick: () => {clock+=11000;}, fail: () => {failSend=true;},
    req: (uid,payload={}) => ({auth: uid ? {uid} : null,data:payload})};
}
test('private setup, single-use pairing, third-device denial and token isolation', async () => {
  const h=harness(), {api,req}=h;
  await assert.rejects(api.createPair(req(null)), {code:'unauthenticated'});
  await assert.rejects(api.createPair(req('stranger',{setupKey:'wrong'})), {code:'permission-denied'});
  const {code}=await api.createPair(req('a',{setupKey:'private-setup-key-at-least-32-characters'}));
  assert.match(code,/^\d{6}$/);
  await assert.rejects(api.registerToken(req('stranger',{token:'s'.repeat(30)})),{code:'permission-denied'});
  const joins = await Promise.allSettled([api.joinPair(req('b',{code})),api.joinPair(req('c',{code}))]);
  assert.equal(joins.filter(r=>r.status==='fulfilled').length,1);
  assert.equal(h.data.get('private/pair').members.length,2);
  assert.equal(h.data.get('private/pair').codeHash,undefined);
  h.tick();
  await assert.rejects(api.joinPair(req('d',{code})),{code:'failed-precondition'});
  assert.equal((await api.pairStatus(req('stranger'))).paired,false);
});
test('recipient routing, exact payload, simultaneous send cooldown and failure reporting', async () => {
  const h=harness(), {api,req}=h;
  h.data.set('private/pair',{members:['a','b']});
  await api.registerToken(req('a',{token:'a'.repeat(30)}));
  await api.registerToken(req('b',{token:'b'.repeat(30)}));
  await assert.rejects(api.sendDhikr(req('outsider',{dhikrID:0})),{code:'failed-precondition'});
  await assert.rejects(api.sendDhikr(req('a',{dhikrID:99})),{code:'invalid-argument'});
  const results=await Promise.allSettled([api.sendDhikr(req('a',{dhikrID:1})),api.sendDhikr(req('a',{dhikrID:1}))]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  assert.equal(h.sends.length,1);
  assert.equal(h.sends[0].token,'b'.repeat(30));
  assert.equal(h.sends[0].notification.title,'تذكير ❤️');
  assert.equal(h.sends[0].notification.body,'الحمد لله');
  await api.sendDhikr(req('b',{dhikrID:0}));
  assert.equal(h.sends[1].token,'a'.repeat(30));
  h.tick(); h.fail();
  await assert.rejects(api.sendDhikr(req('a',{dhikrID:0})),{code:'unavailable'});
});
