require('dotenv').config();

const required = [
  'DATABASE_URL',
  'MONGO_URL',
  'REDIS_URL',
  'JWT_SECRET',
  'JWT_REFRESH_SECRET',
  'ENCRYPTION_KEY',
];

const missing = required.filter((k) => !process.env[k]);
if (missing.length > 0) {
  console.error(`[Config] Missing required env vars: ${missing.join(', ')}`);
  process.exit(1);
}

module.exports = {
  port: parseInt(process.env.PORT || '4000', 10),
  nodeEnv: process.env.NODE_ENV || 'development',

  // Databases
  databaseUrl: process.env.DATABASE_URL,
  mongoUrl: process.env.MONGO_URL,
  redisUrl: process.env.REDIS_URL,

  // Kafka
  kafkaBrokers: (process.env.KAFKA_BROKERS || 'localhost:9092').split(','),
  kafkaClientId: process.env.KAFKA_CLIENT_ID || 'crednest-api-gateway',
  kafkaGroupId: process.env.KAFKA_GROUP_ID || 'crednest-gateway-group',

  // JWT
  jwtSecret: process.env.JWT_SECRET,
  jwtRefreshSecret: process.env.JWT_REFRESH_SECRET,
  jwtAccessExpiry: process.env.JWT_ACCESS_EXPIRY || '15m',
  jwtRefreshExpiry: process.env.JWT_REFRESH_EXPIRY || '30d',

  // Encryption
  encryptionKey: process.env.ENCRYPTION_KEY,
  localStoragePath: process.env.LOCAL_STORAGE_PATH || './vault_storage',

  // Setu AA
  setuAA: {
    baseUrl: process.env.SETU_AA_BASE_URL || 'https://fiu-sandbox.setu.co',
    clientId: process.env.SETU_AA_CLIENT_ID || '',
    clientSecret: process.env.SETU_AA_CLIENT_SECRET || '',
    productInstanceId: process.env.SETU_AA_PRODUCT_INSTANCE_ID || '',
  },

  // Setu GST
  setuGST: {
    baseUrl: process.env.SETU_GST_BASE_URL || 'https://gst-sandbox.setu.co',
    clientId: process.env.SETU_GST_CLIENT_ID || '',
    clientSecret: process.env.SETU_GST_CLIENT_SECRET || '',
  },

  // Setu DigiLocker
  setuDigiLocker: {
    baseUrl: process.env.SETU_DIGILOCKER_BASE_URL || 'https://dg-sandbox.setu.co',
    clientId: process.env.SETU_DIGILOCKER_CLIENT_ID || '',
    clientSecret: process.env.SETU_DIGILOCKER_CLIENT_SECRET || '',
  },

  // ML Service
  mlServiceUrl: process.env.ML_SERVICE_URL || 'http://localhost:8000',
  useMockMlService: process.env.USE_MOCK_ML_SERVICE === 'true',

  // OCEN
  useMockOcen: process.env.USE_MOCK_OCEN !== 'false',

  // KMS
  kmsKeyId: process.env.KMS_KEY_ID || null,
};
