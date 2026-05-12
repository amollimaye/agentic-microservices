You are working inside the existing GitHub repository:

https://github.com/amollimaye/agentic-microservices

You MUST first study:

- Existing microservices structure
- Kubernetes manifests
- Docker setup
- Shared conventions
- Existing agent services
- Build conventions
- Package naming
- YAML organization
- Config management
- Logging style
- Any shared libraries/utilities
- Existing MCP patterns if present

Also study:

https://github.com/amollimaye/agentic-microservices/blob/master/coding-agent-reference.md

You MUST follow the conventions defined there exactly.

--------------------------------------------------
GOAL
--------------------------------------------------

Create a new Spring Boot microservice named:

observability-agent

This service is BOTH:

1. A normal Spring Boot REST microservice
2. An MCP server

It becomes part of the same microservices ecosystem already present in the repository.

DO NOT redesign architecture.

DO NOT introduce new frameworks unless absolutely required.

DO NOT overengineer.

Reuse existing patterns from repository.

--------------------------------------------------
HIGH LEVEL FUNCTIONAL REQUIREMENTS
--------------------------------------------------

The service provides observability APIs and MCP tools for:

1. Logs by request ID
2. Logs by service + time range
3. Error logs by service + time range
4. Heap size metrics by service + time range
5. Thread count metrics by service + time range
6. List of services for which observability data is available

--------------------------------------------------
IMPORTANT ARCHITECTURE REQUIREMENTS
--------------------------------------------------

1. Same Infrastructure Style

The new service MUST use:

- Same Gradle/Maven style as repo
- Same Docker conventions
- Same Kubernetes conventions
- Same namespace conventions
- Same ingress/service/deployment style
- Same application.yml style
- Same logging approach
- Same actuator usage style
- Same health check style

Do NOT invent new deployment architecture.

--------------------------------------------------
DATA SOURCE ASSUMPTIONS
--------------------------------------------------

Assume observability data already exists in:

- Loki (for logs)
- Prometheus (for JVM metrics)

The new service acts as:

- Aggregation layer
- Query layer
- MCP exposure layer

DO NOT implement custom log storage.

DO NOT implement custom metrics storage.

--------------------------------------------------
TECHNOLOGIES
--------------------------------------------------

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

--------------------------------------------------
CLEAN CODE REQUIREMENTS
--------------------------------------------------

Follow clean code principles throughout implementation.

Requirements:

- Small focused classes
- Small focused methods
- Clear naming
- No god classes
- No unnecessary abstraction
- No deep inheritance
- Constructor injection only
- Avoid utility classes unless genuinely reusable
- Keep controller/service/client responsibilities clear
- Keep DTOs explicit and minimal
- Prefer readability over cleverness

--------------------------------------------------
IMPORTANT IMPLEMENTATION RULES
--------------------------------------------------

Avoid overengineering.

This service is intentionally a thin observability aggregation and MCP exposure layer.

DO NOT introduce:

- Kafka
- Databases
- Elasticsearch
- Custom storage
- CQRS
- Event sourcing
- Plugin systems
- Generic query engines
- Complex domain modeling
- Internal caching layers unless absolutely needed
- Strategy/factory patterns unless repository already uses them
- Reactive chains beyond simple WebClient usage
- Multiple abstraction layers for simple logic
- Authentication unless existing repo already has it
- UI/frontend

Keep implementation straightforward and maintainable.

Prefer simple imperative code over highly abstract functional/reactive pipelines.

The code should be understandable by a normal Spring Boot developer without requiring advanced framework knowledge.

--------------------------------------------------
PACKAGE STRUCTURE
--------------------------------------------------

Use clean structure aligned with repository conventions.

Expected minimum:

observability-agent
 ├── controller
 ├── service
 ├── client
 ├── dto
 ├── config
 ├── mcp
 ├── exception
 └── util

--------------------------------------------------
FUNCTIONAL APIS
--------------------------------------------------

--------------------------------------------------
API 1 — Logs By Request ID
--------------------------------------------------

REST:

GET /api/observability/logs/request/{requestId}

Behavior:

Return all logs across all microservices for a request ID.

Query Strategy:

Use Loki query.

Search logs containing request ID.

Aggregate and sort chronologically.

Response Example:

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
API 2 — Logs By Service + Time Range
--------------------------------------------------

REST:

GET /api/observability/logs/service/{serviceName}

Query Params:

- startTime
- endTime

Behavior:

Return logs for a service within a given time range.

--------------------------------------------------
API 3 — Error Logs By Service + Time Range
--------------------------------------------------

REST:

GET /api/observability/logs/errors/{serviceName}

Query Params:

- startTime
- endTime

Behavior:

Return all error logs for the given service within the specified time range.

Log Level Matching Rules:

The implementation MUST include logs matching ANY of the following:

- ERROR
- ERR
- error
- err

If Loki log entries contain structured JSON fields, prefer matching on:

- level=ERROR
- severity=ERROR

If structured fields are unavailable, fallback to text matching.

Response Example:

{
  "service": "payment-service",
  "logs": [
    {
      "timestamp": "2026-05-12T10:15:11Z",
      "service": "payment-service",
      "level": "ERROR",
      "message": "Payment authorization failed"
    }
  ]
}

--------------------------------------------------
API 4 — Heap Metrics
--------------------------------------------------

REST:

GET /api/observability/metrics/heap/{serviceName}

Query Params:

- startTime
- endTime
- stepSeconds (OPTIONAL)

Behavior:

Return heap usage datapoints for the given service within the specified time range.

If stepSeconds is NOT provided:

- Return all available recorded heap datapoints between startTime and endTime.

If stepSeconds IS provided:

- Query Prometheus using the provided resolution step.

Prometheus Metric:

- jvm_memory_used_bytes

Only heap-related data.

Response Example:

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

Validation Rules:

If provided:

- stepSeconds must be greater than 0
- stepSeconds must have sane upper bounds

--------------------------------------------------
API 5 — Thread Count Metrics
--------------------------------------------------

REST:

GET /api/observability/metrics/threads/{serviceName}

Query Params:

- startTime
- endTime
- stepSeconds (OPTIONAL)

Behavior:

Return thread count datapoints for the given service within the specified time range.

If stepSeconds is NOT provided:

- Return all available recorded thread count datapoints between startTime and endTime.

If stepSeconds IS provided:

- Query Prometheus using the provided resolution step.

Prometheus Metric:

- jvm_threads_live_threads

Validation Rules:

If provided:

- stepSeconds must be greater than 0
- stepSeconds must have sane upper bounds

--------------------------------------------------
API 6 — List Available Services
--------------------------------------------------

REST:

GET /api/observability/services

Behavior:

Return services for which logs and metrics exist.

Response Example:

{
  "services": [
    "order-service",
    "payment-service",
    "inventory-service"
  ]
}

--------------------------------------------------
MCP REQUIREMENTS
--------------------------------------------------

The service MUST expose MCP tools.

Each REST API should also be exposed as MCP tools.

Required tool names:

- get_logs_by_request_id
- get_logs_by_service
- get_error_logs_by_service
- get_heap_metrics
- get_thread_metrics
- list_observable_services

Each MCP tool must include:

- clear description
- strict parameter schema
- validation
- useful examples
- structured JSON responses

--------------------------------------------------
MCP TOOL DETAILS
--------------------------------------------------

get_error_logs_by_service

Returns all ERROR/ERR logs for a given microservice within a specified time range.

Supports:

- structured log level matching
- text-based fallback matching

Required parameters:

- serviceName
- startTime
- endTime

--------------------------------------------------
LOKI INTEGRATION REQUIREMENTS
--------------------------------------------------

Implement:

LokiClient

Responsibilities:

- Query Loki
- Parse Loki response
- Map logs to DTOs
- Handle errors
- Timeout handling

Use configurable Loki base URL.

DO NOT hardcode URLs.

Use WebClient.

--------------------------------------------------
PROMETHEUS INTEGRATION REQUIREMENTS
--------------------------------------------------

Implement:

PrometheusClient

Responsibilities:

- Query Prometheus range APIs
- Parse metrics
- Map datapoints
- Handle failures
- Timeout handling

Use configurable Prometheus URL.

Use WebClient.

--------------------------------------------------
DTO REQUIREMENTS
--------------------------------------------------

Create explicit DTOs.

DO NOT return raw maps.

Examples:

- LogEntryDto
- LogsResponseDto
- MetricPointDto
- MetricsResponseDto
- ServicesResponseDto

Use Java records where appropriate.

--------------------------------------------------
VALIDATION REQUIREMENTS
--------------------------------------------------

Validate:

- startTime < endTime
- timestamps are ISO-8601
- service names are non-empty
- optional stepSeconds > 0
- optional stepSeconds has sane upper bounds

--------------------------------------------------
ERROR HANDLING REQUIREMENTS
--------------------------------------------------

Implement centralized exception handling.

Return proper HTTP status codes.

Include handling for:

- invalid timestamps
- invalid range
- unknown service
- downstream failure
- timeout
- missing serviceName
- invalid optional stepSeconds
- unsupported metric query parameters
- malformed Loki responses
- malformed Prometheus responses

Use structured error response DTOs.

--------------------------------------------------
CONFIGURATION REQUIREMENTS
--------------------------------------------------

Add configuration for:

observability:
  loki:
    base-url:
    timeout-seconds:
  prometheus:
    base-url:
    timeout-seconds:

Use @ConfigurationProperties.

--------------------------------------------------
ACTUATOR REQUIREMENTS
--------------------------------------------------

Enable:

- health
- info
- prometheus

--------------------------------------------------
LOGGING REQUIREMENTS
--------------------------------------------------

Use structured logs.

Include:

- requestId when available
- service name
- error details

--------------------------------------------------
KUBERNETES REQUIREMENTS
--------------------------------------------------

Create Kubernetes manifests consistent with repository style.

Must include:

- deployment.yaml
- service.yaml
- configmap.yaml if repo convention uses it

Reuse existing patterns.

DO NOT introduce Helm unless repository already uses Helm.

--------------------------------------------------
DOCKER REQUIREMENTS
--------------------------------------------------

Create Dockerfile consistent with repository conventions.

--------------------------------------------------
TESTING REQUIREMENTS
--------------------------------------------------

Create unit tests covering:

- Loki response parsing
- Prometheus response parsing
- validation
- service layer
- controller layer

Create integration tests using mocked downstream APIs.

Validate:

- API contracts
- JSON structure
- error handling

--------------------------------------------------
MCP VALIDATION REQUIREMENTS
--------------------------------------------------

Validate:

- MCP server startup
- MCP tool registration
- MCP tool execution
- MCP parameter validation
- MCP response structure

--------------------------------------------------
REQUIRED DOCUMENTATION
--------------------------------------------------

Create:

- README.md
- API examples
- MCP tool examples
- Local run instructions
- Kubernetes deployment instructions

--------------------------------------------------
REQUIRED VALIDATION STEPS
--------------------------------------------------

You MUST validate all of the following before completion.

--------------------------------------------------
VALIDATION 1 — BUILD
--------------------------------------------------

Run:

./mvnw clean test

OR repository equivalent.

Build must succeed.

--------------------------------------------------
VALIDATION 2 — DOCKER
--------------------------------------------------

Build Docker image successfully.

--------------------------------------------------
VALIDATION 3 — KUBERNETES YAML
--------------------------------------------------

Validate manifests are syntactically correct.

--------------------------------------------------
VALIDATION 4 — REST APIS
--------------------------------------------------

Test all endpoints.

Verify JSON responses exactly match DTOs.

--------------------------------------------------
VALIDATION 5 — LOKI INTEGRATION
--------------------------------------------------

Mock Loki response.

Verify:

- parsing works
- chronological sorting works
- error filtering works

--------------------------------------------------
VALIDATION 6 — PROMETHEUS INTEGRATION
--------------------------------------------------

Mock Prometheus range query responses.

Verify:

- datapoint mapping
- optional stepSeconds behavior
- metrics parsing

--------------------------------------------------
VALIDATION 7 — OPTIONAL stepSeconds
--------------------------------------------------

Validate both cases.

Case 1:

Without stepSeconds:

- all available datapoints are returned

Case 2:

With stepSeconds:

- Prometheus query uses requested resolution

--------------------------------------------------
VALIDATION 8 — MCP TOOLS
--------------------------------------------------

Verify:

- all tools appear
- tool execution works
- schema correctness
- validation behavior

--------------------------------------------------
VALIDATION 9 — ERROR HANDLING
--------------------------------------------------

Verify:

- invalid timestamps
- missing params
- Loki unavailable
- Prometheus unavailable
- malformed responses
- invalid stepSeconds

--------------------------------------------------
VALIDATION 10 — CODE QUALITY
--------------------------------------------------

Verify:

- No unused classes
- No dead code
- No TODOs
- No hardcoded URLs
- No duplicated logic
- No commented code

--------------------------------------------------
FINAL OUTPUT REQUIREMENTS
--------------------------------------------------

At the end provide:

1. High level architecture summary
2. List of created files
3. REST API summary
4. MCP tools summary
5. Example curl commands
6. Example MCP requests
7. Kubernetes deployment steps
8. Assumptions made
9. Any limitations

Do NOT skip validation steps.

Do NOT leave partial implementation.

The generated code must compile successfully.
