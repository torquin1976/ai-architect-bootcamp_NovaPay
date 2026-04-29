import { SQSClient, ReceiveMessageCommand, DeleteMessageCommand } from "@aws-sdk/client-sqs";

// Configure SQS client with LocalStack support
const sqsConfig = {
  region: process.env.AWS_REGION || "us-east-1"
};

// If AWS_ENDPOINT_URL is set (for LocalStack), use it
if (process.env.AWS_ENDPOINT_URL) {
  sqsConfig.endpoint = process.env.AWS_ENDPOINT_URL;
}

const sqs = new SQSClient(sqsConfig);
const QueueUrl = process.env.SQS_QUEUE_URL;

if (!QueueUrl) {
  console.error('ERROR: SQS_QUEUE_URL environment variable is required');
  process.exit(1);
}

while (true) {
  const { Messages = [] } = await sqs.send(new ReceiveMessageCommand({
    QueueUrl,
    MaxNumberOfMessages: 10,
    WaitTimeSeconds: 20
  }));

  for (const m of Messages) {
    try {
      await fetch("https://merchant.example.com/hook", {
        method: "POST",
        body: m.Body
      });

      await sqs.send(new DeleteMessageCommand({
        QueueUrl,
        ReceiptHandle: m.ReceiptHandle
      }));

    } catch {
      // let SQS retry
    }
  }
}