package com.amol.microservices.ecommerce.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.ClientHttpRequestExecution;
import org.springframework.http.client.ClientHttpRequestInterceptor;
import org.springframework.http.client.ClientHttpResponse;
import org.springframework.web.client.RestTemplate;
import org.slf4j.MDC;

import java.io.IOException;
import java.util.Collections;

/**
 * @author Amol Limaye
 **/
@Configuration
public class ServiceConfiguration {

    @Value("${observability.correlation.header:X-Correlation-Id}")
    private String correlationHeader;

    @Bean
    public RestTemplate restTemplate() {
        RestTemplate restTemplate = new RestTemplate();
        restTemplate.setInterceptors(Collections.singletonList(new CorrelationIdInterceptor(correlationHeader)));
        return restTemplate;
    }

    private static class CorrelationIdInterceptor implements ClientHttpRequestInterceptor {
        private final String correlationHeader;

        private CorrelationIdInterceptor(String correlationHeader) {
            this.correlationHeader = correlationHeader;
        }

        @Override
        public ClientHttpResponse intercept(org.springframework.http.HttpRequest request, byte[] body,
                                            ClientHttpRequestExecution execution) throws IOException {
            String correlationId = MDC.get("correlationId");
            if (correlationId != null && !correlationId.isEmpty()) {
                request.getHeaders().set(correlationHeader, correlationId);
            }
            return execution.execute(request, body);
        }
    }
}
