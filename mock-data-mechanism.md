You are an expert observability and clean-code engineer.

Goal:
Replace the existing mock observability data generation mechanism with a SIMPLE and maintainable implementation.

IMPORTANT:

* REMOVE the current TSDB/mock block generation approach completely.
* REMOVE obsolete scripts/configs related to old mock data generation.
* Do NOT generate Prometheus TSDB blocks.
* Do NOT manipulate WAL files.
* Avoid overengineering.
* Keep dependencies minimal.
* No tests.
* Prefer Python standard library only.
* Keep code small and readable.

Existing stack already available:

* Prometheus
* Grafana
* Loki
* Promtail
* Kubernetes
* Docker Desktop
* Java microservices with Micrometer metrics

Microservices:

* ecommerce
* product
* images
* observability-agent

Existing observability:

* Prometheus scraping already exists
* Loki + Promtail already exist
* Correlation IDs already exist in logs

Required implementation:
Generate realistic metrics files and log files only.

Architecture:
generated metrics/logs
→ Prometheus scrape
→ Loki ingestion
→ Grafana dashboards

DO NOT use Pushgateway.

Implementation requirements:

1. Remove old mock data scripts and configs.
2. Add new Python generator:
   scripts/generate_mock_observability_data.py
3. Keep existing:
   mock-observability-data.bat
   but rewrite it completely.
4. Generate:
   generated-metrics/
   generated-logs/

Metrics format:
Use Prometheus text exposition format.

Generate metrics for:

* jvm_heap_used_mb
* jvm_threads_live
* http_requests_per_second
* http_request_duration_p95
* jvm_gc_pause_seconds
* cpu_usage_percent

Metric rules:

* Metrics must correlate realistically.
* Higher request load increases:

  * heap
  * threads
  * CPU
  * GC frequency
* Full GC sharply reduces heap.
* GC pauses increase latency.

Generate minute-level telemetry.

Scenario 1:
NORMAL DAY

Time:
06:00 AM → 10:59 PM

Behavior:

* moderate daytime traffic
* heap sawtooth pattern
* periodic full GC
* stable CPU
* moderate thread count

During full GC:

* request latency spikes
* some requests exceed 5 seconds
* downstream services also slow

Scenario 2:
NIGHT BATCH JOB

Time:
11:00 PM → 11:30 PM

Behavior:

* sudden sustained high traffic
* high thread count
* higher CPU
* frequent GC
* faster heap oscillation

At 11:30 PM:

* traffic drops quickly
* heap stabilizes
* threads reduce

Logs:
Generate realistic logs for all services.

Log format:
timestamp level requestId traceId service endpoint durationMs message

Requirements:

* correlated requestId/traceId across services
* propagated latency
* GC warning logs
* slow requests during GC
* realistic timestamps

Example:
2026-05-13T23:04:11Z INFO requestId=req-9912 traceId=t-7782 service=ecommerce endpoint=/checkout durationMs=8123 message="Request completed"

2026-05-13T23:04:11Z WARN requestId=req-9912 traceId=t-7782 service=ecommerce message="Full GC pause detected"

Prometheus integration:
Use simplest possible approach.

Preferred approach:

* expose generated metrics using lightweight local HTTP server
  OR
* simple file-based scrape mechanism

Choose the simplest clean solution compatible with current Prometheus setup.

Promtail:
Add scrape config for generated logs only if missing.

Batch file requirements:
mock-observability-data.bat should:

1. validate required pods/services
2. generate metrics/logs
3. copy logs to Promtail-readable location
4. print status clearly

Code quality:

* small functions
* no giant classes
* no frameworks
* no dead code
* minimal comments
* clear naming
* deterministic random seed

Final output:

* exact files changed
* exact cleanup changes
* full code
* exact commands to run
* minimal explanation
