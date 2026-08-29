const fs = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const kms = require('../kms');
const config = require('../../config/env');

const VAULT_DIR = path.resolve(config.localStoragePath);

// Ensure vault directory exists
if (!fs.existsSync(VAULT_DIR)) {
  fs.mkdirSync(VAULT_DIR, { recursive: true });
}

/**
 * Store raw data object encrypted on disk.
 * Returns the vault key (filename without directory) to be saved in Postgres.
 */
function store(data) {
  const key = `${uuidv4()}.vault`;
  const plaintext = JSON.stringify(data);
  const encrypted = kms.encrypt(plaintext);
  fs.writeFileSync(path.join(VAULT_DIR, key), encrypted, 'utf8');
  return key;
}

/**
 * Retrieve and decrypt data by vault key.
 */
function retrieve(key) {
  const filePath = path.join(VAULT_DIR, key);
  if (!fs.existsSync(filePath)) {
    throw Object.assign(new Error('Vault entry not found'), { status: 404 });
  }
  const encrypted = fs.readFileSync(filePath, 'utf8');
  const plaintext = kms.decrypt(encrypted);
  return JSON.parse(plaintext);
}

/**
 * Delete a vault entry.
 */
function remove(key) {
  const filePath = path.join(VAULT_DIR, key);
  if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
}

module.exports = { store, retrieve, remove };
