const { Pool } = require('pg');
const mongoose = require('mongoose');
const Redis = require('ioredis');
const config = require('./env');

// ─── PostgreSQL ──────────────────────────────────────────────────────────────
const pgPool = new Pool({
  connectionString: config.databaseUrl,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

pgPool.on('error', (err) => {
  console.error('[Postgres] Unexpected client error:', err.message);
});

async function connectPostgres() {
  const client = await pgPool.connect();
  await client.query('SELECT 1');
  client.release();
  console.log('[Postgres] Connected');
}

// ─── MongoDB ─────────────────────────────────────────────────────────────────
async function connectMongo() {
  await mongoose.connect(config.mongoUrl, {
    serverSelectionTimeoutMS: 5000,
  });
  console.log('[MongoDB] Connected');
}

mongoose.connection.on('error', (err) => {
  console.error('[MongoDB] Connection error:', err.message);
});

// ─── Redis ────────────────────────────────────────────────────────────────────
const redis = new Redis(config.redisUrl, {
  lazyConnect: true,
  maxRetriesPerRequest: 3,
  enableReadyCheck: true,
  retryStrategy: (times) => Math.min(times * 200, 3000),
});

redis.on('error', (err) => {
  console.error('[Redis] Connection error:', err.message);
});

redis.on('connect', () => console.log('[Redis] Connected'));

async function connectRedis() {
  await redis.connect();
}

module.exports = {
  pgPool,
  connectPostgres,
  connectMongo,
  connectRedis,
  redis,
};
