const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');

// Routes
const authRoutes       = require('./routes/auth.routes');
const consentRoutes    = require('./routes/consent.routes');
const onboardingRoutes = require('./routes/onboarding.routes');
const aaRoutes         = require('./routes/aa.routes');
const gstRoutes        = require('./routes/gst.routes');
const scoreRoutes      = require('./routes/score.routes');
const quizRoutes       = require('./routes/quiz.routes');
const ocenRoutes       = require('./routes/ocen.routes');
const webhookRoutes    = require('./routes/webhooks.routes');
const ledgerRoutes     = require('./routes/ledger.routes');
const mlRoutes         = require('./routes/ml.routes');

const app = express();

// ─── Security & Parsing ──────────────────────────────────────────────────────
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));

// ─── Health Check ────────────────────────────────────────────────────────────
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'crednest-api-gateway', ts: new Date().toISOString() });
});

// ─── API Routes ──────────────────────────────────────────────────────────────
app.use('/v1/auth',        authRoutes);
app.use('/v1/consent',     consentRoutes);
app.use('/v1/onboarding',  onboardingRoutes);
app.use('/v1/aa',          aaRoutes);
app.use('/v1/gst',         gstRoutes);
app.use('/v1/score',       scoreRoutes);
app.use('/v1/quiz',        quizRoutes);
app.use('/v1/loans',       ocenRoutes);
app.use('/v1/webhooks',    webhookRoutes);
app.use('/v1/ledger',      ledgerRoutes);

// ML Routes from ml-alt-credit-model branch
app.use('/ml',             mlRoutes);

// ─── 404 Handler ─────────────────────────────────────────────────────────────
app.use((_req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// ─── Global Error Handler ─────────────────────────────────────────────────────
app.use((err, _req, res, _next) => {
  console.error('[Error]', err.message, err.stack);
  const status = err.status || err.statusCode || 500;
  res.status(status).json({
    error: err.message || 'Internal server error',
    ...(process.env.NODE_ENV !== 'production' && { stack: err.stack }),
  });
});

module.exports = app;
