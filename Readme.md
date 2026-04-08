# Incode SRE Take-Home

This repository contains a cost-conscious AWS infrastructure design plus a small demo application with persistent highscores. The infrastructure layer is managed with Terraform, while the Kubernetes application layer is packaged with Helm. A separate local Minikube workflow is included so the backend, PostgreSQL, and frontend can be exercised without AWS access.

## Current layout

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
|   `-- snake-api/
|       |-- Chart.yaml
|       |-- values.yaml
|       `-- templates/
|-- localtesting/
|   |-- config.js.example
|   |-- overlay/
|   |-- README.md
|   |-- start-localtest.ps1
|   |-- stop-localtest.ps1
|   `-- write-frontend-config.ps1
|-- modules/
|   |-- eks/
|   |-- network/
|   `-- rds/
|-- scripts/
|   `-- bootstrap.ps1
|-- .gitignore
`-- Readme.md
```

## Target design

- AWS VPC across two availability zones
- Public, private, and database subnets
- Amazon EKS with a small managed node group optimized for low cost
- PostgreSQL on Amazon RDS, reachable from the cluster but not public
- Static snake frontend hosted separately
- Backend API deployed as a Kubernetes workload
- Prometheus and Grafana deployed with Helm

## Naming and tagging

Resources are named from `project` and `environment` using:

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

`envs/dev` is the Terraform entry point and wires:

- `modules/network`
- `modules/eks`
- `modules/rds`

This keeps the infrastructure modular while still being small enough to explain clearly in an interview.

## Helm deployment

The Kubernetes app layer is Helm-based.

`helm/snake-api` contains the application chart for the backend API, including:

- Deployment
- Service
- optional Secret creation
- optional ServiceMonitor for Prometheus scraping

Environment-specific values live in:

- `helm/values-local.yaml`
- `helm/values-aws.yaml`

Prometheus and Grafana use the official `prometheus-community/kube-prometheus-stack` chart with values in:

- `helm/monitoring-values.yaml`

Provisioned Grafana dashboards are stored in:

- `helm/snake-grafana-dashboards`

## Leaderboard model

The backend stores one row per player in PostgreSQL:

- `id`
- `username`
- `highest_score`
- `updated_at`

`username` is unique. Submitting the same username again updates only the stored high score when the new score is higher than the existing one.

## Metrics and observability

The backend exposes:

- `/healthz`
- `/metrics`

Metrics are generated with `prom-client` and include:

- process/runtime default metrics
- HTTP request count
- HTTP request duration
- score submission count

When the Helm chart is installed with ServiceMonitor enabled and `kube-prometheus-stack` is present, Prometheus can scrape the backend automatically.

An interview-ready query and dashboard guide is included in [`docs/observability.md`](C:\Users\ivanm\projekti\incode\incode-assignment\docs\observability.md).

## Local testing

`localtesting/` contains the local-only workflow.

It includes:

- local PostgreSQL manifests under `localtesting/overlay/`
- a script to generate frontend config from the local backend URL
- one-command start and stop scripts

Quick local run:

```powershell
minikube start --driver=docker
.\localtesting\start-localtest.ps1 -RebuildImage -WithMonitoring
```

This will:

- start Minikube automatically if needed
- rebuild the backend image in Minikube
- apply the local PostgreSQL overlay
- install the backend via Helm
- optionally install Prometheus and Grafana via Helm
- write `app/public/config.js`
- start background port-forwards and the static frontend server
- expose Grafana on `http://127.0.0.1:13000`
- expose Prometheus on `http://127.0.0.1:19090`

To stop everything:

```powershell
.\localtesting\stop-localtest.ps1 -DeleteNamespace
```

See `localtesting/README.md` for the detailed local runbook.

## AWS deployment flow

Once AWS access is available:

1. Configure AWS credentials.
2. Create `terraform.tfvars` from `envs/dev/terraform.tfvars.example`.
3. Run Terraform in `envs/dev`.
4. Build and push the backend image.
5. Create the `demo` namespace.
6. Create the database secret from `helm/examples/aws-database-secret.yaml.example`.
7. Deploy the backend:

```powershell
helm upgrade --install snake-api .\helm\snake-api -n demo -f .\helm\values-aws.yaml
```

8. Optionally install monitoring:

```powershell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace -f .\helm\monitoring-values.yaml
```

9. If monitoring is installed, enable the backend `ServiceMonitor`:

```powershell
helm upgrade --install snake-api .\helm\snake-api -n demo -f .\helm\values-aws.yaml --set monitoring.serviceMonitor.enabled=true
```

10. Publish `app/public` to static hosting and provide the backend API URL in `config.js`.
11. Verify reachability, health checks, metrics scraping, Grafana dashboards, and leaderboard persistence.

Grafana default credentials from [`helm/monitoring-values.yaml`](C:\Users\ivanm\projekti\incode\incode-assignment\helm\monitoring-values.yaml):

- username: `admin`
- password: `admin123`

## Assumptions

- Initial region is `eu-central-1`
- Two availability zones are sufficient for the exercise
- Cost optimization is more important than high availability
- The static frontend is better hosted outside Kubernetes
- The backend is the Kubernetes workload required by the assignment
- Secrets are not committed and should be injected at deploy time

## Interview framing

The solution intentionally favors clarity over unnecessary complexity:

- Terraform for infra
- Helm for app deployment
- Helm for monitoring stack
- static frontend outside the cluster
- persistent backend backed by PostgreSQL
- local Minikube path for fast validation

That gives you a straightforward path to explain trade-offs, make changes live, and discuss how the design would evolve in a more production-heavy environment.
