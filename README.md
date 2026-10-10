# Self-Service AWS Deployment Platform

A DevOps-focused platform for provisioning temporary AWS environments, deploying a backend application, and providing automated monitoring, alerting, and environment lifecycle management.

The project demonstrates how a backend application can be taken from source code to a repeatable AWS environment using Infrastructure as Code, CI/CD, Linux service management, observability, and automated infrastructure lifecycle management.

The backend application is intentionally simple. The primary focus of the project is the infrastructure and operational engineering surrounding the application.

---

# Overview

The platform provides a self-service workflow for creating temporary application environments on AWS.

Each application environment consists of an EC2 instance running:

* Nginx
* NestJS
* PostgreSQL
* systemd
* Node Exporter

Monitoring is separated from the application environment.

A dedicated Prometheus EC2 instance is responsible for collecting and evaluating metrics, while a separate Grafana EC2 instance provides visualization.

Prometheus also communicates with Alertmanager for alert routing.

The architecture intentionally does not use Docker or container orchestration. Applications run directly on Linux to provide hands-on experience with EC2, networking, Linux services, deployment automation, monitoring, and infrastructure lifecycle management.

---

# Project Goals

The project is designed to demonstrate:

* Infrastructure as Code with Terraform
* AWS networking and security
* EC2 administration
* Linux service management
* PostgreSQL administration
* Backend deployment
* CI/CD with GitHub Actions
* AWS IAM and GitHub OIDC
* AWS Systems Manager
* Nginx reverse proxy configuration
* systemd service management
* Prometheus monitoring
* Grafana visualization
* Alertmanager alerting
* Application observability
* Infrastructure monitoring
* Temporary environment provisioning
* Environment isolation
* Automated environment expiration and cleanup

The goal is to build a complete operational workflow around a backend service rather than simply deploying a CRUD application.

---

# Architecture

The platform separates the application workload from the monitoring infrastructure.

Each application environment runs on its own EC2 instance. Prometheus and Grafana run on dedicated EC2 instances.

```mermaid
flowchart TD

    USER["API Client"]

    subgraph AWS["AWS"]

        subgraph APP["Application EC2"]
            NGINX["Nginx<br/>HTTPS :443"]
            API["NestJS API<br/>:3000"]
            DB["PostgreSQL<br/>:5432"]
            SYSTEMD["systemd"]
            NODE["Node Exporter<br/>:9100"]
        end

        subgraph PROM["Prometheus EC2"]
            PROMETHEUS["Prometheus<br/>:9090"]
            ALERTMANAGER["Alertmanager<br/>:9093"]
        end

        subgraph GRAFANA["Grafana EC2"]
            GRAFANA_APP["Grafana<br/>:3000"]
        end
    end

    USER -->|"HTTPS"| NGINX
    NGINX -->|"HTTP"| API
    API -->|"Prisma / localhost"| DB

    PROMETHEUS -->|"Application metrics :3000/metrics"| API
    PROMETHEUS -->|"System metrics :9100"| NODE

    GRAFANA_APP -->|"PromQL"| PROMETHEUS
    PROMETHEUS -->|"Alerts"| ALERTMANAGER

    SYSTEMD -->|"Manages"| API
```

## Application EC2

The application EC2 instance hosts the application workload:

```text
Application EC2
│
├── Nginx
├── NestJS
├── PostgreSQL
├── systemd
└── Node Exporter
```

The public request path is:

```text
Client
   │
   │ HTTPS :443
   ▼
 Nginx
   │
   │ HTTP :3000
   ▼
 NestJS
   │
   │ Prisma
   ▼
PostgreSQL
```

PostgreSQL runs on the same EC2 instance as NestJS.

Node Exporter runs on the application EC2 and exposes host-level system metrics on port `9100`.

---

## Prometheus EC2

Prometheus runs on a dedicated EC2 instance.

Its responsibilities are:

* Scrape application metrics
* Scrape application host metrics
* Store time-series data
* Evaluate alert rules
* Send alerts to Alertmanager

Prometheus obtains two different categories of metrics from the application server.

### Application metrics

Prometheus scrapes:

```text
http://APPLICATION_PRIVATE_IP:3000/metrics
```

These metrics describe the NestJS application, such as:

* HTTP request count
* HTTP request duration
* HTTP error rate
* Node.js runtime metrics
* Process memory

### System metrics

Prometheus scrapes:

```text
http://APPLICATION_PRIVATE_IP:9100/metrics
```

These metrics are provided by Node Exporter and describe the application server itself, such as:

* CPU utilization
* Memory usage
* Disk usage
* Filesystem usage
* Network statistics
* System load

The important distinction is:

```text
Application EC2
│
├── :3000/metrics
│       └── Application metrics
│
└── :9100/metrics
        └── System metrics
```

Prometheus is responsible for collecting both.

---

## Grafana EC2

Grafana runs on a separate EC2 instance.

Grafana does not scrape application metrics directly.

Instead:

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

Grafana provides dashboards for:

* Request rate
* HTTP 5xx percentage
* P95 latency
* Application availability
* CPU utilization
* Memory utilization
* Disk utilization
* Node.js process memory

Grafana should remain private and can be accessed by an operator through AWS Systems Manager port forwarding.

---

## Alertmanager

Alertmanager runs alongside Prometheus on the Prometheus EC2 instance.

The alerting flow is:

```text
Prometheus
    │
    │ Alert
    ▼
Alertmanager
    │
    ▼
Configured notification receiver
```

Alertmanager is responsible for:

* Grouping alerts
* Deduplicating alerts
* Routing notifications
* Handling firing alerts
* Handling resolved alerts

Examples of alerts include:

* Application unavailable
* Elevated HTTP 5xx rate
* High CPU utilization
* High memory utilization
* Low disk space
* Prometheus target unavailable

---

## Monitoring Flow

The complete monitoring flow is:

```text
                         Application EC2
                    ┌──────────────────────┐
                    │                      │
                    │       NestJS         │
                    │        :3000         │
                    │          │           │
                    │          │ /metrics  │
                    │          ▼           │
                    │  Application Metrics │
                    │                      │
                    │  Node Exporter :9100 │
                    │          │           │
                    │          ▼           │
                    │    System Metrics    │
                    └──────────┬───────────┘
                               │
                     Private Network
                               │
                               ▼
                    ┌─────────────────┐
                    │ Prometheus EC2  │
                    │                 │
                    │   Prometheus    │
                    │   Alertmanager  │
                    └────────┬────────┘
                             │
                           PromQL
                             │
                             ▼
                    ┌─────────────────┐
                    │   Grafana EC2   │
                    │                 │
                    │     Grafana     │
                    └─────────────────┘
```

Prometheus is the central metrics collection and alert evaluation component.

Grafana is the visualization layer.

Alertmanager is the alert routing layer.

Node Exporter provides system-level metrics from the application server.

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
* Subnets
* Route Tables
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

Invalid requests return:

```text
400 Bad Request
```

Requests for nonexistent tasks return:

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

Application restarts must not result in task data loss.

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

A failed readiness check returns:

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

* HTTP request count
* HTTP request duration
* HTTP error rate
* Node.js runtime metrics
* Process memory
* Other useful application metrics

The endpoint must not be publicly accessible.

Prometheus accesses it through the application's private network interface.

---

## FR09 — Monitoring Dashboards

Grafana shall provide dashboards for application and infrastructure metrics.

Initial dashboards should include:

* Request rate
* HTTP 5xx percentage
* P95 latency
* Application availability
* CPU utilization
* Memory utilization
* Disk utilization
* Node.js process memory

---

## FR10 — Alerting

Prometheus shall evaluate alert rules for important operational conditions.

Examples include:

* Application unavailable
* Prometheus scrape failure
* Elevated HTTP 5xx rate
* High CPU usage
* High memory usage
* Low disk space

Alertmanager shall receive and route these alerts.

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
5. Register the environment for monitoring.
6. Return environment information.

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

Cleanup should be safe to rerun.

---

## FR18 — Monitoring Target Lifecycle

Application environments shall be registered with Prometheus when they are created.

When an environment is created:

```text
Environment Created
        │
        ▼
Application EC2 Created
        │
        ▼
Prometheus discovers target
        │
        ├── :3000/metrics
        │
        └── :9100/metrics
```

When an environment is destroyed:

```text
Environment Destroyed
        │
        ▼
Application EC2 Removed
        │
        ▼
Prometheus removes target
```

---

# Database Architecture

PostgreSQL runs directly on the same EC2 instance as the NestJS application.

```text
Application EC2
│
├── Nginx
├── NestJS
├── PostgreSQL
├── systemd
└── Node Exporter
```

NestJS communicates with PostgreSQL locally.

Example connection string:

```dotenv
DATABASE_URL="postgresql://app_user:password@localhost:5432/taskflow"
```

PostgreSQL should not be publicly accessible.

Port `5432` should not be exposed through the application's security group.

Each isolated application environment has its own PostgreSQL instance and database.

---

# Networking

The AWS infrastructure uses a VPC with appropriate public and private networking.

The application EC2 requires public HTTPS access through Nginx.

Monitoring infrastructure should remain private.

Expected access:

| Resource      | Port | Source                                      |
| ------------- | ---: | ------------------------------------------- |
| Nginx         |  443 | Public HTTPS clients                        |
| Nginx         |   80 | Public clients, if HTTP redirect is enabled |
| NestJS        | 3000 | Prometheus security group                   |
| Node Exporter | 9100 | Prometheus security group                   |
| PostgreSQL    | 5432 | Local application host                      |
| Prometheus    | 9090 | Private / operator access                   |
| Alertmanager  | 9093 | Private                                     |
| Grafana       | 3000 | Private / SSM port forwarding               |

SSH access should not be required for normal deployment.

---

# Security Model

Security is based on least privilege and private service access.

## AWS IAM

IAM policies should grant only the permissions required by each component.

GitHub Actions should authenticate to AWS using GitHub OIDC rather than long-lived AWS access keys.

## Security Groups

Security groups should restrict communication between components.

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

Grafana can remain private while operators access it through an SSM tunnel.

---

# Infrastructure as Code

Terraform manages the AWS infrastructure.

The infrastructure is organized into reusable modules and environment-specific configurations.

Terraform is responsible for infrastructure such as:

* VPC
* Subnets
* Route tables
* Internet connectivity
* Security groups
* IAM
* Application EC2
* Prometheus EC2
* Grafana EC2
* Shared infrastructure

Application-level configuration such as PostgreSQL installation, Nginx configuration, Node Exporter, systemd services, Prometheus, Grafana, and Alertmanager is handled through configuration scripts and deployment automation.

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
       GitHub OIDC
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

Previous releases should be retained to support application rollback.

Database rollback must be handled separately from application rollback because schema changes can have compatibility implications.

---

# Observability Architecture

The monitoring system separates metrics collection, visualization, and alerting.

```text
                    Application EC2
              ┌────────────────────────┐
              │                        │
              │       NestJS           │
              │        :3000           │
              │          │             │
              │          │ /metrics    │
              │          ▼             │
              │  Application Metrics   │
              │                        │
              │  Node Exporter :9100   │
              │          │             │
              │          ▼             │
              │    System Metrics      │
              └────────────┬───────────┘
                           │
                    Private Network
                           │
                           ▼
                  ┌─────────────────┐
                  │ Prometheus EC2  │
                  │                 │
                  │   Prometheus    │
                  │   Alertmanager  │
                  └────────┬────────┘
                           │
                         PromQL
                           │
                           ▼
                  ┌─────────────────┐
                  │   Grafana EC2   │
                  │                 │
                  │     Grafana     │
                  └─────────────────┘
```

There is one Node Exporter in the application monitoring path: **the Node Exporter running on the application EC2**.

Prometheus scrapes:

```text
Application EC2 :3000/metrics
        │
        └── Application metrics

Application EC2 :9100/metrics
        │
        └── System metrics
```

Prometheus then makes those metrics available to Grafana through PromQL.

---

# Logging

Application logs are written to the system journal through systemd.

Example:

```bash
journalctl -u nestjs-api
```

Nginx maintains its own access and error logs.

Prometheus and Grafana are responsible for metrics and visualization, not application log aggregation.

Centralized log aggregation is outside the initial project scope.

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

# Self-Service Environments

The long-term goal is to allow an operator to create temporary environments through GitHub Actions.

The workflow will accept inputs such as:

```text
Environment name
Environment lifetime
```

The workflow will then:

```text
GitHub Actions
      │
      ▼
Validate inputs
      │
      ▼
Terraform
      │
      ▼
Create isolated application environment
      │
      ▼
Deploy NestJS
      │
      ▼
Register monitoring targets
      │
      ▼
Return environment URL
```

Each environment receives its own application EC2 instance and PostgreSQL database.

Prometheus monitors the application through:

```text
Application EC2 :3000/metrics
Application EC2 :9100/metrics
```

Shared Prometheus, Grafana, and Alertmanager infrastructure remains independent of the temporary application environment.

---

# Environment Destruction

Two destruction mechanisms are planned.

## Manual Destruction

An operator can select an environment through GitHub Actions and destroy it.

The workflow must destroy only the selected application environment.

Shared Prometheus, Grafana, and Alertmanager infrastructure must remain intact.

## Automatic Expiry

A scheduled GitHub Actions workflow periodically searches for expired environments.

For each expired environment:

```text
Find expired environment
        │
        ▼
Identify Terraform state
        │
        ▼
Destroy application environment
        │
        ▼
Remove monitoring target
```

The cleanup process should be safe to rerun.

---

# Failure and Recovery

The platform should support basic operational recovery scenarios.

## Application Process Failure

```text
NestJS crashes
     │
     ▼
systemd detects failure
     │
     ▼
systemd restarts application
```

## Application Unavailability

```text
Prometheus
     │
     ▼
Application target unavailable
     │
     ▼
Alert rule fires
     │
     ▼
Alertmanager
```

## Database Unavailability

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

## Expired Environment

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
* Application Auto Scaling
* Blue/green deployment
* Canary deployment
* Centralized log aggregation
* Distributed tracing
* Database replication

These technologies may be appropriate for larger production systems, but they are outside the scope of this project.

The objective is to build a complete and understandable DevOps workflow without introducing unnecessary infrastructure complexity.

---

# Definition of Done

The project is complete when the platform can:

* Provision an AWS environment using Terraform.
* Deploy the NestJS application directly to EC2.
* Run PostgreSQL alongside the application.
* Manage the application through systemd.
* Serve the API through HTTPS using Nginx.
* Persist task data using PostgreSQL and Prisma.
* Expose application health endpoints.
* Expose application metrics on port `3000`.
* Expose host metrics through Node Exporter on port `9100`.
* Allow Prometheus to scrape both application and system metrics.
* Visualize metrics through Grafana.
* Evaluate alerts through Prometheus.
* Route alerts through Alertmanager.
* Run CI quality and security checks through GitHub Actions.
* Authenticate GitHub Actions to AWS using OIDC.
* Deploy through AWS Systems Manager.
* Create isolated temporary environments.
* Destroy environments manually.
* Automatically remove expired environments.
* Preserve shared monitoring infrastructure.
* Update Prometheus targets as environments are created and destroyed.
* Demonstrate application recovery after failure.
* Document deployment, troubleshooting, rollback, and cleanup procedures.

---

# Learning Outcomes

This project is intended to provide practical experience with the complete lifecycle of a backend service:

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
Automate
 │
 ▼
Destroy temporary infrastructure
```

The backend application provides the workload, while the surrounding infrastructure demonstrates how software can be provisioned, deployed, operated, monitored, recovered, and eventually removed through an automated cloud workflow.

The final objective is a repeatable self-service platform where creating an environment is an automated engineering workflow rather than a sequence of manual server configuration steps.

## Reference documentation

- [Prometheus: Monitoring Linux host metrics with Node Exporter](https://prometheus.io/docs/guides/node-exporter/)
- [Prometheus: Grafana integration](https://prometheus.io/docs/visualization/grafana/)
- [AWS: Working with an RDS instance in a VPC](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_VPC.WorkingWithRDSInstanceinaVPC.html)
- [AWS: RDS security groups](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Overview.RDSSecurityGroups.html)


##
