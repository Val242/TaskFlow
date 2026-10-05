# Self-Service AWS Deployment Platform

A DevOps learning project that provisions temporary AWS environments, deploys a TypeScript and NestJS task API directly to EC2, and monitors the application with Prometheus and Grafana.

**Status:** Architecture and implementation plan. The infrastructure, workflows, and monitoring described below are intended behavior and have not yet been implemented or verified.

## Project scope

The project focuses on backend development, infrastructure automation, continuous delivery, monitoring, and environment cleanup. Services run directly on Linux without Docker. API clients use a browser for GET requests, Postman, or curl; a frontend is outside the initial scope.

The initial design uses one AWS region, one application EC2 instance per environment, private RDS PostgreSQL, and a shared monitoring EC2 instance. This is a learning architecture with single points of failure, not a highly available production deployment.

## Technology stack

| Component | Technology | Purpose |
| --- | --- | --- |
| Backend | TypeScript, NestJS, Node.js | Serve the task API |
| Database access | Prisma | Query PostgreSQL and manage schema migrations |
| Database | Amazon RDS PostgreSQL | Persist task data privately |
| Reverse proxy | Nginx | Terminate HTTPS and forward requests to NestJS |
| Process management | systemd | Start services at boot and restart failed processes |
| Infrastructure | Terraform | Provision repeatable AWS environments |
| CI/CD | GitHub Actions | Check code, package releases, and deploy |
| Deployment transport | AWS Systems Manager and S3 | Execute deployment commands and deliver release packages |
| Credentials | AWS Secrets Manager and IAM roles | Supply runtime secrets and AWS permissions |
| Host metrics | Node Exporter | Expose Linux system metrics |
| Metrics storage | Prometheus | Scrape and store time-series metrics |
| Dashboards | Grafana | Query Prometheus and visualize metrics |
| Alert routing | Alertmanager | Group and route Prometheus alerts |
| Security checks | Gitleaks and dependency scanning | Detect exposed secrets and vulnerable dependencies |

## Architecture diagram

Arrows show the component initiating a connection. Prometheus initiates scraping; exporters return metrics in the response.

```mermaid
flowchart TD
    U["API client"]
    O["Operator"]
    subgraph VPC["AWS VPC"]
        subgraph APP["Application EC2 - public subnet"]
            N["Nginx - HTTPS 443"]
            A["NestJS - port 3000"]
            E["Node Exporter - port 9100"]
        end
        D["Private RDS PostgreSQL - port 5432"]
        subgraph MON["Shared monitoring EC2"]
            G["Grafana - localhost 3000"]
            P["Prometheus - localhost 9090"]
            M["Alertmanager - localhost 9093"]
        end
    end
    U -->|"HTTPS"| N
    N -->|"Local HTTP forwarding"| A
    A -->|"PostgreSQL with TLS"| D
    P -->|"Private HTTP scrape: 3000/metrics"| A
    P -->|"Private HTTP scrape: 9100/metrics"| E
    G -->|"PromQL queries"| P
    P -->|"Firing and resolved alerts"| M
    O -->|"Systems Manager port forwarding"| G
```

Grafana and NestJS can both use port 3000 because they run on different EC2 instances.

## User request flow

1. The client resolves the API hostname and sends an HTTPS request on port 443.
2. The application security group permits the request from the intended clients.
3. Nginx receives the request and terminates TLS using a valid certificate for the hostname.
4. Nginx forwards API traffic to NestJS on the same instance, using port 3000.
5. NestJS validates the request and executes the relevant application logic.
6. If data is required, Prisma connects to private RDS PostgreSQL on port 5432.
7. NestJS returns a response through Nginx to the client.

Opening port 443 only permits traffic; Nginx must also be configured to listen on that port with a certificate. Port 80 may redirect HTTP requests to HTTPS. DNS, certificate issuance, and renewal must be configured as part of deployment.

Nginx must block public requests to `/metrics`. Direct access to port 3000 is allowed only from the monitoring security group. NestJS must listen on an interface reachable through the EC2 private address for scraping, rather than exclusively on localhost.

## Task API

Each task contains an ID, title, optional description, status, creation timestamp, and update timestamp. Valid statuses are `TODO`, `IN_PROGRESS`, and `DONE`.

| Method | Endpoint | Behavior |
| --- | --- | --- |
| POST | `/tasks` | Create a task |
| GET | `/tasks` | List tasks |
| GET | `/tasks/:id` | Retrieve one task |
| PATCH | `/tasks/:id` | Update a task |
| DELETE | `/tasks/:id` | Delete a task |
| GET | `/health/live` | Confirm the application process responds |
| GET | `/health/ready` | Check application readiness, including database connectivity |
| GET | `/metrics` | Expose Prometheus metrics privately |

Invalid input returns HTTP 400. A missing task returns 404. A failed readiness check returns 503. Restarting the application must not delete tasks.

Authentication is deferred for the initial demonstration. Use synthetic data and restrict API access to the intended testers while this is the case.

## Database connection

The application uses a PostgreSQL connection string, normally supplied as `DATABASE_URL`:

```dotenv
# Illustrative placeholders only; TLS settings must also be configured.
DATABASE_URL="postgresql://app_user:YOUR_PASSWORD@YOUR_RDS_ENDPOINT:5432/tasksdb"
```

| Field | Meaning |
| --- | --- |
| `postgresql://` | Database protocol |
| `app_user` | Application database user |
| `YOUR_PASSWORD` | Database password; URL-encode reserved characters |
| `YOUR_RDS_ENDPOINT` | AWS-provided database hostname |
| `5432` | PostgreSQL port |
| `tasksdb` | Application database name |

Configure the selected Prisma client/driver for TLS and server certificate verification using the AWS RDS CA. The example above illustrates the address and credentials, not a complete production TLS configuration.

RDS is not publicly accessible. Its security group accepts connections from the application security group only. The connection string supplies addressing and authentication; it does not bypass security groups or routing.

Store credentials in Secrets Manager. The application instance role receives permission to read only its required secret. Startup logic must explicitly retrieve and load the secret; creating a secret does not automatically inject it into Node.js. Use a restricted runtime database user, with migration permissions handled separately where practical.

For local development, use local PostgreSQL and an ignored `.env` file. A laptop cannot directly reach private RDS without an approved network path or tunnel.

## Monitoring flow

### Host metrics

Node Exporter runs on the application EC2 instance and exposes metrics at:

```text
http://APP_PRIVATE_IP:9100/metrics
```

Prometheus pulls CPU, memory, filesystem, disk I/O, and network metrics from this endpoint. Node Exporter measures the host; it does not automatically measure API route performance or RDS internals.

### Application metrics

NestJS exposes a separately instrumented endpoint:

```text
http://APP_PRIVATE_IP:3000/metrics
```

Simply running NestJS on port 3000 does not create metrics. Add instrumentation for request counts, duration histograms, server errors, and Node.js runtime metrics. Use normalized route labels such as `/tasks/:id`; avoid individual task IDs, user IDs, or raw URLs as labels.

Prometheus scrapes both targets on a schedule, independently of user requests. A starting scrape interval is 15 seconds. Refresh targets when temporary environments are created, replaced, or deleted, using tag-based EC2 discovery or generated target configuration.

### Grafana dashboards

Grafana uses Prometheus at `http://localhost:9090` because both services run on the monitoring instance. It queries stored metrics using PromQL and displays:

- Request rate by API route.
- Percentage of HTTP 5xx responses.
- Response time at the 95th percentile.
- Prometheus target scrape availability.
- Node.js process memory.
- Host CPU, memory, disk, and network usage.

Scrape availability does not prove that the public HTTPS path works. Verify that path with deployment smoke tests; external probing can be added later. Application and host metrics together support scaling decisions, but high CPU alone does not determine whether horizontal or vertical scaling is appropriate.

### Alerts and access

Prometheus evaluates alert rules for unavailable targets and sustained server errors. Alertmanager groups alerts and routes them to a receiver configured during implementation. Test both firing and resolution behavior.

Use Systems Manager port forwarding for operator access to Grafana. Bind Grafana, Prometheus, and Alertmanager to localhost when only local/tunneled access is required. Their mutual local connections do not need inbound security group rules.

Persist monitoring data on EBS, with configured retention. Keep dashboard definitions, alert rules, and service configuration in Git. The shared monitoring stack remains when a temporary application environment is destroyed.

## Network and security rules

All listed ports use TCP.

| Destination | Port | Allowed source | Purpose |
| --- | --- | --- | --- |
| Application Nginx | 443 | Intended API clients | HTTPS API access |
| Application Nginx | 80 | Intended clients, if enabled | HTTP-to-HTTPS redirect |
| Application NestJS | 3000 | Monitoring security group | Private application scraping |
| Application Node Exporter | 9100 | Monitoring security group | Private host scraping |
| RDS PostgreSQL | 5432 | Application security group | Database queries and migrations |
| Grafana | 3000 | Localhost via tunnel | Operator dashboards |
| Prometheus | 9090 | Localhost | Grafana queries |
| Alertmanager | 9093 | Localhost | Prometheus alerts |

Place RDS in a DB subnet group spanning private subnets in at least two Availability Zones. This subnet layout does not itself enable Multi-AZ database failover.

The application instance uses a public subnet for direct Nginx ingress. Monitoring uses private addresses to reach exporters. The monitoring instance may use a private subnet with outbound access through NAT or suitable VPC endpoints. Decide this before provisioning because it affects cost and access to package repositories.

Systems Manager requires its agent, instance permissions, and outbound access to the necessary AWS endpoints. GitHub Actions deployment does not require opening SSH to the internet. Configure outbound connectivity for secrets retrieval, release downloads, and required service calls.

## Infrastructure and deployment flow

Terraform manages networking, security groups, IAM, EC2, RDS, and supporting resources. Use remote state with locking, separate state per application environment, and separate state for shared/bootstrap infrastructure. Treat state as sensitive.

The intended GitHub Actions flow is:

1. Check out the selected commit and install locked dependencies.
2. Run linting, tests, compilation, Gitleaks, and dependency security checks.
3. Authenticate to AWS using OIDC and a restricted role.
4. Provision or update the selected environment through Terraform.
5. Package the NestJS release and upload it to a restricted S3 location.
6. Use Systems Manager to download and install the release on EC2.
7. Load required configuration and execute Prisma migrations from inside the VPC.
8. Restart the NestJS systemd service and run readiness and HTTPS smoke tests.

Build for the target Linux runtime and architecture, including any Prisma runtime dependencies. Keep a previous release for application rollback. Database migrations require their own recovery strategy; rolling back code does not automatically reverse schema changes.

Systemd starts the application at boot and restarts failed processes. Application logs go to the systemd journal, with Nginx access/error logs available separately. Prometheus stores metrics, not application logs.

## Self-service environments and cleanup

A manually triggered workflow accepts an environment name and lifetime. It validates the inputs, creates isolated application resources, deploys the API, and reports the URL. Tag resources with project, environment, and expiry time.

A scheduled workflow finds expired environments and destroys their specific Terraform state-managed resources. A manual workflow supports early deletion. Serialize provisioning and destruction for the same environment to prevent overlapping changes.

Automatic expiry runs on the next successful scheduled check, not necessarily at the exact expiry timestamp. Temporary database data is disposable; define snapshot retention explicitly. Shared monitoring, remote state storage, and release infrastructure must remain outside temporary destruction targets.

## Seven-day implementation roadmap

| Day | Deliverable |
| --- | --- |
| 1 | NestJS task API, local PostgreSQL, Prisma migrations, and validation |
| 2 | Tests, health endpoints, application metrics, and local monitoring |
| 3 | Terraform networking, application EC2, IAM, and private RDS |
| 4 | CI checks, release packaging, Systems Manager deployment, and systemd |
| 5 | Shared monitoring EC2, dashboards, target discovery, and alerts |
| 6 | Self-service inputs, environment isolation, manual deletion, and expiry cleanup |
| 7 | End-to-end verification, recovery exercise, documentation, and demo |

## Definition of done

- A fresh environment can be provisioned and deployed through GitHub Actions.
- Task data survives an application restart.
- Public HTTPS works; `/metrics` and the database are not publicly exposed.
- Prometheus scrapes both application and host metrics.
- Grafana dashboards respond to test traffic.
- A controlled failure triggers an alert that resolves after recovery.
- Rebooting EC2 automatically starts the application.
- Expiry cleanup removes only the intended temporary environment.
- The repository contains reproducible instructions and measured deployment/recovery results.

## Reference documentation

- [Prometheus: Monitoring Linux host metrics with Node Exporter](https://prometheus.io/docs/guides/node-exporter/)
- [Prometheus: Grafana integration](https://prometheus.io/docs/visualization/grafana/)
- [AWS: Working with an RDS instance in a VPC](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_VPC.WorkingWithRDSInstanceinaVPC.html)
- [AWS: RDS security groups](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Overview.RDSSecurityGroups.html)
