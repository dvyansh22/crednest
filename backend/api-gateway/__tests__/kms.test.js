/**
 * Unit tests for KMS service (AES-256-GCM encrypt/decrypt)
 * No DB or external calls needed.
 */
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
// Override with test-safe values
process.env.ENCRYPTION_KEY = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

const kms = require('../src/services/kms');

describe('KMS Service', () => {
  test('encrypts and decrypts a string successfully', () => {
    const plaintext = 'Hello CredNest!';
    const encrypted = kms.encrypt(plaintext);
    expect(encrypted).not.toBe(plaintext);
    const decrypted = kms.decrypt(encrypted);
    expect(decrypted).toBe(plaintext);
  });

  test('encrypts a JSON object', () => {
    const data = { account: 'XXXXXXXX1234', balance: 45000 };
    const plaintext = JSON.stringify(data);
    const encrypted = kms.encrypt(plaintext);
    const decrypted = JSON.parse(kms.decrypt(encrypted));
    expect(decrypted.balance).toBe(45000);
  });

  test('two encryptions of same plaintext produce different ciphertext (IV randomization)', () => {
    const plaintext = 'same-text';
    const enc1 = kms.encrypt(plaintext);
    const enc2 = kms.encrypt(plaintext);
    expect(enc1).not.toBe(enc2);
    expect(kms.decrypt(enc1)).toBe(plaintext);
    expect(kms.decrypt(enc2)).toBe(plaintext);
  });

  test('throws on tampered ciphertext', () => {
    const encrypted = kms.encrypt('secret');
    const tampered = encrypted.slice(0, -4) + 'XXXX';
    expect(() => kms.decrypt(tampered)).toThrow();
  });
});
