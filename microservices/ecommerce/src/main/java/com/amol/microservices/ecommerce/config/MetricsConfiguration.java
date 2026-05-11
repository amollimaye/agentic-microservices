package com.amol.microservices.ecommerce.config;

import io.micrometer.core.instrument.Meter;
import io.micrometer.core.instrument.config.MeterFilter;
import io.micrometer.core.instrument.config.MeterFilterReply;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class MetricsConfiguration {

    @Bean
    public MeterFilter meterFilter() {
        return new MeterFilter() {
            @Override
            public MeterFilterReply accept(Meter.Id id) {
                String name = id.getName();
                if ("jvm.memory.used".equals(name) || "jvm.memory.max".equals(name)) {
                    String area = id.getTag("area");
                    return "heap".equals(area) ? MeterFilterReply.NEUTRAL : MeterFilterReply.DENY;
                }
                if ("jvm.threads.live".equals(name) || "jvm.gc.pause".equals(name)) {
                    return MeterFilterReply.NEUTRAL;
                }
                return MeterFilterReply.DENY;
            }
        };
    }
}
