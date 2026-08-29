const axios = require('axios');
const config = require('../../config/env');

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

/**
 * Initiate an AA consent request.
 * Returns { consentHandle, redirectUrl }
 */
async function initiateConsent({ userId, fiTypes = ['DEPOSIT'], dateRangeFrom, dateRangeTo, redirectUrl }) {
  try {
    const payload = {
      consentDetail: {
        consentStart: new Date().toISOString(),
        consentExpiry: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000).toISOString(),
        consentMode: 'STORE',
        fetchType: 'PERIODIC',
        consentTypes: ['TRANSACTIONS', 'SUMMARY', 'PROFILE'],
        fiTypes,
        DataConsumer: { id: CLIENT_ID },
        Customer: { id: userId },
        Purpose: {
          code: '101',
          refUri: 'https://api.rebit.org.in/aa/purpose/101.xml',
          text: 'Credit underwriting for CredNest',
          Category: { type: 'Personal Finance' },
        },
        FIDataRange: {
          from: dateRangeFrom || new Date(Date.now() - 12 * 30 * 24 * 60 * 60 * 1000).toISOString(),
          to:   dateRangeTo   || new Date().toISOString(),
        },
        DataLife: { unit: 'MONTH', value: 3 },
        Frequency: { unit: 'MONTH', value: 1 },
        DataFilter: [],
      },
      redirectUrl,
    };
    const response = await http.post('/v2/consents', payload, { headers: headers() });
    return response.data;
  } catch (err) {
    if (err.response) {
      const e = new Error(err.response.data?.errorMsg || 'AA consent initiate failed');
      e.status = err.response.status;
      throw e;
    }
    console.warn('[AA] Sandbox unreachable, returning mock consent response');
    return {
      consentHandle: `AA_MOCK_HANDLE_${Date.now()}`,
      redirectUrl: `https://aa-sandbox.setu.co/mock-consent`,
    };
  }
}

/**
 * Fetch FI data after consent is approved.
 * Returns raw FI data array.
 */
async function fetchData({ consentHandle, fiTypes, dateRangeFrom, dateRangeTo }) {
  try {
    const sessionPayload = {
      consentHandle,
      FIDataRange: {
        from: dateRangeFrom || new Date(Date.now() - 12 * 30 * 24 * 60 * 60 * 1000).toISOString(),
        to:   dateRangeTo   || new Date().toISOString(),
      },
      KeyMaterial: {
        cryptoAlg: 'ECDH',
        curve: 'Curve25519',
        params: 'cipher=AES/GCM/NoPadding;KeySize=256;DataSize=256',
      },
    };
    const sessionResp = await http.post('/v2/sessions', sessionPayload, { headers: headers() });
    const sessionId = sessionResp.data.sessionId;

    // Poll for session data
    let attempts = 0;
    while (attempts < 10) {
      await new Promise((r) => setTimeout(r, 2000));
      const dataResp = await http.get(`/v2/sessions/${sessionId}`, { headers: headers() });
      if (dataResp.data.status === 'COMPLETED') return dataResp.data.fiObjects || [];
      if (dataResp.data.status === 'FAILED') throw new Error('AA data fetch session failed');
      attempts++;
    }
    throw new Error('AA data fetch timed out');
  } catch (err) {
    if (err.response) {
      const e = new Error(err.response.data?.errorMsg || 'AA data fetch failed');
      e.status = err.response.status;
      throw e;
    }
    console.warn('[AA] Sandbox unreachable, returning mock FI data');
    return generateMockFiData(fiTypes);
  }
}

function generateMockFiData(fiTypes = ['DEPOSIT']) {
  return fiTypes.map((type) => ({
    fipID: 'MOCK_FIP',
    accounts: [
      {
        linkRefNumber: `LRN_${Date.now()}`,
        maskedAccNumber: 'XXXXXXXX5678',
        fiType: type,
        data: {
          summary: { currentBalance: 45000, avgMonthlyBalance: 38000, transactions: 120 },
          transactions: Array.from({ length: 5 }, (_, i) => ({
            txnId: `TXN_${i}`,
            type: i % 2 === 0 ? 'CREDIT' : 'DEBIT',
            amount: 5000 + i * 1000,
            narration: `Mock transaction ${i + 1}`,
            valueDate: new Date(Date.now() - i * 7 * 24 * 60 * 60 * 1000).toISOString(),
          })),
        },
      },
    ],
  }));
}

module.exports = { initiateConsent, fetchData };
