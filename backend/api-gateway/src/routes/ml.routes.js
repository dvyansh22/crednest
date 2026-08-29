const express = require("express");
const axios = require("axios");

const router = express.Router();
const ML_SERVICE_URL = process.env.ML_SERVICE_URL || "http://ml-service:8001";

router.get("/ping", async (req, res, next) => {
  try {
    const response = await axios.get(`${ML_SERVICE_URL}/health`, {
      timeout: 5000,
    });

    res.status(response.status).json(response.data);
  } catch (error) {
    next(error);
  }
});

module.exports = router;
