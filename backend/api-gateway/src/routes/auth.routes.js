const express = require('express');
const router = express.Router();
const { register, login, refresh, logout } = require('../controllers/auth.controller');
const { validate, schemas } = require('../middleware/validate.middleware');
const { authLimiter } = require('../middleware/rate-limit.middleware');

// POST /v1/auth/register
router.post('/register', authLimiter, validate({ body: schemas.registerSchema }), register);

// POST /v1/auth/login
router.post('/login', authLimiter, validate({ body: schemas.loginSchema }), login);

// POST /v1/auth/refresh
router.post('/refresh', validate({ body: schemas.refreshSchema }), refresh);

// POST /v1/auth/logout
router.post('/logout', validate({ body: schemas.logoutSchema }), logout);

module.exports = router;
