const { Kafka, logLevel } = require('kafkajs');
const config = require('./env');

const kafka = new Kafka({
  clientId: config.kafkaClientId,
  brokers: config.kafkaBrokers,
  logLevel: config.nodeEnv === 'production' ? logLevel.WARN : logLevel.ERROR,
  retry: {
    initialRetryTime: 300,
    retries: 5,
  },
});

const producer = kafka.producer();
const consumers = [];

async function connectKafka() {
  try {
    await producer.connect();
    console.log('[Kafka] Producer connected');
  } catch (err) {
    console.warn('[Kafka] Could not connect producer (non-fatal in dev):', err.message);
  }
}

async function disconnectKafka() {
  try {
    await producer.disconnect();
    for (const consumer of consumers) {
      await consumer.disconnect();
    }
    console.log('[Kafka] Disconnected');
  } catch (err) {
    console.error('[Kafka] Error during disconnect:', err.message);
  }
}

async function publishEvent(topic, key, value) {
  try {
    await producer.send({
      topic,
      messages: [
        {
          key: String(key),
          value: JSON.stringify(value),
          timestamp: Date.now().toString(),
        },
      ],
    });
  } catch (err) {
    console.error(`[Kafka] Failed to publish to ${topic}:`, err.message);
  }
}

async function createConsumer(groupId) {
  const consumer = kafka.consumer({ groupId });
  consumers.push(consumer);
  return consumer;
}

module.exports = {
  kafka,
  producer,
  connectKafka,
  disconnectKafka,
  publishEvent,
  createConsumer,
};
