# Incode SRE Take-Home

This repository contains an AWS-based deployment of a small Snake application with a PostgreSQL-backed leaderboard and optional Prometheus/Grafana monitoring.

## What Is In Scope

- Terraform provisions the AWS foundation:
  - VPC
  - public/private/database subnets
  - EKS
  - RDS PostgreSQL
- Helm deploys the Kubernetes workloads:
  - `snake-api` backend
  - `snake-frontend` nginx-based static frontend
  - optional monitoring stack and Grafana dashboard

## Current Architecture

- frontend is a separate Kubernetes workload in namespace `frontend`
- backend is a separate Kubernetes workload in namespace `snake`
- frontend is public through a `LoadBalancer` service
- backend is private behind a `ClusterIP` service
- frontend proxies `/api/*` to `snake-api.snake.svc.cluster.local`
- backend persists highscores in PostgreSQL on RDS
- Prometheus scrapes backend metrics through a `ServiceMonitor` when monitoring is enabled

More detail is in [`docs/architecture.md`](docs/architecture.md).

## Frontend Hosting Note

I also explored an S3 + CloudFront frontend.

The main blocker there was the API endpoint:

- CloudFront served the frontend over HTTPS
- the backend initially exposed an AWS-generated load balancer hostname
- a proper HTTPS API endpoint would have required a domain name I control so I could provision and attach the right ACM certificate

Rather than leave the project in a mixed-content or drift-prone state, I switched to the cleaner fallback for this exercise:

- public frontend workload
- private backend service inside the cluster
- same-origin API access through nginx proxying

## Repository Layout

```text
.
|-- .github/workflows/
|   |-- application-deploy.yml
|   `-- terraform.yml
|-- app/public/
|   |-- config.js.example
|   `-- index.html
|-- backend/
|   |-- Dockerfile
|   |-- package.json
|   `-- server.js
|-- docs/
|   |-- architecture.md
|   `-- observability.md
|-- envs/dev/
|   |-- main.tf
|   |-- outputs.tf
|   |-- terraform.tfvars.example
|   `-- variables.tf
|-- helm/
|   |-- monitoring-values.yaml
|   |-- snake-api/
|   |-- snake-frontend/
|   |-- snake-grafana-dashboards/
|   |-- values-aws.yaml
|   `-- values-local.yaml
|-- localtesting/
|-- modules/
|   |-- eks/
|   |-- network/
|   `-- rds/
`-- Readme.md
```

## Terraform

Terraform entry point: [`envs/dev/main.tf`](envs/dev/main.tf)

Modules:

- [`modules/network`](modules/network)
- [`modules/eks`](modules/eks)
- [`modules/rds`](modules/rds)

State backend:

- S3 remote state
- S3 lockfile enabled

Default dev sizing:

- EKS managed node group desired size: `2`
- EKS managed node group max size: `2`
- instance type: `t3.small`

## GitHub Actions

### Terraform workflow

Workflow file: [`.github/workflows/terraform.yml`](.github/workflows/terraform.yml)

Behavior:

- runs `fmt`, `init`, `validate`, and `plan`
- uploads the saved Terraform plan as an artifact
- optionally applies the exact saved `tfplan` when `apply=true`

### Application workflow

Workflow file: [`.github/workflows/application-deploy.yml`](.github/workflows/application-deploy.yml)

Behavior:

- builds and pushes backend image to GHCR
- updates kubeconfig for the EKS cluster
- reads the AWS-managed RDS secret from Secrets Manager
- creates/updates the Kubernetes DB secret used by the backend
- creates/updates the GHCR image pull secret
- optionally upgrades monitoring
- deploys backend via Helm
- deploys frontend via Helm
- prints the public frontend URL

## Required Repository Settings

### Variables

- `TF_VAR_PROJECT`
- `TF_VAR_ENVIRONMENT`
- `TF_VAR_OWNER`
- `TF_VAR_REPOSITORY`
- `TF_VAR_AWS_REGION`
- `TF_VAR_DATABASE_NAME`
- `TF_VAR_DATABASE_USERNAME`
- `K8S_NAMESPACE`
- `FRONTEND_NAMESPACE`
- `TF_STATE_BUCKET`

Optional:

- `TF_STATE_KEY` default: `envs/dev/terraform.tfstate`
- `GHCR_USERNAME` default: repository owner

### Secrets

- `AWS_ROLE_ARN`
- `GHCR_PULL_TOKEN`
- `GRAFANA_ADMIN_PASSWORD`

## Helm Charts

- [`helm/snake-api`](helm/snake-api): backend API
- [`helm/snake-frontend`](helm/snake-frontend): public frontend nginx workload
- [`helm/snake-grafana-dashboards`](helm/snake-grafana-dashboards): provisioned Grafana dashboard

AWS values file: [`helm/values-aws.yaml`](helm/values-aws.yaml)

Important runtime behavior:

- backend service type is `ClusterIP`
- frontend service type is `LoadBalancer`
- frontend nginx proxies `/api/*` to the private backend service

## Data Model

The leaderboard stores:

- `id`
- `username`
- `highest_score`
- `updated_at`

Rules:

- one row per username
- lower subsequent score does not overwrite a higher score
- higher subsequent score updates both score and timestamp

## Secrets Model

AWS deployment uses AWS-managed RDS master credentials:

- Terraform creates the RDS instance
- AWS creates and stores the password in Secrets Manager
- application workflow reads that secret and creates a Kubernetes secret named `snake-api-db`

This keeps the database password out of Terraform variables and GitHub repository variables.

## Metrics

The backend exposes:

- `/healthz`
- `/metrics`

Metrics cover:

- HTTP request counts and latency
- health checks
- leaderboard reads
- score submission outcomes
- score rejection reasons
- DB query counts and latency
- PostgreSQL pool state
- default Node.js/process metrics

See [`docs/observability.md`](docs/observability.md).

## Local Testing

Local testing documentation: [`localtesting/README.md`](localtesting/README.md)

Local flow uses:

- Minikube
- in-cluster PostgreSQL
- Helm backend deploy
- local static frontend server
- optional Prometheus and Grafana

## Notes

- infrastructure is declarative in Terraform
- Kubernetes deployment is packaged with Helm
- frontend and backend are separated into different workloads and namespaces
- backend remains private inside the cluster
- monitoring is available but increases node pod pressure on a single-node cluster

## Known Trade-Offs

- monitoring on a single `t3.small` node can exhaust pod slots; the dev defaults were raised to 2 nodes to make the stack reliable
- monitoring is still coupled to the application workflow as an optional step instead of a separate workflow
- AWS deployment uses public frontend `LoadBalancer` rather than a custom-domain ingress architecture
