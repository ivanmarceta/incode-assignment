# Local Testing with Minikube

This directory contains the local validation workflow for the backend, PostgreSQL, and optional monitoring stack.

## Scope

The local setup provides:

- a dedicated `snake-local` namespace
- PostgreSQL running inside Minikube
- the backend API installed through Helm
- optional Prometheus and Grafana installed through Helm
- helper scripts for local start, stop, and frontend configuration

## Prerequisites

- `minikube`
- `kubectl`
- `docker`
- `helm`
- `python`

## Start Minikube

```powershell
minikube start --driver=docker
```

## One-command local run

Backend, PostgreSQL, and frontend:

```powershell
.\localtesting\start-localtest.ps1 -RebuildImage
```

Backend, PostgreSQL, frontend, Prometheus, and Grafana:

```powershell
.\localtesting\start-localtest.ps1 -RebuildImage -WithMonitoring
```

The start script performs the following actions:

- starts Minikube if required
- optionally rebuilds the backend image inside Minikube
- applies the local PostgreSQL overlay
- installs the `snake-api` Helm release
- optionally installs `kube-prometheus-stack`
- optionally installs the provisioned Grafana dashboard
- writes `app/public/config.js`
- starts local port-forwards
- starts a local static frontend server

## Local URLs

Default forwarded URLs:

- frontend: `http://localhost:4173`
- backend: `http://127.0.0.1:18080`
- Grafana: `http://127.0.0.1:13000`
- Prometheus: `http://127.0.0.1:19090`

Grafana username:

- `admin`

Grafana password can be read from the generated Kubernetes secret:

```powershell
kubectl get secret monitoring-grafana -n monitoring -o jsonpath="{.data.admin-password}" | %{ [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_)) }
```

The default dashboard is provisioned from [`../helm/snake-grafana-dashboards`](../helm/snake-grafana-dashboards).

## Manual workflow

Build the backend image into Minikube:

```powershell
minikube image build -t incode-snake-backend:local .\backend
```

Apply the local PostgreSQL overlay:

```powershell
kubectl apply -k .\localtesting\overlay
```

Install the backend Helm chart:

```powershell
helm upgrade --install snake-api .\helm\snake-api -n snake-local --create-namespace -f .\helm\values-local.yaml
```

If Prometheus Operator CRDs already exist, enable the `ServiceMonitor`:

```powershell
helm upgrade --install snake-api .\helm\snake-api -n snake-local --create-namespace -f .\helm\values-local.yaml --set monitoring.serviceMonitor.enabled=true
```

Install Prometheus and Grafana:

```powershell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace -f .\helm\monitoring-values.yaml
```

Port-forward the backend:

```powershell
kubectl port-forward svc/snake-api 18080:80 -n snake-local
```

Generate local frontend configuration:

```powershell
.\localtesting\write-frontend-config.ps1
```

Serve the frontend:

```powershell
cd app\public
python -m http.server 4173
```

## Verification

```powershell
kubectl get pods -n snake-local
kubectl get svc -n snake-local
kubectl logs deployment/snake-api -n snake-local
kubectl get servicemonitor -n snake-local
```

## Shutdown

Stop background processes, uninstall Helm releases, and optionally delete namespaces:

```powershell
.\localtesting\stop-localtest.ps1 -DeleteNamespace
```
