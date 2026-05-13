package com.amol.microservices.observability.controller;

import com.amol.microservices.observability.dto.ErrorResponseDto;
import com.amol.microservices.observability.dto.LogsResponseDto;
import com.amol.microservices.observability.dto.MetricsResponseDto;
import com.amol.microservices.observability.dto.ServicesResponseDto;
import com.amol.microservices.observability.service.ObservabilityService;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.time.format.DateTimeParseException;

@RestController
@RequestMapping("/api/observability")
public class ObservabilityController {

    private final ObservabilityService service;

    public ObservabilityController(ObservabilityService service) {
        this.service = service;
    }

    @GetMapping("/logs/request/{requestId}")
    public ResponseEntity<LogsResponseDto> logsByRequestId(@PathVariable String requestId,
                                                           @RequestParam(required = false) String startTime,
                                                           @RequestParam(required = false) String endTime) {
        Instant start = parseOrNull(startTime);
        Instant end = parseOrNull(endTime);
        validateRange(start, end);
        LogsResponseDto resp = service.getLogsByRequestId(requestId, start, end);
        return ResponseEntity.ok(resp);
    }

    @GetMapping("/logs/service/{serviceName}")
    public ResponseEntity<LogsResponseDto> logsByService(@PathVariable @NotBlank String serviceName,
                                                         @RequestParam(required = false) String startTime,
                                                         @RequestParam(required = false) String endTime) {
        Instant start = parseOrNull(startTime);
        Instant end = parseOrNull(endTime);
        validateRange(start, end);
        LogsResponseDto resp = service.getLogsByService(serviceName, start, end);
        return ResponseEntity.ok(resp);
    }

    @GetMapping("/logs/errors/{serviceName}")
    public ResponseEntity<LogsResponseDto> errorLogsByService(@PathVariable @NotBlank String serviceName,
                                                              @RequestParam(required = false) String startTime,
                                                              @RequestParam(required = false) String endTime) {
        Instant start = parseOrNull(startTime);
        Instant end = parseOrNull(endTime);
        validateRange(start, end);
        LogsResponseDto resp = service.getErrorLogsByService(serviceName, start, end);
        return ResponseEntity.ok(resp);
    }

    @GetMapping("/metrics/heap/{serviceName}")
    public ResponseEntity<MetricsResponseDto> heapMetrics(@PathVariable @NotBlank String serviceName,
                                                          @RequestParam(required = false) String startTime,
                                                          @RequestParam(required = false) String endTime,
                                                          @RequestParam(required = false) Integer stepSeconds) {
        Instant start = parseOrNull(startTime);
        Instant end = parseOrNull(endTime);
        validateRange(start, end);
        if (stepSeconds != null && stepSeconds <= 0) throw new IllegalArgumentException("stepSeconds must be > 0");
        MetricsResponseDto resp = service.getHeapMetrics(serviceName, start, end, stepSeconds);
        return ResponseEntity.ok(resp);
    }

    @GetMapping("/metrics/threads/{serviceName}")
    public ResponseEntity<MetricsResponseDto> threadMetrics(@PathVariable @NotBlank String serviceName,
                                                            @RequestParam(required = false) String startTime,
                                                            @RequestParam(required = false) String endTime,
                                                            @RequestParam(required = false) Integer stepSeconds) {
        Instant start = parseOrNull(startTime);
        Instant end = parseOrNull(endTime);
        validateRange(start, end);
        if (stepSeconds != null && stepSeconds <= 0) throw new IllegalArgumentException("stepSeconds must be > 0");
        MetricsResponseDto resp = service.getThreadMetrics(serviceName, start, end, stepSeconds);
        return ResponseEntity.ok(resp);
    }

    @GetMapping("/metrics/request-rate/{serviceName}")
    public ResponseEntity<MetricsResponseDto> requestRateMetrics(@PathVariable @NotBlank String serviceName,
                                                                 @RequestParam(required = false) String startTime,
                                                                 @RequestParam(required = false) String endTime,
                                                                 @RequestParam(required = false) Integer stepSeconds) {
        Instant start = parseOrNull(startTime);
        Instant end = parseOrNull(endTime);
        validateRange(start, end);
        if (stepSeconds != null && stepSeconds <= 0) throw new IllegalArgumentException("stepSeconds must be > 0");
        MetricsResponseDto resp = service.getRequestRateMetrics(serviceName, start, end, stepSeconds);
        return ResponseEntity.ok(resp);
    }

    @GetMapping("/services")
    public ResponseEntity<ServicesResponseDto> services() {
        ServicesResponseDto resp = service.listObservableServices();
        return ResponseEntity.ok(resp);
    }

    private Instant parseOrNull(String s) {
        if (s == null || s.isBlank()) return null;
        try {
            return Instant.parse(s);
        } catch (DateTimeParseException ex) {
            throw new IllegalArgumentException("Invalid ISO timestamp: " + s);
        }
    }

    private void validateRange(Instant start, Instant end) {
        if (start != null && end != null && start.isAfter(end)) throw new IllegalArgumentException("startTime must be before endTime");
    }
}
