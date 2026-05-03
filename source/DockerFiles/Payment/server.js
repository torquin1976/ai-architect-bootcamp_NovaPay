// server.js — NovaPay monolithic payment API
// Runs on a single EC2. All routes + workers in one process.
// Start:  node server.js    (listens on :3000)

const express    = require('express');
const bodyParser = require('body-parser');
const { Pool }   = require('pg');
const Redis      = require('ioredis');
const crypto     = require('crypto');
const { SQSClient, SendMessageCommand } = require('@aws-sdk/client-sqs');

const app = express();

// Database connection from environment variables
const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'novapay',
  user: process.env.DB_USERNAME || 'np',
  password: process.env.DB_PASSWORD || 'np'
};

// Redis connection from environment variables
const redisConfig = {
  host: process.env.REDIS_HOST || 'localhost',
  port: process.env.REDIS_PORT || 6379
};

const pg = new Pool(dbConfig);
const redis = new Redis(redisConfig);

// SQS client for webhook queue with LocalStack support
const sqsConfig = {
  region: process.env.AWS_REGION || 'us-east-1'
};

// If AWS_ENDPOINT_URL is set (for LocalStack), use it
if (process.env.AWS_ENDPOINT_URL) {
  sqsConfig.endpoint = process.env.AWS_ENDPOINT_URL;
}

const sqs = new SQSClient(sqsConfig);
const SQS_QUEUE_URL = process.env.SQS_QUEUE_URL;

app.use(bodyParser.json());

// ----- In-process state (the reason horizontal scaling breaks) -----
const inFlightTxns = new Map();    // idempotency store — local memory!
let   webhookQueue = [];              // in-memory queue — lost on restart!

// ----- /auth — card authorization -----
app.post('/auth', async (req, res) => {
  const { card, amount, merchantId, idempotencyKey } = req.body;
  if (inFlightTxns.has(idempotencyKey))
    return res.json(inFlightTxns.get(idempotencyKey));

  const token = crypto.randomBytes(12).toString('hex');
  await pg.query(
    'INSERT INTO txns(id, merchant, amount, status) VALUES($1,$2,$3,$4)',
    [token, merchantId, amount, 'AUTHORIZED']
  );
  const result = { token, status: 'AUTHORIZED', amount };
  inFlightTxns.set(idempotencyKey, result);
  res.json(result);
});

// ----- /charge — capture -----
app.post('/charge', async (req, res) => {
  const { token } = req.body;
  await pg.query("UPDATE txns SET status='CAPTURED' WHERE id=$1", [token]);
  
  // Send webhook event to SQS instead of in-memory queue
  if (SQS_QUEUE_URL) {
    try {
      await sqs.send(new SendMessageCommand({
        QueueUrl: SQS_QUEUE_URL,
        MessageBody: JSON.stringify({ token, event: 'captured' })
      }));
    } catch (err) {
      console.error('Failed to send SQS message:', err);
    }
  }
  
  res.json({ ok: true });
});

// ----- /refund -----
app.post('/refund', async (req, res) => {
  const { token, amount } = req.body;
  await pg.query("UPDATE txns SET status='REFUNDED' WHERE id=$1", [token]);
  res.json({ ok: true, refunded: amount });
});

// ----- /kyc — heavy CPU-bound regex (the bad neighbor) -----
/* app.post('/kyc', (req, res) => {
  const ssn = (req.body && req.body.ssn) || '';
  // Intentionally expensive regex — blocks the event loop
  const ok = /^(\d{3}-?\d{2}-?\d{4})+$/.test(ssn.repeat(3));
  res.json({ valid: ok });
}); */

// ----- webhook drain — SAME process (noisy neighbor) -----
/* setInterval(async () => {
  while (webhookQueue.length) {
    const ev = webhookQueue.shift();
    try { await fetch('https://merchant.example.com/hook',
        { method:'POST', body: JSON.stringify(ev) }); }
    catch (e) { webhookQueue.push(ev); break; }
  }
}, 2000); */

app.get('/health', (_, res) =>
  res.json({ status: 'ok', pid: process.pid, uptime: process.uptime() }));

app.listen(80, () => console.log('NovaPay monolith :80'));