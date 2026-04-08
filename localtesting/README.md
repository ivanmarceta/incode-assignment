# Local Testing with Minikube

This directory contains the local-only workflow for validating the backend, PostgreSQL, and optional monitoring stack without AWS access.

## What this gives you

- a dedicated `snake-local` namespace
- PostgreSQL running inside Minikube
- the backend API installed through Helm
- local frontend config generation
- optional Prometheus and Grafana installed through Helm
- one-command start and stop scripts

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

Backend + PostgreSQL + frontend:

```powershell
.\localtesting\start-localtest.ps1 -RebuildImage
```

Backend + PostgreSQL + frontend + Prometheus + Grafana:

```powershell
.\localtesting\start-localtest.ps1 -RebuildImage -WithMonitoring
```

The script will:

- start Minikube automatically if needed
- optionally rebuild the backend image in Minikube
- apply the local PostgreSQL overlay
- install the `snake-api` Helm chart into `snake-local`
- optionally install `kube-prometheus-stack` into `monitoring` before enabling the app `ServiceMonitor`
- install a Helm-managed Grafana dashboard automatically when monitoring is enabled
- write [`app/public/config.js`](C:\Users\ivanm\projekti\incode\incode-assignment\app\public\config.js)
- start a backend port-forward
- start a static frontend server
- optionally start Grafana and Prometheus port-forwards

## URLs

Default local URLs are:

- frontend: `http://localhost:4173`
- backend: `http://127.0.0.1:18080`
- Grafana: `http://127.0.0.1:13000`
- Prometheus: `http://127.0.0.1:19090`

Grafana credentials from [`helm/monitoring-values.yaml`](C:\Users\ivanm\projekti\incode\incode-assignment\helm\monitoring-values.yaml):

- username: `admin`
- password: `admin123`

The dashboard is provisioned automatically from [`helm/snake-grafana-dashboards`](C:\Users\ivanm\projekti\incode\incode-assignment\helm\snake-grafana-dashboards).

## Manual flow

Build the backend image into Minikube:

```powershell
minikube image build -t incode-snake-backend:local .\backend
```

Apply the local PostgreSQL overlay:

```powershell
kubectl apply -k .\localtesting\overlay
```

Install the backend with Helm:

```powershell
helm upgrade --install snake-api .\helm\snake-api -n snake-local --create-namespace -f .\helm\values-local.yaml
```

If Prometheus Operator CRDs are already installed, you can enable the app `ServiceMonitor` too:

```powershell
helm upgrade --install snake-api .\helm\snake-api -n snake-local --create-namespace -f .\helm\values-local.yaml --set monitoring.serviceMonitor.enabled=true
```

Install Prometheus and Grafana:

```powershell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace -f .\helm\monitoring-values.yaml
```

Port-forward the backend manually if you are not using the start script:

```powershell
kubectl port-forward svc/snake-api 18080:80 -n snake-local
```

Generate local frontend config:

```powershell
.\localtesting\write-frontend-config.ps1
```

Serve the frontend manually:

```powershell
cd app\public
python -m http.server 4173
```

## Check health

```powershell
kubectl get pods -n snake-local
kubectl get svc -n snake-local
kubectl logs deployment/snake-api -n snake-local
kubectl get servicemonitor -n snake-local
```

## Stop everything

Stop background processes and Helm releases, and optionally delete namespaces:

```powershell
.\localtesting\stop-localtest.ps1 -DeleteNamespace
```
