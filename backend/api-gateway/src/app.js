const express = require("express");
const healthRoutes = require("./routes/health.routes");
const mlRoutes = require("./routes/ml.routes");
const errorMiddleware = require("./middleware/error.middleware");

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

app.use("/", healthRoutes);
app.use("/ml", mlRoutes);

app.use(errorMiddleware);

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`api-gateway listening on port ${PORT}`);
  });
}

module.exports = app;
