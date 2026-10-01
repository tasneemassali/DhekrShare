const {createHash, timingSafeEqual} = require('node:crypto');
const DHIKR = Object.freeze([
  'استغفر الله', 'الحمد لله', 'سبحان الله', 'لا إله إلا الله',
  'الله أكبر', 'لا حول ولا قوة إلا بالله', 'اللهم صلِّ وسلم على نبينا محمد'
]);
const hash = value => createHash('sha256').update(value).digest('hex');
function sameSecret(a, b) {
  return typeof a === 'string' && typeof b === 'string' && b.length >= 16 &&
    timingSafeEqual(Buffer.from(hash(a)), Buffer.from(hash(b)));
}
function partner(pair, uid) {
  if (!pair || !Array.isArray(pair.members) || pair.members.length !== 2 || !pair.members.includes(uid)) return null;
  return pair.members.find(id => id !== uid) || null;
}
function validCode(code) { return typeof code === 'string' && /^\d{6}$/.test(code); }
function availableCode(pair, code, now) {
  return pair && Array.isArray(pair.members) && pair.members.length === 1 && pair.expiresAt > now &&
    validCode(code) && pair.codeHash === hash(code);
}
module.exports = {DHIKR, hash, sameSecret, partner, validCode, availableCode};
