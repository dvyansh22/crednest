const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../../../.env') });
const { Pool } = require('pg');

async function runMigrations() {
  const pool = new Pool({ connectionString: process.env.DATABASE_URL });
  try {
    const sql = fs.readFileSync(path.join(__dirname, '001_init.sql'), 'utf8');
    await pool.query(sql);
    console.log('[Migration] 001_init.sql applied successfully');
  } catch (err) {
    console.error('[Migration] Failed:', err.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

runMigrations();
