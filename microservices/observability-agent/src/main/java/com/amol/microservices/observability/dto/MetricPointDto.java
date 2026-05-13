package com.amol.microservices.observability.dto;

import java.time.Instant;

public record MetricPointDto(Instant timestamp, double value) {
}
