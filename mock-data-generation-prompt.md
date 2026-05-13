# Mock Observability Data Generation Prompt

Generate realistic mock observability data for the Kubernetes-native Spring Boot microservices in this project.

Microservices:
- `ecommerce`
- `product`
- `images`

Observability model already used by the project:
- Logs are JSON logs written to stdout and later aggregated in Loki.
- Logs must include:
  - `timestamp`
  - `service`
  - `level`
  - `correlationId`
  - `thread`
  - `logger`
  - `message`
- Metrics are Prometheus-compatible time series.
- Existing metric names:
  - `jvm_memory_used_bytes{job="<service>",area="heap"}`
  - `jvm_memory_max_bytes{job="<service>",area="heap"}`
  - `jvm_threads_live_threads{job="<service>"}`
  - `jvm_gc_pause_seconds_count{job="<service>"}`
  - `jvm_gc_pause_seconds_sum{job="<service>"}`
  - `jvm_gc_pause_seconds_max{job="<service>"}`
  - `http_server_requests_seconds_count{job="<service>"}`

Your task:
- Generate a realistic synthetic dataset for metrics and logs.
- The output must be usable to backfill Prometheus and Loki.
- The data must look operationally believable.
- Heap, thread count, request rate, GC behavior, and request latency must align with each other.
- Correlation IDs must be preserved across inter-service requests.

Scenario placeholder:

`{{SCENARIO_DESCRIPTION}}`

Hard requirements:

1. Time range
- Use one explicit date in UTC.
- Generate complete timestamps.
- Use realistic spacing between events and samples.
- Unless the scenario explicitly says otherwise, produce 1-minute metric samples.

2. Service call behavior
- `ecommerce` is the entry service.
- `ecommerce` may call `product` and `images`.
- For the same business request, the same `correlationId` must appear in all participating services.
- If a request is slow in `ecommerce`, dependent service timings should still make sense.

3. Metrics realism
- Heap usage must not move randomly.
- Heap usage must respond to load.
- Higher request rate should usually increase active threads and memory pressure.
- GC counters must be cumulative.
- GC sum and max values must be mathematically consistent with the event pattern.
- Request counter must be cumulative and monotonic.
- If there is a burst or batch window, request counter slope must increase during that window.
- If full GC happens, heap should drop in a believable sawtooth pattern.
- If there are more frequent GCs, thread and heap behavior should justify them.

4. Log realism
- Logs must be valid JSON lines.
- Use service-appropriate thread names such as `http-nio-8090-exec-<n>`, `VM Thread`, `batch-runner-<n>`, or similar realistic names.
- Use logger names that look like Java package/class names.
- Messages must reflect actual events such as:
  - request received
  - downstream service call completed
  - request completed
  - GC warning or pause notice
  - batch load notice
- If the scenario includes slow responses, log completion messages with higher `durationMs`.
- If the scenario includes GC impact, some `ecommerce` completion logs must clearly align in time with GC-related warnings.

5. Cross-service correlation
- For every selected business request that touches multiple services:
  - create one `correlationId`
  - log entries in `ecommerce`
  - matching entries in `product`
  - matching entries in `images` when applicable
- Preserve timing order:
  - request enters `ecommerce`
  - downstream calls occur
  - `ecommerce` completes later

6. Output format
- Produce output in 3 sections only.

Section 1: `ASSUMPTIONS`
- short bullet list
- mention chosen UTC date
- mention sample interval
- mention any scenario-specific numeric assumptions

Section 2: `PROMETHEUS_METRICS`
- output Prometheus/OpenMetrics-style sample lines only
- include all required metric names
- use valid labels and timestamps
- keep counters cumulative
- use Unix timestamps in milliseconds
- use `# TYPE ...` headers before metric samples
- end the section with `# EOF`
- use LF line endings only
- do not add explanatory prose inside this section

Section 3: `LOKI_LOGS`
- output JSON log lines only
- one log event per line
- keep timestamps as full ISO-8601 UTC strings
- do not add commentary inside this section

Additional generation rules:
- Keep service names exactly:
  - `ecommerce`
  - `product`
  - `images`
- Keep metric job labels aligned to those names.
- Use UUIDs for `correlationId`.
- Prefer fewer high-quality correlated logs over noisy random logs.
- Make the dataset realistic enough that Grafana charts for heap, threads, GC activity, and request rate look believable.
- Do not invent new APIs, services, or metric names.
- Do not include markdown code fences.
- Do not include CRLF-specific formatting.
- Do not output code, scripts, tutorials, or explanations outside the 3 required sections.
