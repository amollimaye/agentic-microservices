package com.amol.microservices.observability.dto;

import java.time.Instant;

public record LogEntryDto(Instant timestamp, String service, String level, String message) {
}
