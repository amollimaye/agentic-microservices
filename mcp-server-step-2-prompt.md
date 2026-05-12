Repository:
https://github.com/amollimaye/agentic-microservices

Existing service already created:
microservices/observability-agent

Goal now:
Convert observability-agent into a REAL MCP server using Spring AI MCP Server.

IMPORTANT:
- Follow existing repository conventions exactly
- Avoid overengineering
- Keep implementation minimal and clean
- Reuse existing REST service layer
- Do NOT redesign architecture
- Do NOT create generic frameworks
- Do NOT generate tests
- Minimize token usage during implementation
- Modify only required files

==================================================
PRIMARY GOAL
==================================================

Implement proper MCP server support for observability-agent.

The service already contains:
- REST APIs
- DTOs
- ObservabilityService
- LokiClient
- PrometheusClient
- K8s manifests
- Dockerfile

Reuse these existing classes.

DO NOT duplicate business logic.

MCP tools must internally call existing service methods.

==================================================
REQUIRED MCP FEATURES
==================================================

Implement:
1. Spring AI MCP server dependency
2. MCP transport endpoint
3. MCP tool registration
4. Tool descriptions
5. Parameter validation
6. Structured JSON responses

==================================================
DEPENDENCIES
==================================================

Add minimal required Spring AI MCP dependencies.

Prefer:
- spring-ai-starter-mcp-server-webmvc

Do NOT add unnecessary dependencies.

Use versions compatible with existing repository Spring Boot version.

==================================================
IMPLEMENTATION STYLE
==================================================

Follow clean code guidelines:

- Small focused classes
- Constructor injection only
- No unnecessary interfaces
- No abstract factories
- No plugin systems
- No reflection-based registries
- No dynamic tool loaders
- No excessive configuration
- No utility god classes

Prefer:
- direct wiring
- explicit code
- readable code

==================================================
EXPECTED PACKAGE STRUCTURE
==================================================

Add only required MCP classes:

observability-agent
 ├── mcp
 │    ├── ObservabilityTools.java
 │    └── McpConfiguration.java

Avoid additional layers unless absolutely necessary.

==================================================
MCP TOOL REQUIREMENTS
==================================================

Expose these MCP tools:

- get_logs_by_request_id
- get_logs_by_service
- get_error_logs_by_service
- get_heap_metrics
- get_thread_metrics
- list_observable_services

Each tool must:
- directly call ObservabilityService
- return existing DTOs
- use strong typing
- avoid Map<String,Object>

==================================================
TOOL IMPLEMENTATION
==================================================

Implement tools using Spring AI tool annotations or official Spring AI MCP mechanism.

Preferred style:

@Service
public class ObservabilityTools {

    private final ObservabilityService observabilityService;

    public ObservabilityTools(ObservabilityService observabilityService) {
        this.observabilityService = observabilityService;
    }

    @Tool(description = "Get logs across services for a request ID")
    public LogsResponseDto getLogsByRequestId(String requestId) {
        return observabilityService.getLogsByRequestId(requestId);
    }
}

Follow same style for all tools.

==================================================
TOOL DETAILS
==================================================

1. get_logs_by_request_id

Inputs:
- requestId

Returns:
- LogsResponseDto

--------------------------------------------------

2. get_logs_by_service

Inputs:
- serviceName
- startTime
- endTime

Returns:
- LogsResponseDto

--------------------------------------------------

3. get_error_logs_by_service

Inputs:
- serviceName
- startTime
- endTime

Returns:
- LogsResponseDto

Must match:
- ERROR
- ERR
- error
- err

--------------------------------------------------

4. get_heap_metrics

Inputs:
- serviceName
- startTime
- endTime
- stepSeconds (optional)

Returns:
- MetricsResponseDto

Metric:
- jvm_memory_used_bytes

--------------------------------------------------

5. get_thread_metrics

Inputs:
- serviceName
- startTime
- endTime
- stepSeconds (optional)

Returns:
- MetricsResponseDto

Metric:
- jvm_threads_live_threads

--------------------------------------------------

6. list_observable_services

Inputs:
- none

Returns:
- ServicesResponseDto

==================================================
MCP CONFIGURATION
==================================================

Create minimal MCP configuration.

Requirements:
- enable MCP server
- expose registered tools
- use Spring auto configuration where possible
- avoid manual registries if unnecessary

Prefer convention-over-configuration.

==================================================
LOKI CLIENT WORK
==================================================

Current LokiClient is scaffold only.

Implement real Loki parsing.

Requirements:
- query Loki
- parse JSON response
- map to LogEntryDto
- sort chronologically
- support error filtering
- handle malformed responses
- handle timeout failures

Use:
- WebClient
- existing DTOs

Do NOT add retry frameworks.

==================================================
PROMETHEUS CLIENT WORK
==================================================

Current PrometheusClient is scaffold only.

Implement:
- query_range calls
- datapoint parsing
- MetricsResponseDto mapping

Support:
- optional stepSeconds
- full datapoint retrieval when stepSeconds absent

Use:
- WebClient
- existing DTOs

==================================================
VALIDATION RULES
==================================================

Validate:
- ISO-8601 timestamps
- startTime < endTime
- serviceName non-empty
- optional stepSeconds > 0

Reuse existing validation where possible.

==================================================
ERROR HANDLING
==================================================

Reuse existing GlobalExceptionHandler.

Handle:
- Loki unavailable
- Prometheus unavailable
- malformed responses
- invalid parameters
- timeout failures

Use existing error DTO pattern.

==================================================
CONFIGURATION
==================================================

Reuse existing configuration structure.

Expected config:

observability:
  loki:
    base-url:
    timeout-seconds:
  prometheus:
    base-url:
    timeout-seconds:

Do NOT hardcode URLs.

==================================================
MCP VALIDATION
==================================================

Validate manually:

1. Application starts
2. MCP endpoint exposed
3. MCP tools visible
4. MCP tool invocation works
5. Structured responses returned
6. Existing REST APIs still work

==================================================
BUILD VALIDATION
==================================================

Run only:

./mvnw clean package

Do NOT generate tests.

==================================================
OUTPUT REQUIREMENTS
==================================================

At completion provide ONLY:

1. Files modified
2. Files created
3. MCP endpoint details
4. Available MCP tools
5. Example MCP invocation payloads
6. Assumptions made

Keep final response concise.

Generated code must compile successfully.
