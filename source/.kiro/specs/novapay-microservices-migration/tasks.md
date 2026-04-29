# Implementation Plan: NovaPay Microservices Migration

## Overview

This implementation plan breaks down the migration of NovaPay from a monolithic architecture to a cost-optimized microservices architecture on AWS for PoC and learning purposes. All infrastructure is defined as Terraform code, and services are deployed to ECS Fargate with single-AZ deployment and minimal instance sizes.

The implementation focuses on teaching core microservices patterns (service decomposition, externalized state, async messaging) while minimizing AWS costs. The architecture uses single-AZ deployment, minimal instance sizes (db.t3.micro, cache.t3.micro), and simplified infrastructure suitable for a learning environment.

## Tasks

- [ ] 1. Set up Terraform project structure and AWS provider configuration
  - Create directory structure: `terraform/modules/{vpc,ecs,rds,redis,sqs,alb,parameter-store}`
  - Configure AWS provider with region us-east-1
  - Create backend configuration for Terraform state (S3 + DynamoDB)
  - Define variables for environment-specific configuration
  - _Requirements: 10.1, 10.2_

- [ ] 2. Implement single-AZ VPC and networking infrastructure
  - [ ] 2.1 Create Terraform module for single-AZ VPC
    - Define VPC with public and private subnets in us-east-1a only
    - Configure route tables (public subnet with IGW, private subnet isolated)
    - No NAT Gateway (ECS tasks in public subnet for cost optimization)
    - _Requirements: 4.4, 6.1_
  
  - [ ] 2.2 Create security groups for all components
    - ALB security group: inbound 443 from 0.0.0.0/0, outbound to ECS
    - ECS security group: inbound from ALB, outbound to RDS/Redis/internet
    - RDS security group: inbound 5432 from ECS only
    - Redis security group: inbound 6379 from ECS only
    - _Requirements: 4.4_

- [ ] 3. Implement single-AZ RDS database with direct connections
  - [ ] 3.1 Create Terraform module for RDS PostgreSQL
    - Define single-AZ db.t3.micro RDS instance
    - Configure automated backups with 7-day retention
    - Enable encryption at rest using AWS KMS
    - Store credentials in environment variables (no Secrets Manager)
    - _Requirements: 6.1, 6.3, 6.4_
  
  - [ ] 3.2 Create database initialization script
    - Define `txns` table schema with indexes
    - Create migration tracking table for schema versioning
    - _Requirements: 15.1, 15.2_

- [ ] 4. Implement single-node Redis cache for idempotency store
  - [ ] 4.1 Create Terraform module for single-node Redis
    - Configure Redis 7.x single-node with cache.t3.micro
    - Enable encryption in transit (TLS 1.2)
    - Enable automated daily snapshots with 7-day retention
    - _Requirements: 7.1, 7.2, 7.3, 7.4_

- [ ] 5. Implement SQS standard queue for webhook events
  - [ ] 5.1 Create Terraform module for SQS standard queue
    - Configure standard queue (not FIFO for cost optimization)
    - Set visibility timeout to 30 seconds
    - Set message retention to 14 days
    - _Requirements: 3.1, 3.6_
  
  - [ ] 5.2 Create dead-letter queue for failed webhook deliveries
    - Configure DLQ with 14-day retention
    - Set max receive count to 3 on main queue
    - _Requirements: 3.5_

- [ ] 6. Checkpoint - Validate infrastructure foundation
  - Ensure all Terraform modules apply successfully
  - Verify VPC, subnets, and security groups are created
  - Verify RDS, Redis, and SQS resources are accessible
  - Ask the user if questions arise

- [ ] 7. Implement Authorization Service
  - [ ] 7.1 Create Node.js service with Express framework
    - Set up project structure with package.json
    - Implement POST /auth endpoint with request validation
    - Implement GET /health endpoint with dependency checks
    - _Requirements: 1.1, 13.1, 13.2, 13.7_
  
  - [ ] 7.2 Implement idempotency logic with Redis
    - Create Redis client with connection pooling
    - Implement idempotency key check with 200ms timeout
    - Implement response caching with 24-hour TTL
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 11.1_
  
  - [ ] 7.3 Implement database integration with direct connection
    - Create PostgreSQL client using `pg` library
    - Implement transaction insertion with 500ms timeout
    - Read credentials from environment variables
    - _Requirements: 6.2, 6.5, 11.2_
  
  - [ ] 7.4 Implement graceful shutdown handling
    - Handle SIGTERM signal to stop accepting new requests
    - Drain in-flight requests with 30-second timeout
    - Close database and Redis connections gracefully
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5_
  
  - [ ]* 7.5 Write unit tests for Authorization Service
    - Test idempotency key handling with mocked Redis
    - Test timeout behavior with simulated failures
    - Test graceful shutdown with in-flight requests
    - _Requirements: 1.1, 2.3_

- [ ] 8. Implement Charge Service
  - [ ] 8.1 Create Node.js service with Express framework
    - Set up project structure with package.json
    - Implement POST /charge endpoint with request validation
    - Implement POST /refund endpoint with request validation
    - Implement GET /health endpoint with dependency checks
    - _Requirements: 1.2, 13.3, 13.4, 13.7_
  
  - [ ] 8.2 Implement database integration for transaction updates
    - Create PostgreSQL client using `pg` library
    - Implement transaction status update with 500ms timeout
    - Read credentials from environment variables
    - _Requirements: 6.2, 11.2_
  
  - [ ] 8.3 Implement SQS webhook event publishing
    - Create SQS client using AWS SDK
    - Publish webhook events to standard queue
    - _Requirements: 3.1, 3.6_
  
  - [ ] 8.4 Implement graceful shutdown handling
    - Handle SIGTERM signal to stop accepting new requests
    - Drain in-flight requests with 30-second timeout
    - Close database and SQS connections gracefully
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5_
  
  - [ ]* 8.5 Write unit tests for Charge Service
    - Test transaction status updates with mocked database
    - Test SQS message publishing with mocked SQS client
    - Test graceful shutdown with in-flight requests
    - _Requirements: 1.2, 3.1_

- [ ] 9. Implement Webhook Service
  - [ ] 9.1 Create Node.js background worker service
    - Set up project structure with package.json
    - Implement SQS long-polling with 20-second wait time
    - Implement batch processing for up to 10 messages
    - Implement GET /health endpoint
    - _Requirements: 1.3, 13.5_
  
  - [ ] 9.2 Implement webhook delivery with retry logic
    - Create HTTP client with 5-second timeout
    - Implement exponential backoff with jitter (1s to 60s)
    - Delete message from SQS on successful delivery (2xx response)
    - Return message to queue on failure (visibility timeout increases)
    - _Requirements: 3.3, 3.4, 11.3, 11.4_
  
  - [ ] 9.3 Implement graceful shutdown handling
    - Handle SIGTERM signal to stop polling SQS
    - Complete processing of current batch before shutdown
    - Close database connections gracefully
    - _Requirements: 12.1, 12.2, 12.3, 12.4_
  
  - [ ]* 9.4 Write unit tests for Webhook Service
    - Test exponential backoff calculation with jitter
    - Test message deletion on successful delivery
    - Test DLQ movement after 3 failed attempts
    - _Requirements: 3.3, 3.4, 3.5_

- [ ] 10. Implement KYC Service
  - [ ] 10.1 Create Node.js service with Express framework
    - Set up project structure with package.json
    - Implement POST /kyc endpoint with SSN validation
    - Implement GET /health endpoint
    - _Requirements: 1.4, 13.6_
  
  - [ ] 10.2 Implement SSN validation logic
    - Implement regex validation for SSN format
    - Return validation result as JSON response
    - _Requirements: 1.4_
  
  - [ ] 10.3 Implement graceful shutdown handling
    - Handle SIGTERM signal to stop accepting new requests
    - Drain in-flight requests with 30-second timeout
    - _Requirements: 12.1, 12.2, 12.5_
  
  - [ ]* 10.4 Write unit tests for KYC Service
    - Test SSN validation with valid and invalid formats
    - Test graceful shutdown with in-flight requests
    - _Requirements: 1.4_

- [ ] 11. Checkpoint - Validate all services locally
  - Run each service locally with mocked dependencies
  - Verify health endpoints return HTTP 200
  - Verify API contracts match monolith responses
  - Ask the user if questions arise

- [ ] 13. Create Docker images for all services
  - [ ] 13.1 Create Dockerfile for Authorization Service
    - Use Node.js 18 Alpine base image
    - Copy package.json and install dependencies
    - Copy source code and set entrypoint
    - _Requirements: 8.1_
  
  - [ ] 13.2 Create Dockerfile for Charge Service
    - Use Node.js 18 Alpine base image
    - Copy package.json and install dependencies
    - Copy source code and set entrypoint
    - _Requirements: 8.1_
  
  - [ ] 13.3 Create Dockerfile for Webhook Service
    - Use Node.js 18 Alpine base image
    - Copy package.json and install dependencies
    - Copy source code and set entrypoint
    - _Requirements: 8.1_
  
  - [ ] 13.4 Create Dockerfile for KYC Service
    - Use Node.js 18 Alpine base image
    - Copy package.json and install dependencies
    - Copy source code and set entrypoint
    - _Requirements: 8.1_

- [ ] 13.5. Implement ECR repositories for container images
  - [ ] 13.5.1 Create Terraform module for ECR
    - Create directory structure: `terraform/modules/ecr`
    - Define ECR module with variables, main, and outputs files
    - _Requirements: 8.2_
  
  - [ ] 13.5.2 Create ECR repositories for all services
    - Create repository for Payment service (used by Auth and Charge services)
    - Create repository for KYC service
    - Create repository for WebHook service
    - Enable image scanning on push for security
    - Configure lifecycle policy to retain last 10 images
    - _Requirements: 8.2_
  
  - [ ] 13.5.3 Integrate ECR module into main Terraform configuration
    - Add ECR module to `terraform/main.tf`
    - Output ECR repository URLs for use in CodeBuild
    - _Requirements: 8.2_

- [ ] 13.6. Implement CodeBuild projects for container image builds
  - [ ] 13.6.1 Create Terraform module for CodeBuild
    - Create directory structure: `terraform/modules/codebuild`
    - Define CodeBuild module with variables, main, and outputs files
    - _Requirements: 8.2_
  
  - [ ] 13.6.2 Create IAM roles and policies for CodeBuild
    - Create IAM role for CodeBuild with trust policy
    - Attach policies for ECR push permissions (ecr:GetAuthorizationToken, ecr:BatchCheckLayerAvailability, ecr:PutImage, ecr:InitiateLayerUpload, ecr:UploadLayerPart, ecr:CompleteLayerUpload)
    - Attach policies for CloudWatch Logs (logs:CreateLogGroup, logs:CreateLogStream, logs:PutLogEvents)
    - Attach policies for S3 access (for build artifacts if needed)
    - _Requirements: 8.2_
  
  - [ ] 13.6.3 Create CodeBuild project for Payment service
    - Define build project with GitHub source configuration
    - Configure environment: Ubuntu standard image with Docker support
    - Set environment variables: AWS_ACCOUNT_ID, AWS_DEFAULT_REGION, IMAGE_REPO_NAME, IMAGE_TAG
    - Reference buildspec file: `DockerFiles/Payment/buildspec.yml`
    - _Requirements: 8.2_
  
  - [ ] 13.6.4 Create CodeBuild project for KYC service
    - Define build project with GitHub source configuration
    - Configure environment: Ubuntu standard image with Docker support
    - Set environment variables: AWS_ACCOUNT_ID, AWS_DEFAULT_REGION, IMAGE_REPO_NAME, IMAGE_TAG
    - Reference buildspec file: `DockerFiles/KYC/buildspec.yml`
    - _Requirements: 8.2_
  
  - [ ] 13.6.5 Create CodeBuild project for WebHook service
    - Define build project with GitHub source configuration
    - Configure environment: Ubuntu standard image with Docker support
    - Set environment variables: AWS_ACCOUNT_ID, AWS_DEFAULT_REGION, IMAGE_REPO_NAME, IMAGE_TAG
    - Reference buildspec file: `DockerFiles/WebHook/buildspec.yml`
    - _Requirements: 8.2_
  
  - [ ] 13.6.6 Integrate CodeBuild module into main Terraform configuration
    - Add CodeBuild module to `terraform/main.tf`
    - Pass ECR repository URLs as inputs
    - Output CodeBuild project names
    - _Requirements: 8.2_

- [ ] 13.7. Create buildspec files for Docker image builds
  - [ ] 13.7.1 Create buildspec.yml for Payment service
    - Define pre_build phase: Log in to ECR
    - Define build phase: Build Docker image with dockerfile in `DockerFiles/Payment/dockerfile`
    - Define post_build phase: Tag image and push to ECR
    - Set working directory context to `DockerFiles/Payment`
    - _Requirements: 8.2_
  
  - [ ] 13.7.2 Create buildspec.yml for KYC service
    - Define pre_build phase: Log in to ECR
    - Define build phase: Build Docker image with dockerfile in `DockerFiles/KYC/dockerfile`
    - Define post_build phase: Tag image and push to ECR
    - Set working directory context to `DockerFiles/KYC`
    - _Requirements: 8.2_
  
  - [ ] 13.7.3 Create buildspec.yml for WebHook service
    - Define pre_build phase: Log in to ECR
    - Define build phase: Build Docker image with dockerfile in `DockerFiles/WebHook/dockerfile`
    - Define post_build phase: Tag image and push to ECR
    - Set working directory context to `DockerFiles/WebHook`
    - _Requirements: 8.2_

- [ ] 14. Implement ECS Fargate cluster and task definitions
  - [ ] 14.1 Create Terraform module for ECS cluster
    - Define ECS cluster with Fargate launch type
    - Configure cluster settings for container insights
    - _Requirements: 4.1, 11.2_
  
  - [ ] 14.2 Create ECS task definitions for all services
    - Define task definition for Authorization Service (0.5 vCPU, 1 GB memory)
    - Define task definition for Charge Service (0.5 vCPU, 1 GB memory)
    - Define task definition for Webhook Service (0.5 vCPU, 1 GB memory)
    - Define task definition for KYC Service (0.5 vCPU, 1 GB memory)
    - Configure awsvpc network mode for all tasks
    - _Requirements: 4.1_
  
  - [ ] 14.3 Create ECS service definitions with autoscaling
    - Define service for Authorization Service (min: 3, max: 10 tasks)
    - Define service for Charge Service (min: 3, max: 10 tasks)
    - Define service for Webhook Service (min: 3, max: 10 tasks)
    - Define service for KYC Service (min: 3, max: 10 tasks)
    - Configure task placement across 2 availability zones
    - _Requirements: 4.2, 4.3, 4.5, 4.6_
  
  - [ ] 14.4 Configure autoscaling policies for all services
    - Create target tracking policy for CPU utilization (target: 70%)
    - Set scale-out cooldown to 60 seconds
    - Set scale-in cooldown to 300 seconds
    - _Requirements: 4.3, 4.4_

- [ ] 15. Implement Application Load Balancer configuration
  - [ ] 15.1 Create Terraform module for ALB
    - Define ALB with listeners on port 443
    - Configure ALB to span 2 availability zones
    - Enable access logs to S3
    - _Requirements: 5.1, 11.3_
  
  - [ ] 15.2 Create target groups for all services
    - Create target group for Authorization Service with health checks
    - Create target group for Charge Service with health checks
    - Create target group for KYC Service with health checks
    - Configure health check interval: 30 seconds, timeout: 5 seconds
    - Configure healthy threshold: 2, unhealthy threshold: 2
    - _Requirements: 5.5, 5.6, 5.7, 5.8_
  
  - [ ] 15.3 Configure path-based routing rules
    - Route /auth to Authorization Service target group (priority 1)
    - Route /charge to Charge Service target group (priority 2)
    - Route /refund to Charge Service target group (priority 3)
    - Route /kyc to KYC Service target group (priority 4)
    - _Requirements: 5.1, 5.2, 5.3, 5.4_
  
  - [ ] 15.4 Configure connection draining
    - Set deregistration delay to 60 seconds
    - _Requirements: 5.9, 14.6_

- [ ] 16. Implement CloudWatch observability infrastructure
  - [ ] 16.1 Create Terraform module for CloudWatch log groups
    - Create log group for Authorization Service
    - Create log group for Charge Service
    - Create log group for Webhook Service
    - Create log group for KYC Service
    - Set retention period to 30 days
    - _Requirements: 10.1, 10.2, 10.3, 10.4_
  
  - [ ] 16.2 Create CloudWatch dashboard
    - Add widgets for P50/P95/P99 latency per service
    - Add widgets for error rate percentage per service
    - Add widgets for request throughput per service
    - Add widgets for CPU and memory utilization per service
    - _Requirements: 10.5, 10.6, 10.7, 11.7_
  
  - [ ] 16.3 Create CloudWatch alarms
    - Create alarm for P99 latency > 500ms for 5 minutes
    - Create alarm for error rate > 1% for 2 minutes
    - Create alarm for CPU utilization > 80% for 5 minutes
    - Create alarm for available memory < 20% for 5 minutes
    - Configure SNS topic for alarm notifications
    - _Requirements: 10.8, 10.9, 10.10, 10.11, 10.12_

- [ ] 17. Checkpoint - Validate infrastructure deployment
  - Apply Terraform to deploy all infrastructure to AWS
  - Verify ECS services are running with 3 tasks each
  - Verify ALB health checks are passing
  - Verify CloudWatch logs are receiving log entries
  - Ask the user if questions arise

- [ ] 18. Implement CI/CD pipeline with GitHub Actions
  - [ ] 18.1 Create GitHub Actions workflow for automated testing
    - Configure workflow to run on push to main branch
    - Add job for running unit tests
    - Add job for linting and code quality checks
    - _Requirements: 8.1_
  
  - [ ] 18.2 Create GitHub Actions workflow for container image builds
    - Add job for building Docker images
    - Add job for pushing images to Amazon ECR
    - Tag images with commit SHA and latest
    - _Requirements: 8.2_
  
  - [ ] 18.3 Create GitHub Actions workflow for staging deployment
    - Add job for deploying to staging environment
    - Configure deployment to wait for health checks
    - _Requirements: 8.3_
  
  - [ ] 18.4 Create GitHub Actions workflow for production deployment
    - Add manual approval gate before production deployment
    - Configure blue-green deployment using AWS CodeDeploy
    - _Requirements: 8.4, 8.5_
  
  - [ ] 18.5 Implement canary deployment with traffic shifting
    - Configure CodeDeploy to shift 10% traffic initially
    - Configure automatic traffic increase to 50% after 5 minutes
    - Configure automatic traffic increase to 100% after error rate check
    - _Requirements: 8.6, 8.7_
  
  - [ ] 18.6 Implement automatic rollback on errors
    - Configure CloudWatch alarm for error rate > 1%
    - Configure CodeDeploy to rollback on alarm trigger
    - Set rollback timeout to 60 seconds
    - _Requirements: 8.8, 8.9_

- [ ] 19. Implement Strangler Fig migration routing
  - [ ] 19.1 Create ALB routing rules for monolith and microservices
    - Create target group for existing monolith
    - Configure weighted target groups for each endpoint
    - Set initial weights: 100% monolith, 0% microservices
    - _Requirements: 9.1, 9.2_
  
  - [ ] 19.2 Create Terraform variables for traffic split configuration
    - Define variables for auth_service_weight (0-100)
    - Define variables for charge_service_weight (0-100)
    - Define variables for kyc_service_weight (0-100)
    - _Requirements: 9.7_
  
  - [ ] 19.3 Configure CloudWatch logging for routing decisions
    - Enable ALB access logs with routing information
    - Create CloudWatch Insights queries for traffic analysis
    - _Requirements: 9.6_

- [ ] 20. Execute Phase 1: Parallel run deployment
  - [ ] 20.1 Deploy all microservices to production
    - Apply Terraform with 0% traffic to microservices
    - Verify all services are healthy and passing health checks
    - Monitor CloudWatch metrics for 24 hours
    - _Requirements: 9.1_
  
  - [ ] 20.2 Validate functional equivalence
    - Compare microservice responses to monolith responses
    - Verify API contracts match exactly
    - _Requirements: 18.1, 18.2, 18.3, 18.4, 18.5, 18.6, 18.7, 18.8, 18.9_

- [ ] 21. Execute Phase 2: Authorization Service cutover
  - [ ] 21.1 Shift 10% traffic to Authorization Service
    - Update Terraform variable: auth_service_weight = 10
    - Apply Terraform and monitor error rate for 24 hours
    - _Requirements: 9.2_
  
  - [ ] 21.2 Increase to 50% traffic if error rate < 0.5%
    - Update Terraform variable: auth_service_weight = 50
    - Apply Terraform and monitor error rate for 48 hours
    - _Requirements: 9.3_
  
  - [ ] 21.3 Increase to 100% traffic if error rate < 0.5%
    - Update Terraform variable: auth_service_weight = 100
    - Apply Terraform and monitor for 1 week
    - _Requirements: 9.4_
  
  - [ ] 21.4 Implement automatic rollback on error rate > 1%
    - Configure CloudWatch alarm to trigger rollback
    - Verify rollback completes within 60 seconds
    - _Requirements: 9.5_

- [ ] 22. Execute Phase 3: Charge Service cutover
  - [ ] 22.1 Shift 10% traffic to Charge Service
    - Update Terraform variable: charge_service_weight = 10
    - Apply Terraform and monitor error rate for 24 hours
    - Monitor webhook delivery success rates
    - _Requirements: 9.2_
  
  - [ ] 22.2 Increase to 50% traffic if error rate < 0.5%
    - Update Terraform variable: charge_service_weight = 50
    - Apply Terraform and monitor error rate for 48 hours
    - _Requirements: 9.3_
  
  - [ ] 22.3 Increase to 100% traffic if error rate < 0.5%
    - Update Terraform variable: charge_service_weight = 100
    - Apply Terraform and monitor for 1 week
    - _Requirements: 9.4_

- [ ] 23. Execute Phase 4: KYC Service cutover
  - [ ] 23.1 Shift 10% traffic to KYC Service
    - Update Terraform variable: kyc_service_weight = 10
    - Apply Terraform and monitor error rate for 24 hours
    - Monitor CPU utilization and latency improvements
    - _Requirements: 9.2_
  
  - [ ] 23.2 Increase to 50% traffic if error rate < 0.5%
    - Update Terraform variable: kyc_service_weight = 50
    - Apply Terraform and monitor error rate for 48 hours
    - _Requirements: 9.3_
  
  - [ ] 23.3 Increase to 100% traffic if error rate < 0.5%
    - Update Terraform variable: kyc_service_weight = 100
    - Apply Terraform and monitor for 1 week
    - _Requirements: 9.4_

- [ ] 24. Execute Phase 5: Monolith decommission
  - [ ] 24.1 Verify 100% traffic on microservices
    - Confirm all endpoints routing to microservices
    - Verify no traffic to monolith for 1 week
    - _Requirements: 9.4_
  
  - [ ] 24.2 Archive and remove monolith
    - Create AMI snapshot of monolith EC2 instance
    - Remove monolith from ALB target groups
    - Terminate monolith EC2 instance
    - _Requirements: 9.4_

- [ ] 25. Implement cross-region backup strategy
  - [ ] 25.1 Configure cross-region RDS snapshot replication
    - Create Terraform configuration for snapshot copy to secondary region
    - Set retention period to 30 days
    - Enable encryption for cross-region transfers
    - _Requirements: 20.1, 20.3, 20.7_
  
  - [ ] 25.2 Configure cross-region Redis snapshot replication
    - Create Terraform configuration for snapshot copy to secondary region
    - Set retention period to 30 days
    - Enable encryption for cross-region transfers
    - _Requirements: 20.2, 20.3, 20.7_
  
  - [ ] 25.3 Create disaster recovery runbook
    - Document cross-region restore procedures
    - Document RTO and RPO expectations
    - Schedule quarterly DR testing
    - _Requirements: 20.5, 20.6_

- [ ] 26. Final checkpoint - Validate migration completion
  - Verify all services running at 100% traffic
  - Verify RTO and RPO targets are met
  - Verify observability dashboards show healthy metrics
  - Verify backup and disaster recovery procedures are documented
  - Ensure all tests pass, ask the user if questions arise

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at key milestones
- This is an Infrastructure as Code migration - focus is on Terraform modules and AWS service configuration
- Unit tests focus on service logic (idempotency, retry logic, circuit breakers) with mocked dependencies
- Integration tests validate service-to-infrastructure interactions (RDS, Redis, SQS)
- The Strangler Fig pattern enables low-risk incremental cutover with automatic rollback capability
