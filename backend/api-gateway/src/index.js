require('./config/env'); // validate env first
const config = require('./config/env');
const app = require('./app');
const { connectPostgres, connectMongo, connectRedis } = require('./config/db');
const { connectKafka, disconnectKafka } = require('./config/kafka');
const { startNpaMonitor } = require('./jobs/npa-monitor.job');

async function bootstrap() {
  // Connect databases
  await connectPostgres();
  await connectMongo();
  await connectRedis();

  // Connect Kafka (non-fatal in dev)
  await connectKafka();

  // Start background jobs
  await startNpaMonitor();

  // Start HTTP server
  const server = app.listen(config.port, () => {
    console.log(`[Server] CredNest API Gateway running on port ${config.port} [${config.nodeEnv}]`);
  });

  // ─── Graceful Shutdown ────────────────────────────────────────────────────
  const shutdown = async (signal) => {
    console.log(`\n[Server] ${signal} received — shutting down gracefully`);
    server.close(async () => {
      await disconnectKafka();
      console.log('[Server] HTTP server closed');
      process.exit(0);
    });
    // Force exit after 10s
    setTimeout(() => process.exit(1), 10000);
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT',  () => shutdown('SIGINT'));
  process.on('unhandledRejection', (reason) => {
    console.error('[Server] Unhandled rejection:', reason);
  });
}

bootstrap().catch((err) => {
  console.error('[Server] Failed to start:', err.message);
  process.exit(1);
});
