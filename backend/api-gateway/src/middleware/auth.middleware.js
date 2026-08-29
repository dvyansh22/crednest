const jwt = require('jsonwebtoken');
const config = require('../config/env');

/**
 * Authentication middleware — verifies JWT access token.
 * Attaches decoded user payload to req.user.
 */
function authenticate(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid Authorization header' });
  }

  const token = authHeader.slice(7);
  try {
    const payload = jwt.verify(token, config.jwtSecret);
    req.user = {
      id:            payload.sub,
      phone:         payload.phone,
      borrower_type: payload.borrower_type,
    };
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Access token expired' });
    }
    return res.status(401).json({ error: 'Invalid access token' });
  }
}

module.exports = { authenticate };
