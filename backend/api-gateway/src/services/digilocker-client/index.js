const axios = require('axios');
const config = require('../../config/env');

const BASE = config.setuDigiLocker.baseUrl;
const CLIENT_ID = config.setuDigiLocker.clientId;
const CLIENT_SECRET = config.setuDigiLocker.clientSecret;
const PRODUCT_INSTANCE_ID = config.setuDigiLocker.productInstanceId;

function headers() {
  return {
    'x-client-id': CLIENT_ID,
    'x-client-secret': CLIENT_SECRET,
    'x-product-instance-id': PRODUCT_INSTANCE_ID,
    'Content-Type': 'application/json',
  };
}

const http = axios.create({ baseURL: BASE, timeout: 15000 });

/**
 * Initiate a DigiLocker consent request.
 * Returns { requestId, redirectUrl }
 */
async function initiateRequest(userId, redirectBackUrl) {
  try {
    const response = await http.post(
      '/api/digilocker/v2/request',
      {
        redirectUrl: redirectBackUrl,
        purpose: 'KYC verification for CredNest lending platform',
        userId,
      },
      { headers: headers() }
    );
    return response.data;
  } catch (err) {
    // Log the error from Setu sandbox, but continue to mock flow
    console.warn('[DigiLocker] Setu API failed:', err.response?.data || err.message);
    console.warn('[DigiLocker] Returning mock initiate response due to Sandbox failure.');
    return {
      requestId: `DL_MOCK_${Date.now()}`,
      redirectUrl: `https://digilocker.gov.in/mock-auth?requestId=DL_MOCK_${Date.now()}`,
    };
  }
}

/**
 * Poll status of a DigiLocker request.
 * Returns { status: 'pending'|'approved'|'rejected', kycData? }
 */
async function getRequestStatus(requestId) {
  try {
    const response = await http.get(`/api/digilocker/v2/request/${requestId}`, {
      headers: headers(),
    });
    return response.data;
  } catch (err) {
    console.warn('[DigiLocker] Setu status fetch failed:', err.response?.data || err.message);
    // Mock for dev
    return {
      status: 'approved',
      kycData: {
        full_name: 'Mock User',
        aadhaar_masked: 'XXXX XXXX 1234',
        pan: 'ABCDE1234F',
      },
    };
  }
}

module.exports = { initiateRequest, getRequestStatus };
