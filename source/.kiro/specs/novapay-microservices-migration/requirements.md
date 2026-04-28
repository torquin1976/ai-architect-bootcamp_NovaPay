# Requirements Document

## Introduction

This document specifies the requirements for migrating NovaPay from a single-instance monolithic architecture to a microservices architecture on AWS for PoC and learning purposes. This is a cost-optimized, minimal viable implementation designed for internal learning and experimentation, NOT production use.

The migration focuses on teaching core microservices patterns (service decomposition, externalized state, async messaging) while minimizing AWS costs. The architecture uses single-AZ deployment, minimal instance sizes, and simplified infrastructure suitable for a learning environment processing low transaction volumes.

## Glossary

- **Authorization_Service**: Microservice responsible for card authorization and idempotency management
- **Charge_Service**: Microservice responsible for payment capture and refund operations
- **Webhook_Service**: Microservice responsible for asynchronous webhook delivery to merchants
- **KYC_Service**: Microservice responsible for CPU-intensive Know Your Customer validation
- **Application_Load_Balancer**: AWS ALB providing L7 path-based routing with health checks
- **Database**: Single-AZ RDS PostgreSQL instance for transaction storage
- **Idempotency_Store**: Single-node Elasticache Redis instance storing idempotency keys
- **Webhook_Queue**: AWS SQS standard queue providing durable webhook event storage
- **ECS_Cluster**: AWS Fargate cluster running containerized microservices with 1 task per service
- **Deployment_Pipeline**: GitHub Actions workflow for building and deploying container images
- **Infrastructure_Code**: Terraform modules defining all AWS resources
- **Parameter_Store**: AWS Systems Manager Parameter Store storing database credentials and configuration
- **Health_Endpoint**: HTTP endpoint returning service health status for load balancer checks

## Requirements

### Requirement 1: Service Decomposition

**User Story:** As a platform architect, I want to decompose the monolith into independent microservices, so that failures are isolated and services can scale independently.

#### Acceptance Criteria

1. THE Authorization_Service SHALL handle card authorization requests and idempotency management
2. THE Charge_Service SHALL handle payment capture and refund operations
3. THE Webhook_Service SHALL handle asynchronous webhook delivery to merchants
4. THE KYC_Service SHALL handle CPU-intensive Know Your Customer validation
5. WHEN one service fails, THE other services SHALL continue processing requests without degradation
6. THE Authorization_Service SHALL NOT share in-process state with other services
7. THE Charge_Service SHALL NOT share in-process state with other services
8. THE Webhook_Service SHALL NOT share in-process state with other services
9. THE KYC_Service SHALL NOT share in-process state with other services

### Requirement 2: Externalized Idempotency State

**User Story:** As a platform engineer, I want idempotency state stored in a shared cache, so that horizontal scaling does not break duplicate request detection.

#### Acceptance Criteria

1. THE Authorization_Service SHALL store idempotency keys in the Idempotency_Store
2. THE Authorization_Service SHALL retrieve idempotency keys from the Idempotency_Store
3. WHEN an idempotency key exists in the Idempotency_Store, THE Authorization_Service SHALL return the cached response without creating a new transaction
4. WHEN an idempotency key does not exist in the Idempotency_Store, THE Authorization_Service SHALL process the request and store the result
5. THE Idempotency_Store SHALL persist entries for at least 24 hours
6. WHEN the Idempotency_Store is unavailable, THE Authorization_Service SHALL return an error response with HTTP 503 status code

### Requirement 3: Durable Webhook Queue

**User Story:** As a reliability engineer, I want webhook events stored in a durable queue, so that events are not lost during service restarts or failures.

#### Acceptance Criteria

1. THE Charge_Service SHALL publish webhook events to the Webhook_Queue
2. THE Webhook_Service SHALL consume webhook events from the Webhook_Queue
3. WHEN a webhook delivery fails, THE Webhook_Service SHALL retry delivery with exponential backoff up to 3 attempts
4. WHEN a webhook delivery succeeds, THE Webhook_Service SHALL delete the message from the Webhook_Queue
5. WHEN a webhook delivery fails after 3 attempts, THE Webhook_Service SHALL move the message to a dead-letter queue
6. THE Webhook_Queue SHALL guarantee at-least-once delivery of webhook events

### Requirement 4: Single-AZ Container Orchestration

**User Story:** As a DevOps engineer, I want services deployed on ECS Fargate, so that I can run containerized microservices without managing servers.

#### Acceptance Criteria

1. THE ECS_Cluster SHALL run 1 task per service in a single availability zone
2. WHEN a task fails health checks, THE ECS_Cluster SHALL terminate the task and launch a replacement
3. THE ECS_Cluster SHALL use Fargate launch type to eliminate server management
4. THE ECS_Cluster SHALL deploy tasks in public subnets with public IP addresses to avoid NAT Gateway costs

### Requirement 5: Application Load Balancer Routing

**User Story:** As a platform engineer, I want path-based routing with health checks, so that traffic is distributed only to healthy service instances.

#### Acceptance Criteria

1. THE Application_Load_Balancer SHALL route requests to /auth to the Authorization_Service
2. THE Application_Load_Balancer SHALL route requests to /charge to the Charge_Service
3. THE Application_Load_Balancer SHALL route requests to /refund to the Charge_Service
4. THE Application_Load_Balancer SHALL route requests to /kyc to the KYC_Service
5. THE Application_Load_Balancer SHALL perform health checks on each service Health_Endpoint every 30 seconds
6. WHEN a service Health_Endpoint returns HTTP 200, THE Application_Load_Balancer SHALL route traffic to that instance
7. WHEN a service Health_Endpoint returns non-200 status or times out after 5 seconds, THE Application_Load_Balancer SHALL mark the instance unhealthy
8. WHEN an instance is marked unhealthy, THE Application_Load_Balancer SHALL stop routing new requests to that instance within 30 seconds
9. THE Application_Load_Balancer SHALL drain in-flight requests for 60 seconds before terminating an unhealthy instance

### Requirement 6: Single-AZ Database with Direct Connections

**User Story:** As a database administrator, I want a single-AZ RDS PostgreSQL instance, so that I can store transaction data cost-effectively for PoC purposes.

#### Acceptance Criteria

1. THE Database SHALL run PostgreSQL on a db.t3.micro instance in a single availability zone
2. THE Database SHALL accept direct connections from ECS services without RDS Proxy
3. THE Database SHALL enable automated daily backups with 7-day retention
4. THE Database SHALL store database credentials in AWS Systems Manager Parameter Store
5. WHEN a service requests a database connection, THE Database SHALL accept the connection within 100 milliseconds

### Requirement 7: Single-Node Redis Cache

**User Story:** As a platform engineer, I want a single-node Redis cache, so that I can externalize idempotency state cost-effectively for PoC purposes.

#### Acceptance Criteria

1. THE Idempotency_Store SHALL run Redis 7 on a cache.t3.micro instance in a single availability zone
2. THE Idempotency_Store SHALL accept direct connections from the Authorization_Service
3. THE Idempotency_Store SHALL enable encryption in transit using TLS 1.2 or higher
4. THE Idempotency_Store SHALL enable automated daily snapshots with 7-day retention

### Requirement 8: CI/CD Pipeline with Rolling Deployment

**User Story:** As a developer, I want automated deployments with simple rolling updates, so that releases are automated without complex deployment strategies.

#### Acceptance Criteria

1. WHEN code is pushed to the main branch, THE Deployment_Pipeline SHALL execute automated tests
2. WHEN automated tests pass, THE Deployment_Pipeline SHALL build container images and push to ECR
3. WHEN container images are pushed to ECR, THE Deployment_Pipeline SHALL update ECS task definitions
4. WHEN task definitions are updated, THE ECS_Cluster SHALL perform a rolling update by stopping old tasks and starting new tasks
5. THE Deployment_Pipeline SHALL complete deployment without manual approval for PoC simplicity

### Requirement 9: Basic Observability

**User Story:** As a developer, I want basic logging and monitoring, so that I can debug issues during PoC testing.

#### Acceptance Criteria

1. THE Authorization_Service SHALL emit structured JSON logs to CloudWatch Logs
2. THE Charge_Service SHALL emit structured JSON logs to CloudWatch Logs
3. THE Webhook_Service SHALL emit structured JSON logs to CloudWatch Logs
4. THE KYC_Service SHALL emit structured JSON logs to CloudWatch Logs
5. THE ECS_Cluster SHALL send container metrics to CloudWatch for basic monitoring

### Requirement 10: Infrastructure as Code

**User Story:** As a platform engineer, I want all infrastructure defined in Terraform, so that environments are reproducible and changes are auditable.

#### Acceptance Criteria

1. THE Infrastructure_Code SHALL define all AWS resources using Terraform modules
2. THE Infrastructure_Code SHALL define the ECS_Cluster using Terraform
3. THE Infrastructure_Code SHALL define the Application_Load_Balancer using Terraform
4. THE Infrastructure_Code SHALL define the Database using Terraform
5. THE Infrastructure_Code SHALL define the Idempotency_Store using Terraform
6. THE Infrastructure_Code SHALL define the Webhook_Queue using Terraform
7. WHEN Infrastructure_Code is applied, Terraform SHALL create or update resources to match the desired state
8. WHEN Infrastructure_Code is destroyed, Terraform SHALL remove all created resources

### Requirement 11: Basic Resilience Patterns

**User Story:** As a reliability engineer, I want timeouts implemented, so that slow dependencies do not block request processing.

#### Acceptance Criteria

1. WHEN the Authorization_Service calls the Idempotency_Store, THE Authorization_Service SHALL timeout after 200 milliseconds
2. WHEN the Charge_Service calls the Database, THE Charge_Service SHALL timeout after 500 milliseconds
3. WHEN the Webhook_Service calls merchant webhook endpoints, THE Webhook_Service SHALL timeout after 5 seconds
4. WHEN the Webhook_Service retries failed webhook deliveries, THE Webhook_Service SHALL apply exponential backoff between 1 second and 60 seconds

### Requirement 12: Graceful Shutdown

**User Story:** As a platform engineer, I want services to drain in-flight requests during shutdown, so that no requests are dropped during deployments.

#### Acceptance Criteria

1. WHEN a service receives a SIGTERM signal, THE service SHALL stop accepting new requests
2. WHEN a service receives a SIGTERM signal, THE service SHALL continue processing in-flight requests
3. WHEN all in-flight requests complete, THE service SHALL close database connections gracefully
4. WHEN all in-flight requests complete, THE service SHALL close Redis connections gracefully
5. WHEN graceful shutdown exceeds 30 seconds, THE service SHALL force-terminate remaining requests

### Requirement 13: Service Health Endpoints

**User Story:** As a platform engineer, I want health checks, so that unhealthy instances are detected by the load balancer.

#### Acceptance Criteria

1. THE Authorization_Service SHALL expose a Health_Endpoint at /health
2. THE Charge_Service SHALL expose a Health_Endpoint at /health
3. THE Webhook_Service SHALL expose a Health_Endpoint at /health
4. THE KYC_Service SHALL expose a Health_Endpoint at /health
5. WHEN the Health_Endpoint is called, THE service SHALL verify database connectivity
6. WHEN the Health_Endpoint is called, THE service SHALL verify Redis connectivity for services that use it
7. WHEN all dependencies are healthy, THE Health_Endpoint SHALL return HTTP 200
8. WHEN any dependency is unhealthy, THE Health_Endpoint SHALL return HTTP 503

### Requirement 14: Backward Compatibility

**User Story:** As a merchant integration engineer, I want API contracts preserved, so that existing integrations continue working.

#### Acceptance Criteria

1. THE Authorization_Service SHALL accept the same request schema as the monolith /auth endpoint
2. THE Authorization_Service SHALL return the same response schema as the monolith /auth endpoint
3. THE Charge_Service SHALL accept the same request schema as the monolith /charge endpoint
4. THE Charge_Service SHALL return the same response schema as the monolith /charge endpoint
5. THE Charge_Service SHALL accept the same request schema as the monolith /refund endpoint
6. THE Charge_Service SHALL return the same response schema as the monolith /refund endpoint
7. THE KYC_Service SHALL accept the same request schema as the monolith /kyc endpoint
8. THE KYC_Service SHALL return the same response schema as the monolith /kyc endpoint

### Requirement 16: Secrets Management with Parameter Store

**User Story:** As a security engineer, I want credentials stored in AWS Systems Manager Parameter Store, so that secrets are managed securely without additional cost.

#### Acceptance Criteria

1. THE Parameter_Store SHALL store database credentials for RDS using SecureString type
2. THE Parameter_Store SHALL store Redis connection details using SecureString type
3. THE Authorization_Service SHALL retrieve database credentials from Parameter_Store at startup
4. THE Charge_Service SHALL retrieve database credentials from Parameter_Store at startup
5. THE Webhook_Service SHALL retrieve database credentials from Parameter_Store at startup
6. THE Parameter_Store SHALL use AWS KMS for encryption of SecureString parameters
7. THE Infrastructure_Code SHALL NOT contain plaintext credentials in Terraform state files

### Requirement 17: Database Schema Migration

**User Story:** As a database administrator, I want schema changes applied safely, so that data integrity is maintained.

#### Acceptance Criteria

1. THE Infrastructure_Code SHALL define database schema migrations using a migration tool
2. WHEN the Deployment_Pipeline deploys a new version, THE migration tool SHALL apply pending schema changes before starting services
3. WHEN a schema migration fails, THE Deployment_Pipeline SHALL halt deployment
4. THE migration tool SHALL record all applied migrations in a schema_migrations table
5. THE migration tool SHALL prevent re-applying already executed migrations
