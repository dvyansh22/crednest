require('dotenv').config();
const dlClient = require('./src/services/digilocker-client/index.js');

async function test() {
  try {
    const result = await dlClient.initiateRequest('test-user-123', 'https://sharp-hats-swim.loca.lt/v1/webhooks/digilocker');
    console.log('--- TEST RESULT ---');
    console.log(result);
  } catch (err) {
    console.error('--- TEST FAILED ---');
    console.error(err);
  }
}
test();
