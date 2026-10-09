# TaskFlow — Essential Grafana Dashboards

Start with **2 Grafana dashboards and 8 essential panels** covering application performance and EC2 infrastructure.

# Dashboard 1: TaskFlow Application Monitoring

## Row 1 — Application Health

### 1. Application Availability

**Description:** Checks whether Prometheus can scrape the NestJS application metrics endpoint. `1` means up; `0` means down.

**Panel type:** Stat

```promql
up{job="webapp-metrics"}
```

### 2. HTTP Request Rate

**Description:** Shows the average number of HTTP requests the application receives per second over the last five minutes.

**Panel type:** Time series

```promql
sum(rate(http_requests_total[5m]))
```

## Row 2 — Performance and Errors

### 3. P95 Response Latency

**Description:** Estimates the response duration below which 95% of measured requests fall. The result is in seconds.

**Panel type:** Time series

```promql
histogram_quantile(
  0.95,
  sum by (le) (
    rate(http_request_duration_seconds_bucket[5m])
  )
)
```

### 4. HTTP 5xx Errors per Second

**Description:** Tracks the rate of HTTP server errors (status codes 500–599), helping identify application failures. The application metrics interceptor must record error responses for this query to work reliably.

**Panel type:** Time series

```promql
sum(rate(http_requests_total{status_code=~"5.."}[5m]))
```

# Dashboard 2: EC2 Infrastructure Monitoring

## Row 1 — Host Resources

### 5. CPU Utilization (%)

**Description:** Shows the percentage of CPU capacity being used on the application EC2 instance, averaged across its CPU cores.

**Unit:** Percent (0–100)

**Panel type:** Gauge

```promql
100 * (
  1 - avg by (instance) (
    rate(node_cpu_seconds_total{mode="idle"}[5m])
  )
)
```

### 6. Memory Utilization (%)

**Description:** Estimates the percentage of RAM currently unavailable for immediate use, based on Linux's available-memory metric.

**Unit:** Percent (0–100)

**Panel type:** Gauge

```promql
100 * (
  1 -
  node_memory_MemAvailable_bytes
  /
  node_memory_MemTotal_bytes
)
```

### 7. Root Disk Utilization (%)

**Description:** Shows how much of the root filesystem's capacity is in use, helping identify a disk that is filling up.

**Unit:** Percent (0–100)

**Panel type:** Gauge

```promql
100 * (
  1 -
  node_filesystem_avail_bytes{
    mountpoint="/",
    fstype!~"tmpfs|overlay"
  }
  /
  node_filesystem_size_bytes{
    mountpoint="/",
    fstype!~"tmpfs|overlay"
  }
)
```

## Row 2 — Monitoring Health

### 8. Node Exporter Availability

**Description:** Confirms whether Prometheus can scrape Node Exporter and collect system metrics from the application EC2 instance. `1` means the scrape succeeded; `0` means it failed.

**Panel type:** Stat

```promql
up{job="webserver-system-metrics"}
```

# Implementation Notes

* Select **Prometheus** as the data source for every panel.
* For time-series panels, start with the dashboard time range set to **Last 15 minutes**.
* If a panel displays **No data**, verify that the corresponding target is `UP` under Prometheus → Status → Targets.
* Confirm the metric names and labels match the metrics actually exposed by TaskFlow and Node Exporter.
* Verify that the metrics interceptor records error responses before relying on the HTTP 5xx panel.
* Build and validate these eight panels before adding more dashboards or alerting rules.
