# Observability Guide

This document is a compact walkthrough for demonstrating Prometheus and Grafana during the interview.

## Local forwarded URLs

These URLs work while the local test stack and its port-forwards are running.

- frontend: `http://localhost:4173`
- backend: `http://127.0.0.1:18080`
- Prometheus: `http://127.0.0.1:19090`
- Grafana: `http://127.0.0.1:13000`

Grafana default login:

- username: `admin`
- password: `admin123`

The default dashboard is provisioned automatically from [`helm/snake-grafana-dashboards`](C:\Users\ivanm\projekti\incode\incode-assignment\helm\snake-grafana-dashboards) when monitoring is installed.

## Backend metrics exposed on `/metrics`

The backend exports:

- HTTP traffic and latency
- health check results
- leaderboard reads
- score submission results
- score rejection reasons
- high score upsert outcomes
- DB query counts and DB query durations
- PostgreSQL pool gauges
- default Node.js runtime/process metrics

## Best Prometheus queries

These are the most useful live demo queries.

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

### High score upsert outcomes

```promql
sum by (result) (
  rate(snake_api_user_upserts_total[5m])
)
```

### DB query rate by operation

```promql
sum by (operation, result) (
  rate(snake_api_db_queries_total[5m])
)
```

### P95 DB query latency by operation

```promql
histogram_quantile(
  0.95,
  sum by (le, operation) (
    rate(snake_api_db_query_duration_seconds_bucket[5m])
  )
)
```

### DB pool gauges

```promql
snake_api_db_connection_pool_clients
```

```promql
snake_api_db_connection_pool_idle
```

```promql
snake_api_db_connection_pool_waiting
```

## Suggested Grafana panels

Keep the dashboard small and easy to explain.

### Panel 1: API request rate

- query: request rate query above
- visualization: time series
- why: shows user traffic and route activity

### Panel 2: API error rate

- query: error rate query above
- visualization: time series or stat
- why: shows failed requests immediately

### Panel 3: API p95 latency

- query: p95 API latency query above
- visualization: time series
- why: shows responsiveness under load

### Panel 4: Score submissions by result

- query: score submissions by result
- visualization: stacked bar or time series
- why: shows successful vs invalid submissions

### Panel 5: User upserts by result

- query: high score upsert outcomes
- visualization: bar chart
- why: shows created vs updated vs unchanged players

### Panel 6: DB query rate by operation

- query: DB query rate by operation
- visualization: time series
- why: shows what the backend is asking from PostgreSQL

### Panel 7: DB p95 latency by operation

- query: p95 DB query latency by operation
- visualization: time series
- why: shows whether the database is the bottleneck

### Panel 8: DB pool pressure

- queries:
  - `snake_api_db_connection_pool_clients`
  - `snake_api_db_connection_pool_idle`
  - `snake_api_db_connection_pool_waiting`
- visualization: time series or stat
- why: shows connection pool health

## Good live demo sequence

1. Open the frontend and Prometheus.
2. Show the Prometheus target for the snake API is `UP`.
3. Run a couple of Prometheus queries:
   - request rate
   - score submissions by result
   - DB query rate by operation
4. Open Grafana and show the dashboard panels.
5. Play one game and submit a score.
6. Submit the same username again with a lower score.
7. Submit the same username again with a higher score.
8. Optionally trigger one invalid submission.
9. Refresh the dashboard and explain:
   - traffic increased
   - business metrics changed
   - DB metrics changed
   - health stayed green

## Interview framing

Useful summary:

- availability is covered by `/healthz`
- Prometheus scrapes `/metrics` through a `ServiceMonitor`
- app metrics cover HTTP, business flow, and DB dependency behavior
- Grafana turns those into a fast operational view
- for a larger system, alerts and long-term dashboards would be the next step
