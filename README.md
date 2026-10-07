# Self-Service AWS Deployment Platform

A DevOps-focused platform for provisioning temporary AWS environments, deploying a backend application, and providing automated monitoring, alerting, and environment lifecycle management.

The project is designed to demonstrate how a software application can move from source code to a repeatable AWS environment through Infrastructure as Code, CI/CD, Linux service management, observability, and automated infrastructure lifecycle management.

---

## Overview

The platform provides a self-service workflow for creating temporary application environments on AWS.

An environment consists of an application EC2 instance running:

* A NestJS backend
* PostgreSQL
* Nginx
* systemd
* Node Exporter

A separate monitoring EC2 instance provides shared observability through:

* Prometheus
* Grafana
* Alertmanager
* Node Exporter

Infrastructure is provisioned using Terraform, while GitHub Actions automates application checks, deployment, environment creation, destruction, and cleanup.

AWS Systems Manager is used for deployment and administrative access without requiring publicly exposed SSH access.

The project intentionally does not use Docker or container orchestration. Applications run directly on Linux to provide hands-on experience with EC2, systemd, networking, service management, deployment automation, and monitoring.

---

# Project Goals

The primary goals are to demonstrate:

* Infrastructure as Code with Terraform
* AWS networking and security
* Linux server administration
* Backend deployment on EC2
* PostgreSQL administration
* CI/CD with GitHub Actions
* AWS IAM and GitHub OIDC
* AWS Systems Manager
* systemd service management
* Reverse proxy configuration with Nginx
* Application and infrastructure monitoring
* Prometheus metrics
* Grafana dashboards
* Alertmanager alerting
* Temporary environment provisioning
* Environment isolation
* Automated environment expiration and cleanup

The backend application is intentionally simple. The main focus of the project is the **engineering infrastructure around the application**.

---

# Architecture

The platform uses separate EC2 instances for the application and each major monitoring component.

The application environment runs the backend and PostgreSQL together, while Prometheus, Grafana, and Alertmanager are deployed independently. This separation isolates application workloads from monitoring workloads and allows each monitoring component to be managed independently.

```mermaid
flowchart TD

    USER["API Client"]

    subgraph AWS["AWS"]

        subgraph APP["Application EC2"]
            NGINX["Nginx"]
            API["NestJS API"]
            DB["PostgreSQL"]
            SYSTEMD["systemd"]
            NODE_APP["Node Exporter"]
        end

        subgraph PROM["Prometheus EC2"]
            PROMETHEUS["Prometheus"]
            NODE_PROM["Node Exporter"]
        end

        subgraph GRAFANA["Grafana EC2"]
            GRAFANA_APP["Grafana"]
            NODE_GRAFANA["Node Exporter"]
        end

        subgraph ALERT["Alertmanager EC2"]
            ALERTMANAGER["Alertmanager"]
            NODE_ALERT["Node Exporter"]
        end
    end

    USER -->|"HTTPS"| NGINX
    NGINX -->|"HTTP"| API
    API -->|"Prisma / localhost"| DB

    PROMETHEUS -->|"Scrape /metrics"| API
    PROMETHEUS -->|"Scrape :9100"| NODE_APP
    PROMETHEUS -->|"Scrape :9100"| NODE_PROM
    PROMETHEUS -->|"Scrape :9100"| NODE_GRAFANA
    PROMETHEUS -->|"Scrape :9100"| NODE_ALERT

    GRAFANA_APP -->|"PromQL"| PROMETHEUS
    PROMETHEUS -->|"Alerts"| ALERTMANAGER

    SYSTEMD -->|"Manages"| API
```

## Application EC2

The application EC2 instance hosts the actual workload:

* Nginx
* NestJS
* PostgreSQL
* systemd
* Node Exporter

The request path is:

```text
Client
   │
   │ HTTPS
   ▼
Nginx
   │
   │ HTTP
   ▼
NestJS
   │
   │ Prisma
   ▼
PostgreSQL
```

PostgreSQL runs locally on the same instance as NestJS. It is not publicly exposed.

Node Exporter exposes host-level metrics for Prometheus.

---

## Prometheus EC2

The Prometheus EC2 instance is responsible for metrics collection and alert evaluation.

It runs:

* Prometheus
* Node Exporter

Prometheus periodically scrapes:

* Application `/metrics`
* Application EC2 Node Exporter
* Prometheus EC2 Node Exporter
* Grafana EC2 Node Exporter
* Alertmanager EC2 Node Exporter

Prometheus stores the collected time-series data and evaluates alert rules.

```text
Application EC2 ───────┐
Prometheus EC2 ────────┤
Grafana EC2 ───────────┼──► Prometheus
Alertmanager EC2 ──────┘
```

---

## Grafana EC2

Grafana runs on its own EC2 instance.

Its primary responsibility is visualization.

```text
Grafana
   │
   │ PromQL
   ▼
Prometheus
   │
   ▼
Time-series data
```

Grafana does not collect metrics itself. It queries Prometheus as its data source.

The Grafana server should remain private and can be accessed by operators through AWS Systems Manager port forwarding.

---

## Alertmanager EC2

Alertmanager runs independently on its own EC2 instance.

Prometheus sends firing and resolved alerts to Alertmanager.

```text
Prometheus
    │
    │ Alerts
    ▼
Alertmanager
    │
    ▼
Configured notification receivers
```

Alertmanager is responsible for:

* Grouping alerts
* Routing alerts
* Deduplicating notifications
* Handling alert recovery
* Sending notifications to configured receivers

---

## Node Exporter

Node Exporter runs on **every EC2 instance that needs host-level monitoring**.

Therefore, each server exposes:

```text
:9100/metrics
```

Prometheus is responsible for scraping these endpoints.

Node Exporter provides infrastructure metrics such as:

* CPU utilization
* Memory usage
* Disk usage
* Filesystem statistics
* Network statistics
* System load

This allows the monitoring system to observe both the application workload and the monitoring infrastructure itself.

---

## Overall Monitoring Flow

```text
                    ┌─────────────────────┐
                    │   Application EC2   │
                    │                     │
                    │ Nginx               │
                    │ NestJS              │
                    │ PostgreSQL           │
                    │ Node Exporter        │
                    └──────────┬──────────┘
                               │
                     /metrics + :9100
                               │
                               ▼
                    ┌─────────────────────┐
                    │   Prometheus EC2    │
                    │                     │
                    │ Prometheus          │
                    │ Node Exporter       │
                    └──────────┬──────────┘
                               │
                    ┌──────────┴──────────┐
                    │                     │
                  PromQL                Alerts
                    │                     │
                    ▼                     ▼
          ┌──────────────────┐   ┌────────────────────┐
          │  Grafana EC2     │   │ Alertmanager EC2   │
          │                  │   │                    │
          │ Grafana          │   │ Alertmanager       │
          │ Node Exporter    │   │ Node Exporter      │
          └──────────────────┘   └────────────────────┘
```

This separation keeps **application serving, metrics collection, visualization, and alert management as independent infrastructure components** while allowing Prometheus to provide a central source of monitoring data.



# Application Architecture

The backend is a TypeScript/NestJS task management API.

The application provides basic CRUD functionality for tasks while exposing health and monitoring endpoints required by the infrastructure.

```text
Client
  │
  │ HTTPS
  ▼
Nginx
  │
  │ HTTP
  ▼
NestJS
  │
  │ Prisma
  ▼
PostgreSQL
```

The application runs directly on the application EC2 instance.

PostgreSQL is intentionally hosted on the same EC2 instance to keep the project focused on infrastructure, deployment, and observability rather than managed database infrastructure.

This architecture is suitable for the scope of the project but is not intended to represent a highly available production database architecture.

---

# Technology Stack

## Application

* TypeScript
* NestJS
* Node.js
* Prisma
* PostgreSQL

## Infrastructure

* AWS
* EC2
* VPC
* Security Groups
* IAM
* Terraform

## Deployment

* GitHub Actions
* AWS Systems Manager
* GitHub OIDC
* Amazon S3
* systemd
* Nginx

## Monitoring

* Prometheus
* Grafana
* Alertmanager
* Node Exporter

## Security

* IAM
* GitHub OIDC
* Gitleaks
* Dependency vulnerability scanning
* AWS Secrets Manager

---

# Functional Requirements

## FR01 — Create Tasks

The system shall allow clients to create tasks.

```http
POST /tasks
```

A task contains:

* title
* optional description
* status

The server generates the task ID.

---

## FR02 — Retrieve Tasks

The system shall allow clients to retrieve tasks.

```http
GET /tasks
GET /tasks/:id
```

The first endpoint returns a collection of tasks while the second retrieves a specific task.

---

## FR03 — Update and Delete Tasks

Tasks can be modified or deleted.

```http
PATCH /tasks/:id
DELETE /tasks/:id
```

---

## FR04 — Request Validation

The API shall validate incoming requests.

Invalid requests should return:

```text
400 Bad Request
```

Requests for nonexistent tasks should return:

```text
404 Not Found
```

Supported task statuses are:

```text
TODO
IN_PROGRESS
DONE
```

---

## FR05 — Persistent Storage

Tasks shall be persisted in PostgreSQL using Prisma.

Application restarts must not result in data loss.

Tasks shall contain creation and update timestamps.

---

## FR06 — Database Migrations

Database schema changes shall be managed through version-controlled Prisma migrations.

Production deployments shall use migration deployment commands rather than development migration commands.

---

## FR07 — Health Checks

The application shall expose separate liveness and readiness endpoints.

### Liveness

```http
GET /health/live
```

Confirms that the application process is running.

### Readiness

```http
GET /health/ready
```

Confirms that the application is capable of serving requests, including verifying database connectivity.

A failed readiness check should return:

```text
503 Service Unavailable
```

---

## FR08 — Application Metrics

The application shall expose Prometheus-compatible metrics.

```http
GET /metrics
```

Metrics should include:

* Request count
* Request duration
* HTTP error rates
* Node.js runtime metrics
* Process memory usage
* Other relevant application metrics

The metrics endpoint must not be publicly accessible.

---

## FR09 — Monitoring Dashboards

Grafana shall provide dashboards for application and infrastructure metrics.

Initial dashboards should include:

* Request rate
* HTTP 5xx percentage
* P95 latency
* Prometheus scrape availability
* CPU utilization
* Memory utilization
* Disk utilization
* Network utilization
* Node.js process memory

---

## FR10 — Alerting

Prometheus shall evaluate alert rules for important operational conditions.

Examples include:

* Application unavailable
* Node Exporter unavailable
* Elevated HTTP 5xx rate
* High CPU usage
* High memory usage
* Low disk space

Alertmanager shall route and manage these alerts.

Alerts should support both firing and recovery states.

---

## FR11 — CI/CD Quality Gates

GitHub Actions shall execute quality and security checks before deployment.

The pipeline should include:

1. Dependency installation
2. Linting
3. Automated tests
4. Application build
5. Secret scanning
6. Dependency vulnerability scanning

Failed required checks must prevent deployment.

---

## FR12 — Application Deployment

The backend shall be deployable directly to an EC2 instance without containers.

The deployment process should:

1. Build the application.
2. Package the application.
3. Upload the release artifact.
4. Transfer or retrieve the release on the EC2 instance.
5. Install required dependencies.
6. Load application configuration.
7. Run Prisma migrations.
8. Restart the application service.
9. Verify application readiness.

AWS Systems Manager shall be used for remote deployment operations.

---

## FR13 — Service Management

The NestJS application shall run as a systemd service.

The service should:

* Start automatically after reboot.
* Restart after an application failure.
* Load the required runtime configuration.
* Provide logs through the system journal.

---

## FR14 — Self-Service Environment Creation

The platform shall provide a GitHub Actions workflow for creating temporary environments.

The workflow should accept inputs such as:

```text
Environment name
Environment lifetime
```

The workflow shall:

1. Validate the inputs.
2. Provision the environment using Terraform.
3. Configure the application server.
4. Deploy the backend.
5. Configure monitoring.
6. Return the environment information.

---

## FR15 — Environment Isolation

Each temporary environment shall have isolated application infrastructure.

Changes to one environment must not unintentionally affect another environment.

Environment resources should be identifiable using AWS tags such as:

```text
project
environment
expiry
```

Separate Terraform state should be used for isolated environments.

---

## FR16 — Manual Environment Destruction

The platform shall provide a workflow for manually destroying a temporary environment.

Destroying an application environment must not destroy shared monitoring infrastructure.

---

## FR17 — Automatic Environment Cleanup

The platform shall periodically identify expired environments and destroy them automatically.

The cleanup process should:

1. Find expired environments.
2. Identify the corresponding infrastructure.
3. Destroy the environment.
4. Remove stale monitoring targets.

Cleanup should be idempotent and safe to rerun.

---

## FR18 — Monitoring Target Lifecycle

Monitoring targets shall be dynamically associated with application environments.

When an environment is created:

```text
Environment Created
        │
        ▼
Application EC2 Created
        │
        ▼
Prometheus discovers target
```

When an environment is destroyed:

```text
Environment Destroyed
        │
        ▼
Target disappears
        │
        ▼
Prometheus stops scraping it
```

---

# Database Architecture

PostgreSQL runs on the same EC2 instance as the NestJS application.

```text
Application EC2
│
├── Nginx
├── NestJS
├── PostgreSQL
├── systemd
└── Node Exporter
```

The application communicates with PostgreSQL locally.

Example connection:

```dotenv
DATABASE_URL="postgresql://app_user:password@localhost:5432/taskflow"
```

PostgreSQL should not be publicly accessible.

Port `5432` should not be exposed through the application's security group.

Each isolated application environment has its own PostgreSQL instance and database.

---

# Networking

The AWS infrastructure shall use a VPC with appropriate public and private networking.

The application EC2 requires public HTTPS access through Nginx.

Monitoring services should remain private.

Expected network access:

| Resource      | Port | Access                        |
| ------------- | ---: | ----------------------------- |
| Nginx         |  443 | Public HTTPS                  |
| Nginx         |   80 | HTTP redirect, if enabled     |
| NestJS        | 3000 | Private                       |
| PostgreSQL    | 5432 | Local application access      |
| Node Exporter | 9100 | Monitoring EC2 only           |
| Prometheus    | 9090 | Private                       |
| Grafana       | 3000 | Private / SSM port forwarding |
| Alertmanager  | 9093 | Private                       |

SSH access should not be required for normal deployment.

---

# Security Model

Security is based on least privilege and private service access.

## AWS IAM

IAM policies should grant only the permissions required by each component.

GitHub Actions should authenticate to AWS using GitHub OIDC rather than long-lived AWS access keys.

## Security Groups

Security groups should restrict access between components.

The following services should not be publicly exposed:

* PostgreSQL
* NestJS port `3000`
* Node Exporter
* Prometheus
* Grafana
* Alertmanager

Only the required public entry point should be exposed.

---

# AWS Systems Manager

AWS Systems Manager provides remote administration and deployment access to EC2.

It removes the need to expose SSH publicly.

Systems Manager will be used for:

* Remote command execution
* Application deployment
* Operational tasks
* Private service access through port forwarding

For example, Grafana can remain bound to a private interface while an operator accesses it through an SSM tunnel.

---

# Infrastructure as Code

Terraform manages the AWS infrastructure.

The infrastructure is organized into reusable modules and environment-specific configurations.

```text
infrastructure/
├── bootstrap/
├── modules/
│   ├── networking/
│   ├── application/
│   └── monitoring/
├── environments/
└── shared/
```

Terraform is responsible for infrastructure such as:

* VPC
* Subnets
* Internet connectivity
* Route tables
* Security groups
* IAM
* EC2
* Shared monitoring infrastructure

Application-level configuration such as PostgreSQL installation, Nginx configuration, and systemd services is handled separately through configuration scripts and deployment automation.

---

# CI/CD Architecture

The intended CI/CD flow is:

```text
Developer
   │
   ▼
Git Push
   │
   ▼
GitHub
   │
   ▼
GitHub Actions
   │
   ├── Lint
   ├── Test
   ├── Build
   ├── Gitleaks
   └── Dependency Scan
           │
           ▼
       AWS OIDC
           │
           ▼
        AWS IAM
           │
           ▼
      Systems Manager
           │
           ▼
    Application EC2
```

A deployment should only occur after required checks pass.

---

# Deployment Strategy

The application is deployed directly to Linux.

A release follows this general flow:

```text
Source Code
    │
    ▼
Build
    │
    ▼
Package
    │
    ▼
Artifact Storage
    │
    ▼
Systems Manager
    │
    ▼
Application EC2
    │
    ├── Extract release
    ├── Configure environment
    ├── Run migrations
    ├── Restart systemd
    └── Run smoke tests
```

Previous releases should be retained so that application rollback is possible.

Database rollback must be handled separately from application rollback because schema changes can have compatibility implications.

---

# Observability Architecture

The monitoring architecture separates metrics collection, visualization, and alerting.

```text
                 ┌───────────────┐
                 │ Application   │
                 │    EC2        │
                 └───────┬───────┘
                         │
              ┌──────────┴──────────┐
              │                     │
         /metrics                :9100
              │                     │
              └──────────┬──────────┘
                         │
                         ▼
                  ┌─────────────┐
                  │ Prometheus  │
                  └──────┬──────┘
                         │
               ┌─────────┴─────────┐
               │                   │
               ▼                   ▼
          ┌─────────┐        ┌─────────────┐
          │ Grafana │        │ Alertmanager│
          └─────────┘        └─────────────┘
```

Prometheus collects and stores metrics.

Grafana visualizes metrics.

Alertmanager handles alert routing.

Node Exporter exposes operating-system metrics.

NestJS exposes application-level metrics.

---

# Logging

Application logs are written to the system journal through systemd.

Example:

```bash
journalctl -u nestjs-api
```

Nginx maintains its own access and error logs.

Prometheus and Grafana are responsible for metrics and visualization, not application log aggregation.

A centralized log aggregation system is outside the initial project scope.

---

# Secrets Management

Secrets must never be committed to source control.

Sensitive configuration may include:

* PostgreSQL credentials
* Application secrets
* TLS credentials
* Monitoring credentials
* AWS-related secrets

Local development uses environment variables.

AWS environments should use AWS Secrets Manager where appropriate.

GitHub Actions uses OIDC for AWS authentication rather than storing long-lived AWS access keys.

Gitleaks is used to detect accidentally committed secrets.

---

# Repository Structure

```text
devops-self-service-platform/
├── README.md
├── .gitignore
├── .env.example
│
├── app/
│   ├── src/
│   │   ├── main.ts
│   │   ├── app.module.ts
│   │   ├── tasks/
│   │   │   ├── tasks.module.ts
│   │   │   ├── tasks.controller.ts
│   │   │   ├── tasks.service.ts
│   │   │   └── dto/
│   │   │       ├── create-task.dto.ts
│   │   │       └── update-task.dto.ts
│   │   ├── prisma/
│   │   │   ├── prisma.module.ts
│   │   │   └── prisma.service.ts
│   │   ├── health/
│   │   │   ├── health.module.ts
│   │   │   └── health.controller.ts
│   │   └── metrics/
│   │       ├── metrics.module.ts
│   │       ├── metrics.controller.ts
│   │       └── metrics.interceptor.ts
│   ├── prisma/
│   │   ├── schema.prisma
│   │   └── migrations/
│   ├── test/
│   │   └── tasks.e2e-spec.ts
│   ├── package.json
│   ├── package-lock.json
│   ├── nest-cli.json
│   └── tsconfig.json
│
├── infrastructure/
│   ├── bootstrap/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── modules/
│   │   ├── networking/
│   │   ├── application/
│   │   └── monitoring/
│   ├── environments/
│   │   ├── main.tf
│   │   ├── providers.tf
│   │   ├── versions.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── backend.tf
│   │   └── terraform.tfvars.example
│   └── shared/
│       ├── main.tf
│       ├── providers.tf
│       ├── versions.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── backend.tf
│
├── configuration/
│   ├── nginx/
│   │   └── api.conf
│   ├── systemd/
│   │   ├── nestjs-api.service
│   │   ├── node-exporter.service
│   │   ├── prometheus.service
│   │   └── alertmanager.service
│   ├── prometheus/
│   │   ├── prometheus.yml
│   │   └── rules/
│   │       ├── application-alerts.yml
│   │       └── host-alerts.yml
│   ├── grafana/
│   │   ├── dashboards/
│   │   │   ├── application.json
│   │   │   └── host.json
│   │   └── provisioning/
│   │       ├── datasources/
│   │       │   └── prometheus.yml
│   │       └── dashboards/
│   │           └── dashboards.yml
│   └── alertmanager/
│       └── alertmanager.yml
│
├── scripts/
│   ├── setup-application.sh
│   ├── setup-monitoring.sh
│   ├── deploy.sh
│   ├── load-secrets.sh
│   ├── smoke-test.sh
│   ├── rollback.sh
│   └── cleanup-expired.sh
│
├── .github/
│   └── workflows/
│       ├── ci.yml
│       ├── provision.yml
│       ├── deploy.yml
│       ├── destroy.yml
│       └── cleanup-expired.yml
│
└── docs/
    ├── architecture.md
    ├── local-development.md
    ├── deployment.md
    └── runbooks/
        ├── application-down.md
        ├── database-connection.md
        └── rollback.md
```

---

# Environment Lifecycle

The complete environment lifecycle is intended to be:

```text
             ┌───────────────┐
             │ Create Request│
             └───────┬───────┘
                     │
                     ▼
              Terraform Apply
                     │
                     ▼
             AWS Environment
                     │
                     ▼
                Deployment
                     │
                     ▼
               Verification
                     │
                     ▼
                Monitoring
                     │
                     ▼
             Environment Active
                     │
                     ▼
                Expiration
                     │
                     ▼
              Terraform Destroy
                     │
                     ▼
              Environment Removed
```

Shared monitoring infrastructure remains available throughout the lifecycle.

---

# Failure and Recovery

The platform should support basic operational recovery scenarios.

Examples include:

### Application process failure

```text
NestJS crashes
     │
     ▼
systemd detects failure
     │
     ▼
systemd restarts application
```

### Application unavailable

```text
Prometheus
     │
     ▼
Target unavailable
     │
     ▼
Alert rule fires
     │
     ▼
Alertmanager
```

### Database unavailable

```text
NestJS
  │
  ▼
PostgreSQL unavailable
  │
  ▼
Readiness check fails
  │
  ▼
503 Service Unavailable
```

### Expired environment

```text
Scheduled cleanup
       │
       ▼
Expired environment detected
       │
       ▼
Terraform destroy
       │
       ▼
Temporary resources removed
```

---

# Non-Goals

The initial version intentionally excludes:

* Docker
* Docker Compose
* Kubernetes
* ECS
* EKS
* Fargate
* RDS
* Application authentication
* Frontend development
* Multi-region deployment
* High availability
* Auto Scaling Groups for the application
* Blue/green deployment
* Canary deployment
* Centralized log aggregation
* Distributed tracing
* Complex database replication

These technologies may be appropriate for larger production systems, but they are outside the scope of this project.

The goal is to build a complete and understandable DevOps workflow without introducing unnecessary infrastructure complexity.

---

# Implementation Roadmap

## Phase 1 — Backend

* Create NestJS application
* Implement task CRUD
* Add DTO validation
* Configure PostgreSQL
* Configure Prisma
* Create migrations
* Add automated tests

## Phase 2 — AWS Infrastructure

* Create VPC
* Configure subnets
* Configure routing
* Configure security groups
* Create IAM roles
* Provision application EC2
* Provision monitoring EC2
* Configure Systems Manager

## Phase 3 — Application Deployment

* Install Node.js
* Install PostgreSQL
* Configure database
* Configure Nginx
* Configure systemd
* Package application
* Deploy application
* Execute Prisma migrations
* Verify application health

## Phase 4 — Observability

* Add `/health/live`
* Add `/health/ready`
* Add `/metrics`
* Install Node Exporter
* Configure Prometheus
* Configure Grafana
* Create dashboards
* Configure Alertmanager
* Test alerts and recovery

## Phase 5 — CI/CD

* Configure GitHub Actions
* Add linting
* Add tests
* Add build
* Add Gitleaks
* Add dependency scanning
* Configure GitHub OIDC
* Configure SSM deployment
* Add smoke tests
* Add rollback procedure

## Phase 6 — Self-Service Environments

* Add environment workflow inputs
* Create isolated Terraform state
* Provision temporary environments
* Deploy application automatically
* Configure monitoring targets
* Add manual destruction workflow

## Phase 7 — Lifecycle Automation

* Add environment expiry
* Add scheduled cleanup
* Remove stale monitoring targets
* Verify environment isolation
* Test failure and recovery scenarios
* Complete documentation

---

# Definition of Done

The project is complete when the platform can:

* Provision an AWS environment through Terraform.
* Deploy the NestJS application directly to EC2.
* Run PostgreSQL alongside the application.
* Manage the application through systemd.
* Serve the API through HTTPS using Nginx.
* Persist task data using PostgreSQL and Prisma.
* Expose application health endpoints.
* Expose Prometheus application metrics.
* Collect host metrics using Node Exporter.
* Scrape application environments using Prometheus.
* Visualize metrics through Grafana.
* Detect operational failures through Prometheus alerts.
* Route alerts through Alertmanager.
* Run CI quality and security checks through GitHub Actions.
* Authenticate GitHub Actions to AWS using OIDC.
* Deploy through AWS Systems Manager.
* Create isolated temporary environments.
* Destroy environments manually.
* Automatically remove expired environments.
* Preserve shared monitoring infrastructure.
* Update monitoring targets as environments are created and destroyed.
* Demonstrate application recovery after failure.
* Document deployment, troubleshooting, rollback, and cleanup procedures.

---

# Learning Outcomes

This project is intended to provide practical experience with the full lifecycle of a backend service:

```text
Code
 │
 ▼
Build
 │
 ▼
Test
 │
 ▼
Infrastructure
 │
 ▼
Deploy
 │
 ▼
Run
 │
 ▼
Monitor
 │
 ▼
Alert
 │
 ▼
Recover
 │
 ▼
Scale the workflow
 │
 ▼
Destroy temporary infrastructure
```

The backend application provides the workload, while the surrounding infrastructure demonstrates how software is provisioned, deployed, operated, monitored, and eventually removed in a cloud environment.

The final objective is a repeatable self-service platform where creating an environment is an automated engineering workflow rather than a sequence of manual server configuration steps.


## Reference documentation

- [Prometheus: Monitoring Linux host metrics with Node Exporter](https://prometheus.io/docs/guides/node-exporter/)
- [Prometheus: Grafana integration](https://prometheus.io/docs/visualization/grafana/)
- [AWS: Working with an RDS instance in a VPC](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_VPC.WorkingWithRDSInstanceinaVPC.html)
- [AWS: RDS security groups](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Overview.RDSSecurityGroups.html)
