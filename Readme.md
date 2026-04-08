# Incode SRE Take-Home

This repository contains a draft solution for the Incode SRE take-home assessment. The AWS infrastructure layer is defined with Terraform. The Kubernetes application layer and monitoring stack are defined with Helm.

## Repository layout

```text
.
|-- app/
|   `-- public/
|       |-- config.js.example
|       `-- index.html
|-- backend/
|   |-- Dockerfile
|   |-- package.json
|   `-- server.js
|-- docs/
|   |-- architecture.md
|   `-- observability.md
|-- envs/
|   `-- dev/
|       |-- main.tf
|       |-- outputs.tf
|       |-- terraform.tfvars.example
|       `-- variables.tf
|-- helm/
|   |-- examples/
|   |   `-- aws-database-secret.yaml.example
|   |-- monitoring-values.yaml
|   |-- values-aws.yaml
|   |-- values-local.yaml
|   |-- snake-api/
|   `-- snake-grafana-dashboards/
|-- localtesting/
|   |-- config.js.example
|   |-- overlay/
|   |-- README.md
|   |-- start-localtest.ps1
|   |-- stop-localtest.ps1
|   `-- write-frontend-config.ps1
|-- modules/
|   |-- eks/
|   |-- frontend/
|   |-- network/
|   `-- rds/
|-- .github/
|   `-- workflows/
|       |-- application-deploy.yml
|       `-- terraform.yml
|-- .gitignore
`-- Readme.md
```

## Architecture summary

- AWS VPC spanning two availability zones
- public, private, and database subnet tiers
- Amazon EKS with a low-cost managed node group
- Amazon RDS for PostgreSQL, reachable from the application tier only
- static frontend hosted on Terraform-managed Amazon S3 and CloudFront
- backend API deployed as the Kubernetes workload
- Prometheus and Grafana deployed with Helm

Additional architecture detail is documented in [`docs/architecture.md`](docs/architecture.md).

## Naming and tagging

Resources follow the naming pattern:

```text
<project>-<environment>-<component>
```

Standard AWS tags are applied through the provider `default_tags` block:

- `Project`
- `Environment`
- `ManagedBy=terraform`
- `Owner`
- `Repository`

## Terraform

The Terraform entry point is [`envs/dev`](envs/dev). It composes the following modules:

- `modules/network`
- `modules/eks`
- `modules/rds`
- `modules/frontend`

This keeps the infrastructure modular while remaining small enough to review and explain during the interview.

Terraform state is stored in an S3 backend with S3 lockfile support enabled.

## GitHub Actions workflows

The repository uses separate workflows for infrastructure and application deployment:

- Terraform workflow: [`.github/workflows/terraform.yml`](.github/workflows/terraform.yml)
- application deployment workflow: [`.github/workflows/application-deploy.yml`](.github/workflows/application-deploy.yml)

Both workflows are intended for ad hoc execution through `workflow_dispatch`.

Repository variables used by the workflows:

- `TF_VAR_PROJECT`
- `TF_VAR_ENVIRONMENT`
- `TF_VAR_OWNER`
- `TF_VAR_REPOSITORY`
- `TF_VAR_AWS_REGION`
- `TF_VAR_DATABASE_NAME`
- `TF_VAR_DATABASE_USERNAME`
- `K8S_NAMESPACE`
- `TF_STATE_BUCKET`

Optional repository variables:

- `TF_STATE_KEY` (defaults to `envs/dev/terraform.tfstate`)

Repository secrets used by the workflows:

- `AWS_ROLE_ARN`
- `GRAFANA_ADMIN_PASSWORD`

The application deployment workflow performs the following tasks:

- builds and pushes the backend image to GHCR
- discovers the EKS cluster and RDS instance from the configured naming convention
- discovers the Terraform-managed frontend bucket and CloudFront distribution
- reads the AWS-managed RDS credential from Secrets Manager
- creates or updates the Kubernetes secret consumed by the backend
- deploys the backend via Helm
- optionally deploys Prometheus, Grafana, and the provisioned dashboard
- optionally publishes the static frontend to S3 and invalidates CloudFront

Additional repository variables used by the application workflow when exposing the
API through ingress:

- `API_HOSTNAME`
- `API_CERT_ARN`

Additional repository secrets used by the application workflow:

- `GHCR_PULL_TOKEN`

## Helm

The Kubernetes application layer is Helm-based.

Charts in this repository:

- [`helm/snake-api`](helm/snake-api) for the backend API
- [`helm/snake-grafana-dashboards`](helm/snake-grafana-dashboards) for the provisioned Grafana dashboard

Values files:

- [`helm/values-local.yaml`](helm/values-local.yaml)
- [`helm/values-aws.yaml`](helm/values-aws.yaml)
- [`helm/monitoring-values.yaml`](helm/monitoring-values.yaml)

Prometheus and Grafana are deployed through the `prometheus-community/kube-prometheus-stack` chart.

## Application data model

The backend stores one leaderboard row per username in PostgreSQL:

- `id`
- `username`
- `highest_score`
- `updated_at`

Behavior:

- `username` is unique
- a new username creates a row
- a lower subsequent score leaves the stored high score unchanged
- a higher subsequent score updates the stored high score and timestamp

## Secrets handling

For AWS, the RDS module is configured to use AWS-managed master credentials.

This means:

- Terraform creates the RDS instance
- AWS generates the master password
- AWS stores that password in Secrets Manager
- Terraform exposes the secret ARN through `rds_master_user_secret_arn`

This avoids storing a database password in the repository or Terraform variables.

Local testing uses disposable demo credentials only for the Minikube workflow.

## Metrics and observability

The backend exposes:

- `/healthz`
- `/metrics`

The exported metrics include:

- Node.js runtime and process metrics
- HTTP request counts
- HTTP request latency
- health check results
- leaderboard request counts
- score submission outcomes
- invalid submission reasons
- high-score upsert outcomes
- database query counts and latency
- PostgreSQL connection pool gauges

Prometheus scrapes the backend through a `ServiceMonitor` when monitoring is enabled. Grafana consumes Prometheus as its data source. An observability guide with Prometheus queries and dashboard notes is available in [`docs/observability.md`](docs/observability.md).

## Local testing

The local validation workflow is documented in [`localtesting/README.md`](localtesting/README.md).

The local setup includes:

- PostgreSQL inside Minikube
- Helm deployment of the backend
- optional Helm deployment of Prometheus and Grafana
- helper scripts for frontend config generation and local start/stop

## AWS deployment flow

1. Run the Terraform workflow at [`.github/workflows/terraform.yml`](.github/workflows/terraform.yml).
2. Confirm that the workflow created the VPC, EKS cluster, RDS instance, AWS-managed RDS credential, S3 bucket, and CloudFront distribution.
3. Ensure the AWS Load Balancer Controller and its IAM prerequisites are installed in the EKS cluster if you plan to expose the API via ingress.
4. Run the application workflow at [`.github/workflows/application-deploy.yml`](.github/workflows/application-deploy.yml).
5. Confirm that the application workflow:
   - builds and publishes the backend image
   - reads the RDS credential from Secrets Manager
   - creates or updates the Kubernetes secret `demo-api-db`
   - deploys the backend Helm release
   - optionally creates an ingress-backed public API endpoint when `API_HOSTNAME` and `API_CERT_ARN` are configured
   - optionally deploys monitoring and dashboard provisioning
   - optionally publishes the static frontend to the Terraform-managed S3 bucket and invalidates CloudFront
6. Verify:
   - backend connectivity to RDS
   - public application reachability
   - `/healthz` and `/metrics`
   - Prometheus scraping
   - Grafana dashboard availability
   - leaderboard persistence

## Assumptions

- initial region is `us-east-1`
- two availability zones are sufficient for this exercise
- cost efficiency is prioritized over high availability
- the frontend is better hosted as a static site outside the cluster
- the backend is the Kubernetes workload required by the assessment
