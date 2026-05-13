package com.amol.microservices.observability.mcp;

import org.springframework.ai.tool.ToolCallbackProvider;
import org.springframework.ai.tool.method.MethodToolCallbackProvider;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class McpConfiguration {

    @Bean
    ToolCallbackProvider observabilityToolCallbackProvider(ObservabilityTools observabilityTools) {
        return MethodToolCallbackProvider.builder()
                .toolObjects(observabilityTools)
                .build();
    }
}
