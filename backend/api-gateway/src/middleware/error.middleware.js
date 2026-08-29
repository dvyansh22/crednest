module.exports = (err, req, res, next) => {
  console.error(err);

  const status = err.response?.status || 500;
  const message = err.response?.data?.detail || err.message || "Internal Server Error";

  res.status(status).json({
    error: message,
  });
};
