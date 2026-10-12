# Self-Service AWS Deployment Platform

A DevOps-focused platform for provisioning temporary AWS environments, deploying a backend application, and providing automated monitoring, alerting, and environment lifecycle management.

The project demonstrates how a backend application can be taken from source code to a repeatable AWS environment using Infrastructure as Code, CI/CD, Linux service management, observability, and automated infrastructure lifecycle management.

The backend application is intentionally simple. The primary focus of the project is the infrastructure and operational engineering surrounding the application.

---

# Overview

The platform is designed to provide a self-service workflow for creating temporary application environments on AWS.

Each application environment consists of an EC2 instance running:

- Nginx
- NestJS
- PostgreSQL
- systemd
- Node Exporter

Monitoring is separated from the application environment.

A dedicated Prometheus EC2 instance is responsible for collecting and evaluating metrics, while a separate Grafana EC2 instance provides visualization.

Prometheus also communicates with Alertmanager for alert routing.

The architecture intentionally does not use Docker or container orchestration. Applications run directly on Linux to provide hands-on experience with EC2, networking, Linux services, deployment automation, monitoring, and infrastructure lifecycle management.

**Current implementation status:** The TaskFlow backend deployment pipeline, AWS OIDC authentication, S3 artifact delivery, SSM deployment, systemd service management, and monitoring foundation have been implemented. Self-service temporary environment creation, manual environment destruction, and automatic expiry cleanup remain planned extensions.

---

# Project Goals

The project is designed to demonstrate:

- Infrastructure as Code with Terraform
- AWS networking and security
- EC2 administration
- Linux service management
- PostgreSQL administration
- Backend deployment
- CI/CD with GitHub Actions
- AWS IAM and GitHub OIDC
- AWS Systems Manager
- Nginx reverse proxy configuration
- systemd service management
- Prometheus monitoring
- Grafana visualization
- Alertmanager alerting
- Application observability
- Infrastructure monitoring
- Temporary environment provisioning
- Environment isolation
- Automated environment expiration and cleanup

The goal is to build a complete operational workflow around a backend service rather than simply deploying a CRUD application.

---

# Architecture

The platform separates the application workload from the monitoring infrastructure.

Each application environment is intended to run on its own EC2 instance. Prometheus and Grafana run on dedicated EC2 instances.

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
            GRAFANA_APP["Grafana"]
        end
    end

    USER -->|"HTTPS"| NGINX
    NGINX -->|"HTTP"| API
    API -->|"Prisma / localhost"| DB

    PROMETHEUS -->|"Application metrics :3000/metrics"| API
    PROMETHEUS -->|"System metrics :9100/metrics"| NODE

    GRAFANA_APP -->|"PromQL"| PROMETHEUS
    PROMETHEUS -->|"Alerts"| ALERTMANAGER

    SYSTEMD -->|"Manages"| API
```

The diagram describes the intended request and monitoring paths. Verify the active Nginx, TLS, and security-group configurations before assuming every illustrated access path is currently enabled.

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

The intended public request path is:

```text
Client
   |
   | HTTPS :443
   v
 Nginx
   |
   | HTTP :3000
   v
 NestJS
   |
   | Prisma
   v
PostgreSQL
```

PostgreSQL runs on the same EC2 instance as NestJS.

Node Exporter runs on the application EC2 and exposes host-level system metrics on port `9100`.

## Prometheus EC2

Prometheus runs on a dedicated EC2 instance.

Its responsibilities are:

- Scrape application metrics
- Scrape application host metrics
- Store time-series data
- Evaluate alert rules
- Send alerts to Alertmanager

Prometheus obtains two different categories of metrics from the application server.

### Application metrics

Prometheus scrapes:

```text
http://APPLICATION_PRIVATE_IP:3000/metrics
```

These metrics describe the NestJS application, such as:

- HTTP request count
- HTTP request duration
- HTTP error rate
- Node.js runtime metrics
- Process memory

### System metrics

Prometheus scrapes:

```text
http://APPLICATION_PRIVATE_IP:9100/metrics
```

These metrics are provided by Node Exporter and describe the application server itself, such as:

- CPU utilization
- Memory usage
- Disk usage
- Filesystem usage
- Network statistics
- System load

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

## Grafana EC2

Grafana runs on a separate EC2 instance.

Grafana does not scrape application metrics directly.

Instead:

```text
Grafana
   |
   | PromQL queries
   v
Prometheus
   |
   v
Time-series data
```

Grafana provides dashboards for:

- Request rate
- HTTP 5xx percentage
- P95 latency
- Application availability
- CPU utilization
- Memory utilization
- Disk utilization
- Node.js process memory

Grafana should remain private and can be accessed by an operator through AWS Systems Manager port forwarding when configured.

## Alertmanager

Alertmanager runs alongside Prometheus on the Prometheus EC2 instance.

The alerting flow is:

```text
Prometheus
    |
    | Alert
    v
Alertmanager
    |
    v
Configured notification receiver
```

Alertmanager is responsible for:

- Grouping alerts
- Deduplicating alerts
- Routing notifications
- Handling firing alerts
- Handling resolved alerts

Examples of alerts include:

- Application unavailable
- Elevated HTTP 5xx rate
- High CPU utilization
- High memory utilization
- Low disk space
- Prometheus target unavailable

A CPU alert configured to send Slack notifications when utilization exceeds 75% has been implemented.

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

- TypeScript
- NestJS
- Node.js
- Prisma
- PostgreSQL

## Infrastructure

- AWS
- EC2
- EBS
- VPC
- Subnets
- Route Tables
- Security Groups
- IAM
- Terraform

The existing Terraform configuration relies on AWS default networking in places. Not every VPC, subnet, or route table is explicitly managed by the current configuration.

## Deployment

- GitHub Actions
- AWS Systems Manager
- GitHub OIDC
- Amazon S3
- systemd
- Nginx

## Monitoring

- Prometheus
- Grafana
- Alertmanager
- Node Exporter

## Security

- IAM
- GitHub OIDC
- Gitleaks
- Dependency vulnerability scanning
- AWS Secrets Manager where configured

---

# Functional Requirements

The following requirements define the intended behavior of the platform. Some describe completed functionality, while temporary-environment lifecycle automation remains future work.

## FR01 — Create Tasks

The system shall allow clients to create tasks.

```http
POST /tasks
```

A task contains:

- title
- optional description
- status

The server generates the task ID.

## FR02 — Retrieve Tasks

The system shall allow clients to retrieve tasks.

```http
GET /tasks
GET /tasks/:id
```

The first endpoint returns a collection of tasks while the second retrieves a specific task.

## FR03 — Update and Delete Tasks

Tasks can be modified or deleted.

```http
PATCH /tasks/:id
DELETE /tasks/:id
```

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

## FR05 — Persistent Storage

Tasks shall be persisted in PostgreSQL using Prisma.

Application restarts must not result in task data loss.

Tasks shall contain creation and update timestamps.

## FR06 — Database Migrations

Database schema changes shall be managed through version-controlled Prisma migrations.

Production deployments shall use migration deployment commands rather than development migration commands.

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

## FR08 — Application Metrics

The application shall expose Prometheus-compatible metrics.

```http
GET /metrics
```

Metrics should include:

- HTTP request count
- HTTP request duration
- HTTP error rate
- Node.js runtime metrics
- Process memory
- Other useful application metrics

The endpoint must not be publicly accessible.

Prometheus accesses it through the application's private network interface.

## FR09 — Monitoring Dashboards

Grafana shall provide dashboards for application and infrastructure metrics.

Initial dashboards should include:

- Request rate
- HTTP 5xx percentage
- P95 latency
- Application availability
- CPU utilization
- Memory utilization
- Disk utilization
- Node.js process memory

## FR10 — Alerting

Prometheus shall evaluate alert rules for important operational conditions.

Examples include:

- Application unavailable
- Prometheus scrape failure
- Elevated HTTP 5xx rate
- High CPU usage
- High memory usage
- Low disk space

Alertmanager shall receive and route these alerts.

Alerts should support both firing and recovery states.

## FR11 — CI/CD Quality Gates

GitHub Actions shall execute quality and security checks before deployment.

The pipeline includes:

1. Dependency installation
2. Linting
3. Automated tests
4. Application build
5. Secret scanning
6. Dependency vulnerability scanning

Failed required checks must prevent deployment.

## FR12 — Application Deployment

The backend shall be deployable directly to an EC2 instance without containers.

The deployment process should:

1. Build the application.
2. Package the application.
3. Upload the release artifact.
4. Retrieve the release on the EC2 instance.
5. Install required dependencies.
6. Load application configuration.
7. Run Prisma migrations.
8. Restart the application service.
9. Verify application readiness.

AWS Systems Manager is used for remote deployment operations.

## FR13 — Service Management

The NestJS application shall run as a systemd service.

The service should:

- Start automatically after reboot.
- Restart after an application failure.
- Load the required runtime configuration.
- Provide logs through the system journal.

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

**Status:** Planned. The complete self-service environment creation workflow has not been implemented.

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

**Status:** Design requirement for the future temporary-environment implementation.

## FR16 — Manual Environment Destruction

The platform shall provide a workflow for manually destroying a temporary environment.

Destroying an application environment must not destroy shared monitoring infrastructure.

**Status:** Planned.

## FR17 — Automatic Environment Cleanup

The platform shall periodically identify expired environments and destroy them automatically.

The cleanup process should:

1. Find expired environments.
2. Identify the corresponding infrastructure.
3. Destroy the environment.
4. Remove stale monitoring targets.

Cleanup should be safe to rerun.

**Status:** Planned.

## FR18 — Monitoring Target Lifecycle

Application environments shall be registered with Prometheus when they are created.

When an environment is created:

```text
Environment Created
        |
        v
Application EC2 Created
        |
        v
Prometheus discovers target
        |
        ├── :3000/metrics
        |
        └── :9100/metrics
```

When an environment is destroyed:

```text
Environment Destroyed
        |
        v
Application EC2 Removed
        |
        v
Prometheus removes target
```

**Status:** The existing monitoring setup collects metrics from the configured application target. Automatic registration and removal of targets for dynamically created environments remain planned.

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

The example is illustrative; actual credentials must be stored securely and must not be committed to source control.

PostgreSQL should not be publicly accessible.

Port `5432` should not be exposed through the application's security group.

Each isolated application environment is intended to have its own PostgreSQL instance and database.

---

# Networking

The AWS infrastructure uses AWS networking and security groups to control connectivity between the application and monitoring components.

The intended access model is:

| Resource | Port | Intended source |
|---|---:|---|
| Nginx | 443 | Public HTTPS clients |
| Nginx | 80 | Public clients, if HTTP redirect is enabled |
| NestJS | 3000 | Prometheus and authorized internal access |
| Node Exporter | 9100 | Prometheus security group |
| PostgreSQL | 5432 | Local application host |
| Prometheus | 9090 | Private/operator access |
| Alertmanager | 9093 | Private |
| Grafana | 3000 | Private/operator access, including SSM port forwarding |

SSH access should not be required for routine deployments.

The existing Terraform configuration relies on default networking in places. Therefore, this section describes the intended access model, not a claim that every listed VPC, subnet, route table, or access rule is explicitly provisioned by Terraform.

---

# Security Model

Security is based on least privilege and private service access.

## AWS IAM

IAM policies should grant only the permissions required by each component.

GitHub Actions authenticates to AWS using GitHub OIDC rather than relying on long-lived AWS access keys.

## Security Groups

Security groups should restrict communication between components.

The following services should not be publicly exposed:

- PostgreSQL
- NestJS port `3000`
- Node Exporter
- Prometheus
- Grafana
- Alertmanager

Only the required public entry point should be exposed.

## Secret Scanning

Gitleaks scans for accidentally committed secrets.

Dependency vulnerability scanning checks project dependencies for known security issues.

These checks help detect risks but do not replace correct IAM policies, network restrictions, or secure runtime configuration.

---

# AWS Systems Manager

AWS Systems Manager provides remote administration and deployment access to EC2.

It removes the need to expose SSH publicly for routine deployment operations.

Systems Manager is used for:

- Remote command execution
- Application deployment
- Operational tasks

Private service access through port forwarding can be used where configured.

For an EC2 instance to register with Systems Manager, the required instance permissions and network connectivity must be available.

---

# Infrastructure as Code

Terraform manages the AWS infrastructure.

The existing infrastructure configuration includes files for:

- EC2 instance configuration
- Ubuntu AMI lookup
- Key pair
- AWS provider
- Security groups
- Input variables

The intended long-term architecture is organized into reusable modules and environment-specific configurations.

Terraform can manage infrastructure such as:

- VPC
- Subnets
- Route tables
- Internet connectivity
- Security groups
- IAM
- Application EC2
- Prometheus EC2
- Grafana EC2
- Shared infrastructure

The current configuration relies on default networking in places, so not every item in the intended architecture is currently represented by an explicit Terraform resource.

Application-level configuration such as PostgreSQL installation, Nginx configuration, Node Exporter, systemd services, Prometheus, Grafana, and Alertmanager is handled through configuration and deployment automation.

Temporary environments should use separate Terraform state from permanent infrastructure to reduce the risk of accidental destruction.

---

# CI/CD Architecture

The implemented CI/CD workflow automates application delivery.

```text
Developer
   |
   v
Git Push
   |
   v
GitHub
   |
   v
GitHub Actions
   |
   ├── Lint
   ├── Test
   ├── Build
   ├── Gitleaks
   └── Dependency Scan
          |
          v
      GitHub OIDC
          |
          v
        AWS IAM
          |
          v
    Amazon S3 artifact
          |
          v
   AWS Systems Manager
          |
          v
    Application EC2
```

A deployment should only occur after the required quality and security checks pass.

The pipeline uses OIDC to assume the configured AWS IAM role. It stores the packaged release in S3 and invokes remote deployment operations through SSM.

---

# Deployment Strategy

The application is deployed directly to Linux.

A release follows this general flow:

```text
Source Code
    |
    v
Build
    |
    v
Package
    |
    v
Artifact Storage
    |
    v
Systems Manager
    |
    v
Application EC2
    |
    ├── Extract release
    ├── Load environment configuration
    ├── Run migrations
    ├── Restart systemd
    └── Verify readiness
```

The application uses versioned releases under:

```text
/opt/taskflow-api/releases/
```

The active release is referenced through:

```text
/opt/taskflow-api/current
```

Runtime configuration is stored at:

```text
/etc/taskflow-api/taskflow-api.env
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
              │        NestJS           │
              │        :3000            │
              │          │              │
              │          │ /metrics     │
              │          v              │
              │  Application Metrics    │
              │                        │
              │  Node Exporter :9100    │
              │          │              │
              │          v              │
              │    System Metrics       │
              └────────────┬───────────┘
                           │
                     Private Network
                           │
                           v
                  ┌─────────────────┐
                  │ Prometheus EC2   │
                  │                 │
                  │   Prometheus    │
                  │   Alertmanager  │
                  └────────┬────────┘
                           │
                         PromQL
                           │
                           v
                  ┌─────────────────┐
                  │   Grafana EC2   │
                  │                 │
                  │     Grafana     │
                  └─────────────────┘
```

There is one Node Exporter in the application monitoring path: the Node Exporter running on the application EC2 instance.

Prometheus scrapes:

```text
Application EC2 :3000/metrics
        |
        └── Application metrics

Application EC2 :9100/metrics
        |
        └── System metrics
```

Prometheus makes those metrics available to Grafana through PromQL.

## Implemented Alerting

A CPU-utilization alert has been configured to send Slack notifications when CPU usage exceeds 75%.

The alerting path is:

```text
Node Exporter
      |
      v
Prometheus scrape
      |
      v
Prometheus alert rule
      |
      v
Alertmanager
      |
      v
Slack notification
```

The notification path depends on the active Prometheus alert rules and Alertmanager receiver configuration.

Additional alerts for application availability, HTTP error rates, memory utilization, filesystem capacity, and scrape failures can be added and tested as required.

---

# Logging

Application logs are available through the systemd journal.

The application service is named `taskflow-api`.

Useful commands include:

```bash
sudo systemctl status taskflow-api
sudo journalctl -u taskflow-api
sudo journalctl -u taskflow-api -f
```

Nginx maintains its own access and error logs.

Prometheus and Grafana are responsible for metrics and visualization, not application log aggregation.

Centralized log aggregation is outside the initial project scope.

---

# Secrets Management

Secrets must never be committed to source control.

Sensitive configuration may include:

- PostgreSQL credentials
- Application secrets
- TLS credentials
- Monitoring credentials
- AWS-related secrets

Local development uses environment variables.

AWS environments should use AWS Secrets Manager where appropriate and configured.

GitHub Actions uses OIDC for AWS authentication rather than storing long-lived AWS access keys.

Gitleaks is used to detect accidentally committed secrets.

The runtime environment file is stored separately from the application release:

```text
/etc/taskflow-api/taskflow-api.env
```

Its permissions should restrict access to authorized users and processes.

---

# Self-Service Environments

The long-term goal is to allow an operator to create temporary environments through GitHub Actions.

The workflow will accept inputs such as:

```text
Environment name
Environment lifetime
```

The intended workflow is:

```text
GitHub Actions
      |
      v
Validate inputs
      |
      v
Terraform
      |
      v
Create isolated application environment
      |
      v
Deploy NestJS
      |
      v
Register monitoring targets
      |
      v
Return environment information
```

Each environment is intended to receive its own application EC2 instance and PostgreSQL database.

Prometheus will monitor the application through:

```text
Application EC2 :3000/metrics
Application EC2 :9100/metrics
```

Shared Prometheus, Grafana, and Alertmanager infrastructure remains independent of the temporary application environment.

**Implementation status:** This remains planned work. The project currently demonstrates the deployment and monitoring foundation rather than a completed self-service provisioning platform.

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
        |
        v
Identify Terraform state
        |
        v
Destroy application environment
        |
        v
Remove monitoring target
```

The cleanup process should be safe to rerun.

**Implementation status:** Manual environment destruction and automatic expiry cleanup have not been completed.

---

# Failure and Recovery

The platform is designed around basic operational recovery scenarios.

## Application Process Failure

```text
NestJS crashes
     |
     v
systemd detects failure
     |
     v
systemd restarts application
```

This behavior depends on the configured systemd service restart policy.

## Application Unavailability

```text
Prometheus
     |
     v
Application target unavailable
     |
     v
Alert rule fires
     |
     v
Alertmanager
```

The corresponding alert must be configured and tested before it can be considered operational.

## Database Unavailability

```text
NestJS
  |
  v
PostgreSQL unavailable
  |
  v
Readiness check fails
  |
  v
503 Service Unavailable
```

The readiness endpoint should return an unsuccessful response when the application cannot serve requests because a required dependency is unavailable.

## Expired Environment

```text
Scheduled cleanup
       |
       v
Expired environment detected
       |
       v
Terraform destroy
       |
       v
Temporary resources removed
```

This is part of the planned temporary-environment lifecycle.

---

# Operational Troubleshooting and Lessons Learned

## SSM Deployment Failure: No Space Left on Device

During deployment, AWS Systems Manager reported a filesystem error similar to:

```text
No space left on device
```

The error occurred while SSM was attempting to write a temporary worker file.

The underlying problem was root-filesystem exhaustion on the application EC2 instance.

### Diagnosis

I inspected filesystem capacity, block-device layout, and directory usage:

```bash
df -h /
lsblk
du -h --max-depth=1 /opt /root /var 2>/dev/null
```

The root filesystem initially had approximately 7.6 GiB of capacity and was at 100% utilization.

Investigation showed substantial disk usage under `/opt/taskflow-api`, including application releases, and under `/root/.npm`.

The npm cache occupied approximately 879 MiB.

### Resolution

#### 1. Clean the npm cache

```bash
npm cache clean --force
```

This recovered approximately 1 GiB of space. It provided immediate relief but did not permanently increase the filesystem capacity.

#### 2. Increase the root EBS volume

I updated the Terraform root block-device configuration:

```hcl
root_block_device {
  volume_size = 20
  volume_type = "gp3"
}
```

I then applied the Terraform change to increase the root EBS volume to 20 GiB.

#### 3. Expand the Linux partition and filesystem

After increasing the EBS volume, I expanded the root partition and filesystem so the operating system could use the additional capacity.

Increasing the EBS volume alone had not initially made all the new capacity available inside the root filesystem.

#### 4. Verify the result

I checked the filesystem and block-device layout again:

```bash
df -h /
lsblk
```

The final reported root-filesystem figures were approximately:

| Metric | Result |
|---|---:|
| Total filesystem capacity | 20 GiB |
| Used space | 6.8 GiB |
| Available space | 13 GiB |
| Utilization | 35% |

### Lessons learned

- EBS volume capacity, Linux partition size, and filesystem size are separate layers.
- SSM needs local disk space for working files and remote command execution.
- `df -h` shows filesystem capacity and utilization.
- `lsblk` helps inspect disks and partitions.
- `du` helps identify directories consuming disk space.
- Cache cleanup can recover space quickly, but it should not replace correcting insufficient storage capacity.
- Deployment failures can be caused by host-level resource exhaustion even when the application code and CI/CD workflow are correct.
- Release retention and disk monitoring are important operational concerns.

This incident provided hands-on experience diagnosing a deployment failure, applying an immediate mitigation, changing infrastructure through Terraform, expanding the operating-system filesystem, and verifying the result.

## Memory Pressure During Deployment

The project also encountered memory pressure during deployment.

To provide additional memory headroom, I configured persistent 2 GiB swap on the application host.

Swap can provide a buffer during temporary memory pressure, but it is not a replacement for sufficient RAM or for investigating processes that consume excessive memory.

---

# Current Implementation Status

The following table separates completed work from planned extensions.

| Capability | Status |
|---|---|
| NestJS TaskFlow API | Implemented |
| PostgreSQL and Prisma persistence | Implemented |
| Application health endpoints | Implemented |
| Application metrics endpoint | Implemented |
| Terraform-managed EC2 infrastructure | Implemented |
| Root EBS volume increased to 20 GiB | Implemented |
| Linux root partition and filesystem expanded | Implemented |
| Persistent 2 GiB swap | Configured |
| GitHub Actions CI/CD | Implemented |
| Linting, tests, and build checks | Implemented in the workflow |
| Gitleaks and dependency scanning | Included in the workflow |
| GitHub OIDC authentication to AWS | Implemented |
| S3 release artifact delivery | Implemented |
| SSM deployment operations | Implemented |
| systemd application service | Implemented |
| Versioned release directories | Implemented |
| Readiness verification | Implemented |
| Deployment rollback behavior | Implemented for deployment verification failures |
| Separate Prometheus and Grafana EC2 instances | Implemented |
| Node Exporter on application EC2 | Implemented |
| Prometheus application and host metric collection | Configured |
| Alertmanager | Configured with the monitoring setup |
| Slack CPU alert above 75% | Configured |
| Self-service temporary environment creation | Planned |
| Isolated per-environment Terraform state | Planned for temporary environments |
| Manual temporary environment destruction | Planned |
| Automatic expiry cleanup | Planned |
| Dynamic Prometheus target registration and removal | Planned |

This project has established the deployment and observability foundation. The remaining environment lifecycle features are intentionally deferred rather than represented as completed functionality.

---

# Non-Goals

The initial version intentionally excludes:

- Docker
- Docker Compose
- Kubernetes
- ECS
- EKS
- Fargate
- RDS
- Application authentication
- Frontend development
- Multi-region deployment
- High availability
- Application Auto Scaling
- Blue/green deployment
- Canary deployment
- Centralized log aggregation
- Distributed tracing
- Database replication

These technologies may be appropriate for larger production systems, but they are outside the scope of this project.

The objective is to build a complete and understandable DevOps workflow without introducing unnecessary infrastructure complexity.

---

# Definition of Done

The project is intended to meet the following objectives.

- Provision an AWS environment using Terraform.
- Deploy the NestJS application directly to EC2.
- Run PostgreSQL alongside the application.
- Manage the application through systemd.
- Serve the API through HTTPS using Nginx.
- Persist task data using PostgreSQL and Prisma.
- Expose application health endpoints.
- Expose application metrics on port `3000`.
- Expose host metrics through Node Exporter on port `9100`.
- Allow Prometheus to scrape both application and system metrics.
- Visualize metrics through Grafana.
- Evaluate alerts through Prometheus.
- Route alerts through Alertmanager.
- Run CI quality and security checks through GitHub Actions.
- Authenticate GitHub Actions to AWS using OIDC.
- Deploy through AWS Systems Manager.
- Create isolated temporary environments.
- Destroy environments manually.
- Automatically remove expired environments.
- Preserve shared monitoring infrastructure.
- Update Prometheus targets as environments are created and destroyed.
- Demonstrate application recovery after failure.
- Document deployment, troubleshooting, rollback, and cleanup procedures.

The application deployment and monitoring foundation is implemented. Temporary-environment provisioning, manual destruction, automatic cleanup, and dynamic monitoring-target management remain outstanding objectives.

---

# Learning Outcomes

This project is intended to provide practical experience with the complete lifecycle of a backend service:

```text
Code
 |
 v
Build
 |
 v
Test
 |
 v
Infrastructure
 |
 v
Deploy
 |
 v
Run
 |
 v
Monitor
 |
 v
Alert
 |
 v
Recover
 |
 v
Automate
 |
 v
Destroy temporary infrastructure
```

The project provided practical experience with:

- Managing EC2 infrastructure and EBS capacity through Terraform.
- Deploying a backend with GitHub Actions, OIDC, S3, and SSM.
- Operating a Linux service with systemd.
- Managing PostgreSQL persistence and Prisma migrations.
- Separating application metrics from host metrics.
- Using Prometheus, Grafana, and Alertmanager for observability.
- Diagnosing a real deployment failure caused by filesystem exhaustion.
- Expanding cloud storage and the Linux filesystem.
- Managing deployment-time memory pressure.
- Balancing project scope, operational reliability, and cloud cost.

The backend application provides the workload, while the surrounding infrastructure demonstrates how software can be provisioned, deployed, operated, monitored, recovered, and eventually removed through an automated cloud workflow.

The final objective is a repeatable self-service platform where creating an environment is an automated engineering workflow rather than a sequence of manual server configuration steps.

---

# Reference Documentation

- [Prometheus: Monitoring Linux host metrics with Node Exporter](https://prometheus.io/docs/guides/node-exporter/)
- [Prometheus: Grafana integration](https://prometheus.io/docs/visualization/grafana/)
- [Terraform AWS provider documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [GitHub Actions: OpenID Connect in AWS](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [AWS Systems Manager documentation](https://docs.aws.amazon.com/systems-manager/)
- [AWS EBS volume modification](https://docs.aws.amazon.com/ebs/latest/userguide/ebs-modify-volume.html)
- [AWS: Working with an RDS instance in a VPC](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_VPC.WorkingWithRDSInstanceinaVPC.html)
- [AWS: RDS security groups](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Overview.RDSSecurityGroups.html)
