Repository:
https://github.com/amollimaye/agentic-microservices

Must study first:
- Existing microservice structure
- K8s manifests
- Docker setup
- Shared conventions
- Existing agent services
- Build conventions
- Package naming
- Existing MCP patterns
- coding-agent-reference.md

Reference:
https://github.com/amollimaye/agentic-microservices/blob/master/coding-agent-reference.md

Follow repository conventions exactly.

==================================================
GOAL
==================================================

Create a new Spring Boot microservice:

observability-agent

This service is:
1. Spring Boot REST service
2. MCP server

It must integrate into the same microservices + Kubernetes ecosystem already used in repository.

Avoid overengineering.

Reuse existing repo patterns.

==================================================
TECH STACK
==================================================

Use:
- Java 21
- Spring Boot
- Spring Web
- Spring Actuator
- Spring AI MCP Server
- WebClient
- Jackson

Use Micrometer only if genuinely required.

Avoid unnecessary dependencies.

==================================================
ARCHITECTURE
==================================================

Use same:
- Maven/Gradle style
- Docker style
- Kubernetes style
- application.yml conventions
- actuator conventions
- logging conventions
- health check conventions

Do NOT redesign architecture.

Assume:
- Loki already stores logs
- Prometheus already stores JVM metrics

This service is only:
- aggregation layer
- query layer
- MCP exposure layer

Do NOT add:
- DB
- Kafka
- Elasticsearch
- custom storage
- CQRS
- event sourcing
- plugin systems
- caching layers unless required
- generic query engines
- frontend/UI
- auth unless repo already uses it

Prefer simple imperative code.

==================================================
PACKAGE STRUCTURE
==================================================

Minimum:

observability-agent
 ├── controller
 ├── service
 ├── client
 ├── dto
 ├── config
 ├── mcp
 ├── exception

==================================================
REST APIS
==================================================

1. Logs by Request ID

GET /api/observability/logs/request/{requestId}

Behavior:
- Query Loki
- Search logs containing requestId
- Aggregate across services
- Sort chronologically

Response:

{
  "requestId": "abc-123",
  "logs": [
    {
      "timestamp": "2026-05-12T10:15:11Z",
      "service": "order-service",
      "level": "INFO",
      "message": "Creating order"
    }
  ]
}

--------------------------------------------------

2. Logs by Service + Time Range

GET /api/observability/logs/service/{serviceName}

Query params:
- startTime
- endTime

Behavior:
- Return logs for service in time range

--------------------------------------------------

3. Error Logs by Service + Time Range

GET /api/observability/logs/errors/{serviceName}

Query params:
- startTime
- endTime

Behavior:
- Return ERROR/ERR logs for service in time range

Must match:
- ERROR
- ERR
- error
- err

Prefer structured matching:
- level=ERROR
- severity=ERROR

Fallback:
- text matching

--------------------------------------------------

4. Heap Metrics

GET /api/observability/metrics/heap/{serviceName}

Query params:
- startTime
- endTime
- stepSeconds (optional)

Behavior:
- Return heap datapoints

If stepSeconds absent:
- return all available datapoints

If stepSeconds present:
- use Prometheus range query step

Metric:
- jvm_memory_used_bytes

Response:

{
  "service": "payment-service",
  "metric": "heap-used",
  "points": [
    {
      "timestamp": "2026-05-12T10:15:00Z",
      "value": 104857600
    }
  ]
}

--------------------------------------------------

5. Thread Metrics

GET /api/observability/metrics/threads/{serviceName}

Query params:
- startTime
- endTime
- stepSeconds (optional)

Behavior:
- Return thread datapoints

If stepSeconds absent:
- return all available datapoints

If stepSeconds present:
- use Prometheus range query step

Metric:
- jvm_threads_live_threads

--------------------------------------------------

6. Available Services

GET /api/observability/services

Response:

{
  "services": [
    "order-service",
    "payment-service"
  ]
}

==================================================
MCP REQUIREMENTS
==================================================

Expose MCP tools for all APIs.

Tool names:
- get_logs_by_request_id
- get_logs_by_service
- get_error_logs_by_service
- get_heap_metrics
- get_thread_metrics
- list_observable_services

Each tool must have:
- description
- parameter schema
- validation
- examples
- structured JSON response

==================================================
CLIENTS
==================================================

Create:
- LokiClient
- PrometheusClient

Responsibilities:
- query downstream systems
- parse responses
- map DTOs
- timeout handling
- error handling

Use:
- configurable base URLs
- WebClient

No hardcoded URLs.

==================================================
DTOs
==================================================

Create explicit DTOs.

Do not return raw maps.

Examples:
- LogEntryDto
- LogsResponseDto
- MetricPointDto
- MetricsResponseDto
- ServicesResponseDto

Use records where appropriate.

==================================================
VALIDATION
==================================================

Validate:
- ISO timestamps
- startTime < endTime
- serviceName non-empty
- optional stepSeconds > 0
- sane upper bound for stepSeconds

==================================================
ERROR HANDLING
==================================================

Centralized exception handling.

Handle:
- invalid timestamps
- invalid ranges
- unknown service
- missing serviceName
- invalid stepSeconds
- Loki unavailable
- Prometheus unavailable
- malformed downstream responses
- timeout failures

Use structured error DTOs.

==================================================
CONFIG
==================================================

Use @ConfigurationProperties.

Config:

observability:
  loki:
    base-url:
    timeout-seconds:
  prometheus:
    base-url:
    timeout-seconds:

==================================================
ACTUATOR
==================================================

Enable:
- health
- info
- prometheus

==================================================
LOGGING
==================================================

Use structured logs.

Include when available:
- requestId
- serviceName
- error details

==================================================
KUBERNETES
==================================================

Create manifests matching repository conventions:
- deployment.yaml
- service.yaml
- configmap.yaml if repo uses it

Do not introduce Helm unless repo already uses Helm.

==================================================
DOCKER
==================================================

Create Dockerfile matching repo conventions.

==================================================
TESTS
==================================================

Unit tests:
- Loki parsing
- Prometheus parsing
- validation
- service layer
- controller layer

Integration tests:
- mocked Loki
- mocked Prometheus
- API contract validation
- error handling

==================================================
MCP VALIDATION
==================================================

Validate:
- MCP startup
- tool registration
- tool execution
- schema validation

==================================================
FINAL VALIDATION
==================================================

Must validate:
1. Build passes
2. Docker build passes
3. K8s YAML valid
4. REST APIs work
5. MCP tools work
6. Error handling works
7. Optional stepSeconds behavior works
8. No dead code
9. No TODOs
10. No hardcoded URLs

Run:
./mvnw clean test
(or repo equivalent)

==================================================
FINAL OUTPUT
==================================================

Provide:
1. Architecture summary
2. Files created
3. REST API summary
4. MCP tools summary
5. curl examples
6. MCP examples
7. K8s deployment steps
8. Assumptions
9. Limitations

Generated code must compile successfully.
