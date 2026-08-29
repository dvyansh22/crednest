const axios = require('axios');
const config = require('../../config/env');

const BASE = config.setuGST.baseUrl;
const CLIENT_ID = config.setuGST.clientId;
const CLIENT_SECRET = config.setuGST.clientSecret;

function headers() {
  return {
    'x-client-id': CLIENT_ID,
    'x-client-secret': CLIENT_SECRET,
    'Content-Type': 'application/json',
  };
}

const http = axios.create({ baseURL: BASE, timeout: 15000 });

/**
 * Verify GSTIN existence and status.
 */
async function verifyGstin(gstin) {
  try {
    const response = await http.get(`/api/gst/v1/verify/${gstin}`, { headers: headers() });
    return response.data;
  } catch (err) {
    if (err.response) {
      const e = new Error(err.response.data?.message || 'GSTIN verification failed');
      e.status = err.response.status;
      throw e;
    }
    console.warn('[GST] Sandbox unreachable, returning mock verify response');
    return {
      gstin,
      status: 'Active',
      legalName: 'Mock MSME Pvt Ltd',
      registrationDate: '2020-01-15',
      taxpayerType: 'Regular',
    };
  }
}

/**
 * Fetch GSTR-3B and GSTR-1 data for a period range.
 */
async function fetchGstReturns(gstin, fromPeriod, toPeriod) {
  try {
    const response = await http.post(
      '/api/gst/v1/returns',
      { gstin, fromPeriod, toPeriod, returnTypes: ['GSTR3B', 'GSTR1'] },
      { headers: headers() }
    );
    return response.data;
  } catch (err) {
    if (err.response) {
      const e = new Error(err.response.data?.message || 'GST fetch failed');
      e.status = err.response.status;
      throw e;
    }
    console.warn('[GST] Sandbox unreachable, returning mock GST data');
    return generateMockGstData(gstin, fromPeriod, toPeriod);
  }
}

function generateMockGstData(gstin, fromPeriod, toPeriod) {
  return {
    gstin,
    fromPeriod,
    toPeriod,
    GSTR3B: {
      totalTaxLiability: 125000,
      totalTaxPaid: 120000,
      igsT: 80000,
      cgst: 22500,
      sgst: 22500,
      avgMonthlyTurnover: 850000,
      filingCompliance: 0.9,
    },
    GSTR1: {
      totalInvoiceValue: 10200000,
      totalTaxableValue: 9000000,
      invoiceCount: 84,
      b2bSupplies: 7000000,
      b2cSupplies: 2000000,
    },
  };
}

module.exports = { verifyGstin, fetchGstReturns };
