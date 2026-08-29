const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const { v4: uuidv4 } = require('uuid');
const { pgPool } = require('../config/db');
const { redis } = require('../config/db');
const config = require('../config/env');
const audit = require('../services/audit');

const SALT_ROUNDS = 12;

// ─── Helpers ──────────────────────────────────────────────────────────────────
function generateAccessToken(user) {
  return jwt.sign(
    { sub: user.id, phone: user.phone, borrower_type: user.borrower_type },
    config.jwtSecret,
    { expiresIn: config.jwtAccessExpiry }
  );
}

function generateRefreshToken(user) {
  return jwt.sign(
    { sub: user.id, type: 'refresh' },
    config.jwtRefreshSecret,
    { expiresIn: config.jwtRefreshExpiry }
  );
}

async function hashToken(token) {
  return bcrypt.hash(token, 10);
}

async function storeRefreshToken(userId, token) {
  const tokenHash = await hashToken(token);
  const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30 days
  await pgPool.query(
    `INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, $3)`,
    [userId, tokenHash, expiresAt]
  );
}

// ─── POST /v1/auth/register ──────────────────────────────────────────────────
async function register(req, res, next) {
  try {
    const { phone, email, full_name, password, borrower_type } = req.body;

    if (!phone) return res.status(400).json({ error: 'phone is required' });
    if (!password) return res.status(400).json({ error: 'password is required' });

    // Check duplicate
    const exists = await pgPool.query('SELECT id FROM users WHERE phone = $1', [phone]);
    if (exists.rows.length > 0) {
      return res.status(409).json({ error: 'User with this phone already exists' });
    }

    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);

    const result = await pgPool.query(
      `INSERT INTO users (phone, email, full_name, password_hash, borrower_type)
       VALUES ($1, $2, $3, $4, $5) RETURNING id, phone, email, full_name, borrower_type, created_at`,
      [phone, email || null, full_name || null, passwordHash, borrower_type || 'individual']
    );
    const user = result.rows[0];

    const accessToken  = generateAccessToken(user);
    const refreshToken = generateRefreshToken(user);
    await storeRefreshToken(user.id, refreshToken);

    await audit.log({ user_id: user.id, action: 'AUTH_REGISTER', resource: 'users', metadata: { phone } });

    return res.status(201).json({
      message: 'User registered successfully',
      access_token: accessToken,
      refresh_token: refreshToken,
      user: { id: user.id, phone: user.phone, email: user.email, full_name: user.full_name, borrower_type: user.borrower_type },
    });
  } catch (err) {
    next(err);
  }
}

// ─── POST /v1/auth/login ─────────────────────────────────────────────────────
async function login(req, res, next) {
  try {
    const { phone, password } = req.body;

    if (!phone || !password) {
      return res.status(400).json({ error: 'phone and password are required' });
    }

    const result = await pgPool.query(
      'SELECT id, phone, email, full_name, borrower_type, password_hash FROM users WHERE phone = $1',
      [phone]
    );
    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const user = result.rows[0];
    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // OTP stub: log to console in sandbox/dev mode (no real SMS needed for demo)
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    console.log(`[OTP STUB] OTP for ${phone}: ${otp}  (sandbox mode — not sent via SMS)`);
    // Cache OTP in Redis for 5 minutes
    await redis.set(`otp:${phone}`, otp, 'EX', 300);

    const accessToken  = generateAccessToken(user);
    const refreshToken = generateRefreshToken(user);
    await storeRefreshToken(user.id, refreshToken);

    await audit.log({ user_id: user.id, action: 'AUTH_LOGIN', resource: 'users', metadata: { phone } });

    return res.json({
      access_token: accessToken,
      refresh_token: refreshToken,
      user: { id: user.id, phone: user.phone, email: user.email, full_name: user.full_name, borrower_type: user.borrower_type },
    });
  } catch (err) {
    next(err);
  }
}

// ─── POST /v1/auth/refresh ───────────────────────────────────────────────────
async function refresh(req, res, next) {
  try {
    const { refresh_token } = req.body;
    if (!refresh_token) return res.status(400).json({ error: 'refresh_token is required' });

    let payload;
    try {
      payload = jwt.verify(refresh_token, config.jwtRefreshSecret);
    } catch {
      return res.status(401).json({ error: 'Invalid or expired refresh token' });
    }

    if (payload.type !== 'refresh') {
      return res.status(401).json({ error: 'Invalid token type' });
    }

    // Find stored token hash
    const stored = await pgPool.query(
      `SELECT id, token_hash FROM refresh_tokens
       WHERE user_id = $1 AND revoked = false AND expires_at > NOW()`,
      [payload.sub]
    );
    if (stored.rows.length === 0) {
      return res.status(401).json({ error: 'Refresh token not found or revoked' });
    }

    // Verify hash
    const matched = await Promise.any(
      stored.rows.map((r) => bcrypt.compare(refresh_token, r.token_hash).then((ok) => (ok ? r.id : Promise.reject())))
    ).catch(() => null);

    if (!matched) return res.status(401).json({ error: 'Refresh token mismatch' });

    // Rotate: revoke old, issue new
    await pgPool.query('UPDATE refresh_tokens SET revoked = true WHERE id = $1', [matched]);

    const userResult = await pgPool.query(
      'SELECT id, phone, email, full_name, borrower_type FROM users WHERE id = $1',
      [payload.sub]
    );
    if (userResult.rows.length === 0) return res.status(401).json({ error: 'User not found' });

    const user = userResult.rows[0];
    const newAccessToken  = generateAccessToken(user);
    const newRefreshToken = generateRefreshToken(user);
    await storeRefreshToken(user.id, newRefreshToken);

    return res.json({ access_token: newAccessToken, refresh_token: newRefreshToken });
  } catch (err) {
    next(err);
  }
}

// ─── POST /v1/auth/logout ────────────────────────────────────────────────────
async function logout(req, res, next) {
  try {
    const { refresh_token } = req.body;
    if (!refresh_token) return res.status(400).json({ error: 'refresh_token is required' });

    let payload;
    try {
      payload = jwt.verify(refresh_token, config.jwtRefreshSecret);
    } catch {
      return res.status(400).json({ error: 'Invalid refresh token' });
    }

    // Revoke all refresh tokens for this user (full logout)
    await pgPool.query(
      'UPDATE refresh_tokens SET revoked = true WHERE user_id = $1 AND revoked = false',
      [payload.sub]
    );

    await audit.log({ user_id: payload.sub, action: 'AUTH_LOGOUT', resource: 'users' });

    return res.json({ message: 'Logged out successfully' });
  } catch (err) {
    next(err);
  }
}

module.exports = { register, login, refresh, logout };
