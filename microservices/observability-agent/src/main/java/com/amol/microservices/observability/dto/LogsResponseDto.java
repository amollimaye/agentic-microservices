package com.amol.microservices.observability.dto;

import java.util.List;

public record LogsResponseDto(String requestId, List<LogEntryDto> logs) {
}
