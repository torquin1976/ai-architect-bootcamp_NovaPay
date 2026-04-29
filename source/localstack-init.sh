#!/bin/bash

# LocalStack initialization script
# Creates SQS queue for webhook events

echo "Initializing LocalStack resources..."

# Create SQS queue
awslocal sqs create-queue \
  --queue-name novapay-webhook-queue \
  --attributes VisibilityTimeout=30,MessageRetentionPeriod=1209600

# Create dead-letter queue
awslocal sqs create-queue \
  --queue-name novapay-webhook-dlq \
  --attributes MessageRetentionPeriod=1209600

# Get queue URLs
QUEUE_URL=$(awslocal sqs get-queue-url --queue-name novapay-webhook-queue --query 'QueueUrl' --output text)
DLQ_URL=$(awslocal sqs get-queue-url --queue-name novapay-webhook-dlq --query 'QueueUrl' --output text)

echo "Created SQS queue: $QUEUE_URL"
echo "Created DLQ: $DLQ_URL"

# Configure redrive policy (send to DLQ after 3 failed attempts)
DLQ_ARN=$(awslocal sqs get-queue-attributes --queue-url $DLQ_URL --attribute-names QueueArn --query 'Attributes.QueueArn' --output text)

awslocal sqs set-queue-attributes \
  --queue-url $QUEUE_URL \
  --attributes "{\"RedrivePolicy\":\"{\\\"deadLetterTargetArn\\\":\\\"$DLQ_ARN\\\",\\\"maxReceiveCount\\\":\\\"3\\\"}\"}"

echo "LocalStack initialization complete!"
