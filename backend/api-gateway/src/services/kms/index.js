const crypto = require('crypto');
const config = require('../../config/env');

const ALGORITHM = 'aes-256-gcm';
// Key must be 32 bytes (64 hex chars)
const KEY = Buffer.from(config.encryptionKey, 'hex');

/**
 * Encrypts plaintext string.
 * Returns base64-encoded: iv (12 bytes) + authTag (16 bytes) + ciphertext
 */
function encrypt(plaintext) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv(ALGORITHM, KEY, iv);
  const encrypted = Buffer.concat([
    cipher.update(plaintext, 'utf8'),
    cipher.final(),
  ]);
  const authTag = cipher.getAuthTag();
  // Combine: [iv(12)][authTag(16)][ciphertext]
  const combined = Buffer.concat([iv, authTag, encrypted]);
  return combined.toString('base64');
}

/**
 * Decrypts base64-encoded payload produced by encrypt().
 */
function decrypt(base64Payload) {
  const combined = Buffer.from(base64Payload, 'base64');
  const iv       = combined.slice(0, 12);
  const authTag  = combined.slice(12, 28);
  const ciphertext = combined.slice(28);

  const decipher = crypto.createDecipheriv(ALGORITHM, KEY, iv);
  decipher.setAuthTag(authTag);
  const decrypted = Buffer.concat([
    decipher.update(ciphertext),
    decipher.final(),
  ]);
  return decrypted.toString('utf8');
}

module.exports = { encrypt, decrypt };
