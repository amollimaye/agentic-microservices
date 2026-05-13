package com.amol.microservices.observability.mcp;

import com.amol.microservices.observability.dto.LogsResponseDto;
import com.amol.microservices.observability.dto.MetricsResponseDto;
import com.amol.microservices.observability.dto.ServicesResponseDto;
import com.amol.microservices.observability.service.ObservabilityService;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.ai.tool.annotation.ToolParam;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.time.format.DateTimeParseException;

@Service
public class ObservabilityTools {

    private final ObservabilityService observabilityService;

    public ObservabilityTools(ObservabilityService observabilityService) {
        this.observabilityService = observabilityService;
    }

    @Tool(name = "get_logs_by_request_id", description = "Get logs across services for a request ID")
    public LogsResponseDto getLogsByRequestId(RequestIdInput input) {
        Instant start = parseOrNull(input.startTime());
        Instant end = parseOrNull(input.endTime());
        validateRange(start, end);
        if (isBlank(input.requestId())) {
            throw new IllegalArgumentException("requestId must not be blank");
        }
        return observabilityService.getLogsByRequestId(input.requestId(), start, end);
    }

    @Tool(name = "get_logs_by_service", description = "Get logs for a service within a time range")
    public LogsResponseDto getLogsByService(ServiceLogsInput input) {
        Instant start = parseOrNull(input.startTime());
        Instant end = parseOrNull(input.endTime());
        validateServiceAndRange(input.serviceName(), start, end);
        return observabilityService.getLogsByService(input.serviceName(), start, end);
    }

    @Tool(name = "get_error_logs_by_service", description = "Get error logs for a service within a time range")
    public LogsResponseDto getErrorLogsByService(ServiceLogsInput input) {
        Instant start = parseOrNull(input.startTime());
        Instant end = parseOrNull(input.endTime());
        validateServiceAndRange(input.serviceName(), start, end);
        return observabilityService.getErrorLogsByService(input.serviceName(), start, end);
    }

    @Tool(name = "get_heap_metrics", description = "Get heap metrics for a service within a time range")
    public MetricsResponseDto getHeapMetrics(MetricsInput input) {
        Instant start = parseOrNull(input.startTime());
        Instant end = parseOrNull(input.endTime());
        validateMetricsInput(input.serviceName(), start, end, input.stepSeconds());
        return observabilityService.getHeapMetrics(input.serviceName(), start, end, input.stepSeconds());
    }

    @Tool(name = "get_thread_metrics", description = "Get thread metrics for a service within a time range")
    public MetricsResponseDto getThreadMetrics(MetricsInput input) {
        Instant start = parseOrNull(input.startTime());
        Instant end = parseOrNull(input.endTime());
        validateMetricsInput(input.serviceName(), start, end, input.stepSeconds());
        return observabilityService.getThreadMetrics(input.serviceName(), start, end, input.stepSeconds());
    }

    @Tool(name = "get_request_rate", description = "Get request rate for a service within a time range")
    public MetricsResponseDto getRequestRate(MetricsInput input) {
        Instant start = parseOrNull(input.startTime());
        Instant end = parseOrNull(input.endTime());
        validateMetricsInput(input.serviceName(), start, end, input.stepSeconds());
        return observabilityService.getRequestRateMetrics(input.serviceName(), start, end, input.stepSeconds());
    }

    @Tool(name = "list_observable_services", description = "List observable services")
    public ServicesResponseDto listObservableServices() {
        return observabilityService.listObservableServices();
    }

    private void validateMetricsInput(String serviceName, Instant start, Instant end, Integer stepSeconds) {
        validateServiceAndRange(serviceName, start, end);
        if (stepSeconds != null && stepSeconds <= 0) {
            throw new IllegalArgumentException("stepSeconds must be > 0");
        }
    }

    private void validateServiceAndRange(String serviceName, Instant start, Instant end) {
        if (isBlank(serviceName)) {
            throw new IllegalArgumentException("serviceName must not be blank");
        }
        validateRange(start, end);
    }

    private void validateRange(Instant start, Instant end) {
        if (start != null && end != null && !start.isBefore(end)) {
            throw new IllegalArgumentException("startTime must be before endTime");
        }
    }

    private Instant parseOrNull(String value) {
        if (isBlank(value)) {
            return null;
        }
        try {
            return Instant.parse(value);
        } catch (DateTimeParseException ex) {
            throw new IllegalArgumentException("Invalid ISO timestamp: " + value);
        }
    }

    private boolean isBlank(String value) {
        return value == null || value.isBlank();
    }

    public record RequestIdInput(
            @ToolParam(description = "Request correlation ID", required = true) String requestId,
            @ToolParam(description = "Optional ISO-8601 start time") String startTime,
            @ToolParam(description = "Optional ISO-8601 end time") String endTime) {
    }

    public record ServiceLogsInput(
            @ToolParam(description = "Service name", required = true) String serviceName,
            @ToolParam(description = "Optional ISO-8601 start time") String startTime,
            @ToolParam(description = "Optional ISO-8601 end time") String endTime) {
    }

    public record MetricsInput(
            @ToolParam(description = "Service name", required = true) String serviceName,
            @ToolParam(description = "Optional ISO-8601 start time") String startTime,
            @ToolParam(description = "Optional ISO-8601 end time") String endTime,
            @ToolParam(description = "Optional step in seconds, must be > 0") Integer stepSeconds) {
    }
}
