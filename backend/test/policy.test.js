const test = require('node:test');
const assert = require('node:assert/strict');
const {DHIKR, hash, sameSecret, partner, availableCode, validCode} = require('../policy');
test('exact seven notification bodies without sender or heart', () => {
  assert.equal(DHIKR.length, 7);
  assert.equal(DHIKR[0], 'استغفر الله');
  assert.ok(DHIKR.every(s => !s.includes('❤️')));
});
test('only members can address their one partner', () => {
  assert.equal(partner({members: ['a', 'b']}, 'a'), 'b');
  assert.equal(partner({members: ['a', 'b']}, 'b'), 'a');
  assert.equal(partner({members: ['a', 'b']}, 'c'), null);
  assert.equal(partner({members: ['a']}, 'a'), null);
});
test('reject expired, consumed, malformed and incorrect pairing codes', () => {
  const p = {members: ['a'], codeHash: hash('123456'), expiresAt: 200};
  assert.ok(availableCode(p, '123456', 100));
  assert.ok(!availableCode(p, '123456', 200));
  assert.ok(!availableCode({...p, members: ['a', 'b']}, '123456', 100));
  assert.ok(!availableCode(p, '999999', 100));
  assert.ok(!validCode(123456));
  assert.ok(!validCode('1234567'));
});
test('private installation key requires exact match and minimum length', () => {
  assert.ok(sameSecret('abcdefghijklmnop', 'abcdefghijklmnop'));
  assert.ok(!sameSecret('bad', 'abcdefghijklmnop'));
  assert.ok(!sameSecret('short', 'short'));
  assert.ok(!sameSecret(null, 'abcdefghijklmnop'));
});
