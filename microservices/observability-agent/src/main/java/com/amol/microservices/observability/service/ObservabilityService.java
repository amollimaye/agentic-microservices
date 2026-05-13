package com.amol.microservices.observability.service;

import com.amol.microservices.observability.client.LokiClient;
import com.amol.microservices.observability.client.PrometheusClient;
import com.amol.microservices.observability.dto.LogEntryDto;
import com.amol.microservices.observability.dto.LogsResponseDto;
import com.amol.microservices.observability.dto.MetricsResponseDto;
import com.amol.microservices.observability.dto.ServicesResponseDto;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.List;

@Service
public class ObservabilityService {

    private final LokiClient lokiClient;
    private final PrometheusClient prometheusClient;

    public ObservabilityService(LokiClient lokiClient, PrometheusClient prometheusClient) {
        this.lokiClient = lokiClient;
        this.prometheusClient = prometheusClient;
    }

    public LogsResponseDto getLogsByRequestId(String requestId, Instant start, Instant end) {
        return lokiClient.queryByRequestId(requestId, start, end);
    }

    public LogsResponseDto getLogsByService(String serviceName, Instant start, Instant end) {
        return lokiClient.queryByService(serviceName, start, end);
    }

    public LogsResponseDto getErrorLogsByService(String serviceName, Instant start, Instant end) {
        return lokiClient.queryErrorByService(serviceName, start, end);
    }

    public MetricsResponseDto getHeapMetrics(String serviceName, Instant start, Instant end, Integer stepSeconds) {
        return prometheusClient.queryRange("jvm_memory_used_bytes", serviceName, start, end, stepSeconds);
    }

    public MetricsResponseDto getThreadMetrics(String serviceName, Instant start, Instant end, Integer stepSeconds) {
        return prometheusClient.queryRange("jvm_threads_live_threads", serviceName, start, end, stepSeconds);
    }

    public MetricsResponseDto getRequestRateMetrics(String serviceName, Instant start, Instant end, Integer stepSeconds) {
        return prometheusClient.queryRange("rate(http_server_requests_seconds_count[1m])", serviceName, start, end, stepSeconds);
    }

    public ServicesResponseDto listObservableServices() {
        return new ServicesResponseDto(List.of("product-service", "images-service", "ecommerce-service"));
    }
}
