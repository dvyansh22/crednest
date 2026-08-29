const { redis } = require('../config/db');

/**
 * Redis-backed sliding window rate limiter.
 *
 * @param {object} opts
 * @param {number} opts.windowMs   - Window in milliseconds (default: 60_000 = 1 min)
 * @param {number} opts.max        - Max requests per window (default: 100)
 * @param {string} opts.keyPrefix  - Redis key prefix (default: 'rl')
 * @param {Function} opts.keyFn    - Custom key function (req) => string. Default: IP + path
 */
function rateLimiter({ windowMs = 60_000, max = 100, keyPrefix = 'rl', keyFn } = {}) {
  const windowSec = Math.ceil(windowMs / 1000);

  return async (req, res, next) => {
    try {
      const identifier = keyFn ? keyFn(req) : `${req.ip}:${req.path}`;
      const key = `${keyPrefix}:${identifier}`;

      const current = await redis.incr(key);
      if (current === 1) {
        // First request — set expiry
        await redis.expire(key, windowSec);
      }

      const ttl = await redis.ttl(key);
      res.set({
        'X-RateLimit-Limit': max,
        'X-RateLimit-Remaining': Math.max(0, max - current),
        'X-RateLimit-Reset': Math.floor(Date.now() / 1000) + ttl,
      });

      if (current > max) {
        return res.status(429).json({
          error: 'Too many requests',
          retry_after_seconds: ttl,
        });
      }
      next();
    } catch (err) {
      // Rate limiter failure must not block requests
      console.error('[RateLimit] Redis error, bypassing:', err.message);
      next();
    }
  };
}

// Pre-built limiters for common scenarios
const authLimiter = rateLimiter({
  windowMs: 15 * 60 * 1000, // 15 min
  max: 20,
  keyPrefix: 'rl:auth',
  keyFn: (req) => req.ip,
});

const apiLimiter = rateLimiter({
  windowMs: 60 * 1000, // 1 min
  max: 120,
  keyPrefix: 'rl:api',
  keyFn: (req) => req.user?.id || req.ip,
});

const scoreLimiter = rateLimiter({
  windowMs: 60 * 1000, // 1 min
  max: 5,
  keyPrefix: 'rl:score',
  keyFn: (req) => req.user?.id || req.ip,
});

module.exports = { rateLimiter, authLimiter, apiLimiter, scoreLimiter };
