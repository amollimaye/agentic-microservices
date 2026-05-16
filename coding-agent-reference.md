# Agentic Microservices - Coding Agent Reference

**Repository:** `amollimaye/agentic-microservices`  
**Primary Language:** Java  
**License:** MIT

## Purpose

Use this file as the working reference when adding new features to the repo.

This repo is a Kubernetes-native local ecommerce system with:
- 3 Spring Boot microservices
- 1 Spring Boot observability MCP service
- Prometheus, Loki, Promtail, Grafana
- local orchestration through `start.bat` / `stop.bat`

## Current Architecture

### Application services
- `ecommerce`
  - context path: `/ecommerce-service`
  - role: aggregates product + image data
- `product`
  - context path: `/product-service`
  - role: serves product catalog data from H2
- `images`
  - context path: `/image-service`
  - role: serves image metadata from H2

### Observability service
- `observability-agent`
  - role: REST + MCP access to Prometheus and Loki
  - namespace: `observability-agent`

### Kubernetes namespaces
- `ecommerce`
- `observability`
- `observability-agent`

## Technology Baseline

### App services
- Java `21`
- Spring Boot `3.3.5`
- Maven
- Docker base image: `eclipse-temurin:21-jdk-alpine`

Common app dependencies:
- `spring-boot-starter-web`
- `spring-boot-starter-actuator`
- `spring-boot-starter-test`
- `micrometer-registry-prometheus`
- `logstash-logback-encoder`

Extra dependencies:
- `product`, `images`
  - `spring-boot-starter-data-jpa`
  - `h2`

### Observability agent
- Java `21`
- Spring Boot `3.x`
- Spring AI MCP Server (WebMVC)

## Runtime URLs

Primary local URLs:
- App: `http://localhost:8090/ecommerce-service/ecommerceProducts`
- Ecommerce actuator: `http://localhost:8090/ecommerce-service/actuator`
- Ecommerce Prometheus: `http://localhost:8090/ecommerce-service/actuator/prometheus`
- Prometheus UI: `http://localhost:9090`
- Grafana UI: `http://localhost:3000`

## Service Discovery

Internal service calls use Kubernetes DNS only:
- `http://product-service:8090`
- `http://images-service:8090`

Do not reintroduce:
- `HOST_IP`
- `consul`
- `nginx`
- `docker-compose` service discovery

## Kubernetes Layout

### App manifests
- `k8s/namespace.yaml`
- `k8s/ecommerce/`
- `k8s/product/`
- `k8s/images/`
- `k8s/ingress/`

Each service has:
- `configmap.yaml`
- `deployment.yaml`
- `service.yaml`

### Observability manifests
- `k8s/observability/namespace.yaml`
- `k8s/observability/prometheus/`
- `k8s/observability/loki/`
- `k8s/observability/promtail/`
- `k8s/observability/grafana/`

### Observability agent manifests
- `k8s/observability-agent/namespace.yaml`
- `k8s/observability-agent/configmap.yaml`
- `k8s/observability-agent/deployment.yaml`
- `k8s/observability-agent/service.yaml`

## Build And Startup

### Normal way to start everything
- `start.bat`

What `start.bat` does now:
- builds fresh Docker images for app services
- uses a new timestamp tag on each run
- applies Kubernetes manifests
- updates deployments to the fresh image tags
- deploys observability stack

This matters because:
- reusing a static image tag caused stale-image confusion before
- the timestamp-tag flow is the current known-good behavior

### Stop everything
- `stop.bat`

## Observability

### Logging
- JSON logs to stdout
- fields:
  - `timestamp`
  - `service`
  - `level`
  - `correlationId`
  - `thread`
  - `logger`
  - `message`

### Correlation ID
- header: `X-Correlation-Id`
- preserved if present
- generated if absent
- propagated from `ecommerce` to downstream services
- stored in MDC as `correlationId`

### Metrics
Expected actuator path per service:
- `/ecommerce-service/actuator/prometheus`
- `/product-service/actuator/prometheus`
- `/image-service/actuator/prometheus`

Metrics currently intended for scraping:
- `jvm_memory_used_bytes`
- `jvm_memory_max_bytes`
- `jvm_threads_live_threads`
- `jvm_gc_pause_seconds_count`
- `jvm_gc_pause_seconds_sum`
- `jvm_gc_pause_seconds_max`
- `http_server_requests_seconds_count`

### Grafana
- datasource: Prometheus
- datasource: Loki
- dashboard: ecommerce JVM metrics

### Grafana logs
Use Grafana `Explore` with datasource `Loki`.

Common queries:
- `{namespace="ecommerce"}`
- `{namespace="ecommerce",app="ecommerce"}`
- `{namespace="ecommerce"} |= "some-correlation-id"`

## Observability Agent

Source:
- `microservices/observability-agent/`

REST endpoints:
- `/api/observability/logs/request/{requestId}`
- `/api/observability/logs/service/{serviceName}`
- `/api/observability/logs/errors/{serviceName}`
- `/api/observability/metrics/heap/{serviceName}`
- `/api/observability/metrics/threads/{serviceName}`
- `/api/observability/metrics/request-rate/{serviceName}`
- `/api/observability/services`

MCP tools:
- `get_logs_by_request_id`
- `get_logs_by_service`
- `get_error_logs_by_service`
- `get_heap_metrics`
- `get_thread_metrics`
- `get_request_rate`
- `list_observable_services`

## Database Initialization

`product` and `images` use H2 with SQL init files.

Important current behavior:
- `schema.sql`
- `data.sql`
- `spring.sql.init.mode=always`
- `spring.jpa.defer-datasource-initialization=true`
- `spring.jpa.hibernate.ddl-auto=none`

Do not switch those back to Hibernate schema creation unless you intentionally redesign DB init.

## Known Good / Known Bad

### Known good
- app data endpoint returns products at `localhost:8090`
- `start.bat` timestamp-tag deployment fixed stale image issues
- readiness/liveness currently use `/actuator/health`

### Known bad patterns
- static Docker tag reuse for app images
- conflicting DB init (`ddl-auto=create` plus `schema.sql`)
- assuming local `mvn spring-boot:run` behavior matches Kubernetes runtime
- reusing actuator endpoint id `prometheus` in a custom endpoint class

## Feature Development Rules

1. Keep existing REST APIs stable unless the feature explicitly requires API change.
2. Preserve current context paths:
   - `/ecommerce-service`
   - `/product-service`
   - `/image-service`
3. Prefer Kubernetes DNS names for inter-service calls.
4. Keep app services deployable independently.
5. When changing runtime behavior, update both:
   - app `application.properties`
   - Kubernetes `ConfigMap` env overrides
6. If you add metrics/logging/config behavior, check both local Spring Boot and Kubernetes runtime.
7. For any new container/runtime change, assume `start.bat` is the canonical local deployment flow.

## Files To Check First For New Features

### App code
- `microservices/ecommerce/src/main/java/...`
- `microservices/product/src/main/java/...`
- `microservices/images/src/main/java/...`

### App config
- `microservices/*/src/main/resources/application.properties`
- `microservices/*/src/main/resources/logback-spring.xml`

### K8s runtime config
- `k8s/ecommerce/configmap.yaml`
- `k8s/product/configmap.yaml`
- `k8s/images/configmap.yaml`
- `k8s/*/deployment.yaml`

### Observability
- `k8s/observability/prometheus/configmap.yaml`
- `k8s/observability/promtail/configmap.yaml`
- `k8s/observability/grafana/`
- `microservices/observability-agent/`

### Local orchestration
- `start.bat`
- `stop.bat`
- `README.md`

## Mock Data Tooling

Current files:
- `mock-observability-data.bat`
- `scripts/generate_mock_observability_data.py`
- `mock-data-generation-prompt.md`

Purpose:
- generate synthetic metrics/logs for demos and observability workflows

## Common Verification Targets

When changing application behavior:
- `http://localhost:8090/ecommerce-service/ecommerceProducts`

When changing actuator/metrics:
- `http://localhost:8090/ecommerce-service/actuator`
- `http://localhost:8090/ecommerce-service/actuator/prometheus`
- `http://localhost:9090`

When changing logs/observability:
- `http://localhost:3000`

## Fixes Done And Learnings

### Fixes done
- Removed old runtime assumptions:
  - `consul`
  - `nginx`
  - `HOST_IP`
  - compose-based service discovery
- Moved app services to:
  - Java `21`
  - Spring Boot `3.3.5`
- Updated test scaffolds from JUnit 4 to JUnit 5.
- Fixed probe restarts for `product` and `images` by using:
  - `/product-service/actuator/health`
  - `/image-service/actuator/health`
  instead of readiness/liveness paths that returned `404`
- Fixed empty product/image data after Boot 3 migration by using:
  - `spring.sql.init.mode=always`
  - `spring.jpa.defer-datasource-initialization=true`
  - `spring.jpa.hibernate.ddl-auto=none`
- Fixed Kubernetes runtime overrides by aligning `k8s/*/configmap.yaml` with application property changes.
- Fixed stale image problems by changing `start.bat` to use fresh timestamp-tagged Docker images every run and forcing deployment image updates.
- Added minimal observability stack:
  - Prometheus
  - Loki
  - Promtail
  - Grafana
- Added structured JSON logging and correlation-id propagation.
- Added observability agent with REST + MCP support.

### Learnings
- If local `mvn spring-boot:run` works but Kubernetes does not, check image freshness first.
- In this repo, Kubernetes `ConfigMap` env values can override `application.properties`; both must be kept in sync.
- Boot 3 migration can break H2 init silently if SQL init settings are not explicit.
- `ExitCode 143` with healthy startup logs usually points to probe failures, not app crashes.
- Reusing a static Docker tag like `:v2` is unreliable for rapid local Kubernetes iteration.
- For actuator debugging, the `/actuator` index is the fastest truth source for what is actually exposed.
- Do not create a custom actuator endpoint with id `prometheus` when Spring Boot already provides the built-in Prometheus endpoint.
- Do not assume a fix tested with `spring-boot:run` automatically proves the containerized runtime is using the same code/config.

## Last Updated

`2026-05-16`
