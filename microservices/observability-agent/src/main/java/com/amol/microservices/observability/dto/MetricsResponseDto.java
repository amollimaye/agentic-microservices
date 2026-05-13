package com.amol.microservices.observability.dto;

import java.util.List;

public record MetricsResponseDto(String service, String metric, List<MetricPointDto> points) {
}
