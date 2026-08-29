require('dotenv').config();
const axios = require('axios');
const config = require('./src/config/env');

const BASE = config.setuAA.baseUrl;
const CLIENT_ID = config.setuAA.clientId;
const CLIENT_SECRET = config.setuAA.clientSecret;
const PRODUCT_INSTANCE_ID = config.setuAA.productInstanceId;

function headers() {
  return {
    'x-client-id': CLIENT_ID,
    'x-client-secret': CLIENT_SECRET,
    'x-product-instance-id': PRODUCT_INSTANCE_ID,
    'Content-Type': 'application/json',
  };
}

const http = axios.create({ baseURL: BASE, timeout: 20000 });

async function test() {
  try {
    const payload = {
      vua: "9999999999@onemoney",
      dataRange: {
        from: new Date(Date.now() - 365 * 24 * 60 * 60 * 1000).toISOString(),
        to: new Date().toISOString()
      },
      redirectUrl: "https://sharp-hats-swim.loca.lt/v1/webhooks/aa/consent"
    };

    const response = await http.post('/v2/consents', payload, { headers: headers() });
    console.log('--- TEST RESULT ---');
    console.log(response.data);
  } catch (err) {
    console.error('--- TEST FAILED ---');
    console.error(err.response?.data || err.message);
  }
}
test();
