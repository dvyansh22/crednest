require('dotenv').config();
const gspClient = require('./src/services/gsp-client/index.js');

async function test() {
  try {
    const result = await gspClient.verifyGstin('27AAACW5285G1Z1');
    console.log('--- TEST RESULT ---');
    console.log(result);
  } catch (err) {
    console.error('--- TEST FAILED ---');
    console.error(err);
  }
}
test();
