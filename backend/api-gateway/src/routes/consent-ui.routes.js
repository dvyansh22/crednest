const express = require('express');
const path = require('path');
const router = express.Router();

const PUBLIC_DIR = path.join(__dirname, '../public');
const BASE_URL = process.env.API_GATEWAY_BASE_URL || 'http://localhost:4000';

/**
 * GET /v1/consent-ui/bank
 * Serves the mock Setu Account Aggregator consent page.
 * The page will redirect to crednest://aa-callback?status=SUCCESS&source=bank on allow.
 */
router.get('/bank', (req, res) => {
  res.sendFile(path.join(PUBLIC_DIR, 'aa-consent.html'));
});

/**
 * GET /v1/consent-ui/gst
 * Serves the mock Setu GSP GST consent page.
 */
router.get('/gst', (req, res) => {
  res.sendFile(path.join(PUBLIC_DIR, 'gst-consent.html'));
});

/**
 * GET /v1/consent-ui/digilocker
 * Serves the mock DigiLocker KYC consent page (with OTP flow).
 */
router.get('/digilocker', (req, res) => {
  res.sendFile(path.join(PUBLIC_DIR, 'digilocker-consent.html'));
});

/**
 * GET /v1/consent-ui/callback
 * After the HTML page redirects to crednest:// (caught by flutter_web_auth_2),
 * this server-side endpoint is NOT needed for the app flow.
 * However, we expose it so browsers that can't handle custom schemes can also
 * complete the flow via a redirect to the crednest:// deep link directly.
 */
router.get('/callback', (req, res) => {
  const { status, source } = req.query;
  if (status === 'SUCCESS') {
    res.send(`
      <html><head><style>
        body{font-family:Inter,sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;flex-direction:column;gap:12px;background:#f0fdf4}
        h2{color:#16a34a;font-size:20px}p{color:#6b7280;font-size:14px}
      </style></head><body>
        <h2>✓ ${source} connected successfully!</h2>
        <p>You may now return to the CredNest app.</p>
      </body></html>
    `);
  } else {
    res.send(`
      <html><head><style>
        body{font-family:Inter,sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;flex-direction:column;gap:12px;background:#fef2f2}
        h2{color:#dc2626;font-size:20px}p{color:#6b7280;font-size:14px}
      </style></head><body>
        <h2>Access denied</h2>
        <p>You may now return to the CredNest app.</p>
      </body></html>
    `);
  }
});

module.exports = router;
