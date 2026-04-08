# Observability Guide

This document summarizes the monitoring surface exposed by the application and the recommended Prometheus queries and Grafana panels for demonstration purposes.

## Local forwarded URLs

These URLs are valid while the local test stack and the associated port-forwards are running.

- frontend: `http://localhost:4173`
- backend: `http://127.0.0.1:18080`
- Prometheus: `http://127.0.0.1:19090`
- Grafana: `http://127.0.0.1:13000`

Grafana authentication:

- username: `admin`
- password: read from the generated Kubernetes secret

The provisioned dashboard is sourced from [`helm/snake-grafana-dashboards`](../helm/snake-grafana-dashboards).

## Backend metrics

The backend exports:

- HTTP traffic and latency
- health check results
- leaderboard reads
- score submission results
- score rejection reasons
- high-score upsert outcomes
- database query counts and durations
- PostgreSQL pool gauges
- default Node.js runtime and process metrics

## Recommended Prometheus queries

### Request rate

```promql
sum by (method, route) (
  rate(snake_api_http_requests_total[5m])
)
```

### Error rate

```promql
sum by (route, status_code) (
  rate(snake_api_http_requests_total{status_code=~"4..|5.."}[5m])
)
```

### P95 API latency

```promql
histogram_quantile(
  0.95,
  sum by (le, route) (
    rate(snake_api_http_request_duration_seconds_bucket[5m])
  )
)
```

### Health check results

```promql
sum by (result) (
  rate(snake_api_healthcheck_total[5m])
)
```

### Leaderboard request rate

```promql
rate(snake_api_leaderboard_requests_total[5m])
```

### Score submissions by result

```promql
sum by (result) (
  rate(snake_api_score_submissions_total[5m])
)
```

### Score rejections by reason

```promql
sum by (reason) (
  rate(snake_api_score_rejections_total[5m])
)
```

### High-score upsert outcomes

```promql
sum by (result) (
  rate(snake_api_user_upserts_total[5m])
)
```

### Database query rate by operation

```promql
sum by (operation, result) (
  rate(snake_api_db_queries_total[5m])
)
```

### P95 database query latency by operation

```promql
histogram_quantile(
  0.95,
  sum by (le, operation) (
    rate(snake_api_db_query_duration_seconds_bucket[5m])
  )
)
```

### Database pool gauges

```promql
snake_api_db_connection_pool_clients
```

```promql
snake_api_db_connection_pool_idle
```

```promql
snake_api_db_connection_pool_waiting
```

## Recommended Grafana panels

### API request rate

- query: request rate
- visualization: time series

### API error rate

- query: error rate
- visualization: time series or stat

### API P95 latency

- query: P95 API latency
- visualization: time series

### Score submissions by result

- query: score submissions by result
- visualization: stacked bar or time series

### User upserts by result

- query: high-score upsert outcomes
- visualization: bar chart or time series

### Database query rate by operation

- query: database query rate by operation
- visualization: time series

### Database P95 latency by operation

- query: P95 database query latency by operation
- visualization: time series

### Database pool state

- queries:
  - `snake_api_db_connection_pool_clients`
  - `snake_api_db_connection_pool_idle`
  - `snake_api_db_connection_pool_waiting`
- visualization: time series or stat

## Demonstration sequence

1. Confirm that the Prometheus target for the snake API is `UP`.
2. Review request rate, score submissions, and database query rate in Prometheus.
3. Open Grafana and review the provisioned dashboard.
4. Submit a valid score through the frontend.
5. Submit the same username with a lower score.
6. Submit the same username with a higher score.
7. Optionally submit an invalid payload to exercise rejection metrics.
8. Refresh the dashboard and confirm that traffic, business, and database metrics changed as expected.

## Summary

- availability is covered through `/healthz`
- Prometheus scrapes `/metrics` through a `ServiceMonitor`
- the metrics set covers HTTP behavior, business behavior, and database behavior
- Grafana provides a concise operational view suitable for demonstration and discussion
