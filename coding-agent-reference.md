# Agentic Microservices - Coding Agent Reference

**Repository:** `amollimaye/agentic-microservices`  
**Primary Language:** Java  
**License:** MIT

## Overview

This repo contains a Kubernetes-native local ecommerce microservices setup with minimal observability and an MCP-based observability agent.

Current runtime shape:
- `ecommerce` service aggregates data from `product` and `images`
- all three app services run on Kubernetes in namespace `ecommerce`
- observability stack runs in namespace `observability`
- separate MCP server runs in namespace `observability-agent`

Removed runtime dependencies:
- `nginx`
- `consul`
- `consul-template`
- `docker-compose` service discovery
- `HOST_IP` routing

## Core Services

### `product`
- Artifact: `product-service`
- Port: `8090`
- Context path: `/product-service`
- Database: H2 in-memory
- Purpose: returns product catalog data

### `images`
- Artifact: `images`
- Port: `8090`
- Context path: `/image-service`
- Database: H2 in-memory
- Purpose: returns image metadata for products

### `ecommerce`
- Artifact: `ecommerce`
- Port: `8090`
- Context path: `/ecommerce-service`
- Purpose: aggregates `product` and `images`
- Service discovery: Kubernetes DNS via:
  - `http://product-service:8090`
  - `http://images-service:8090`

### `observability-agent`
- Artifact: `observability-agent`
- Port: `8091`
- Purpose: REST + MCP access to Loki and Prometheus data
- Namespace: `observability-agent`

## Technology Baseline

### App services: `ecommerce`, `product`, `images`
- Java: `21`
- Spring Boot: `3.3.5`
- Build tool: Maven
- Runtime image: `eclipse-temurin:21-jdk-alpine`

Common dependencies:
- `spring-boot-starter-web`
- `spring-boot-starter-actuator`
- `spring-boot-starter-test`
- `micrometer-registry-prometheus`
- `logstash-logback-encoder`

Additional service dependencies:
- `product`, `images`:
  - `spring-boot-starter-data-jpa`
  - `h2`

### Observability agent
- Java: `21`
- Spring Boot: `3.x`
- Spring AI MCP Server (WebMVC)

## Kubernetes Layout

### Namespace: `ecommerce`
- `k8s/namespace.yaml`
- `k8s/product/`
- `k8s/images/`
- `k8s/ecommerce/`
- `k8s/ingress/`

Resources per service:
- `ConfigMap`
- `Deployment`
- `Service`

### Namespace: `observability`
- `k8s/observability/namespace.yaml`
- `k8s/observability/prometheus/`
- `k8s/observability/loki/`
- `k8s/observability/promtail/`
- `k8s/observability/grafana/`

### Namespace: `observability-agent`
- `k8s/observability-agent/namespace.yaml`
- `k8s/observability-agent/configmap.yaml`
- `k8s/observability-agent/deployment.yaml`
- `k8s/observability-agent/service.yaml`

## Local Endpoints

Stable local endpoints:
- App API: `http://localhost:8090/ecommerce-service/ecommerceProducts`
- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3000`

Ingress manifest exists, but the reliable local app entrypoint is the `LoadBalancer` service on `8090`.

## Observability

### Correlation ID
- Header: `X-Correlation-Id`
- preserved if incoming
- generated as UUID if absent
- propagated from `ecommerce` to downstream services
- stored in MDC as `correlationId`

### Logging
- JSON logs to stdout
- key fields:
  - `timestamp`
  - `service`
  - `level`
  - `correlationId`
  - `thread`
  - `logger`
  - `message`

### Metrics
- actuator endpoint exposed per service:
  - `/ecommerce-service/actuator/prometheus`
  - `/product-service/actuator/prometheus`
  - `/image-service/actuator/prometheus`

Enabled metric families:
- heap used/max
- live threads
- GC pause
- request count / request rate source metric

### Grafana
- datasources:
  - Prometheus
  - Loki
- one built-in dashboard for ecommerce service JVM metrics

## Observability Agent

Source:
- `microservices/observability-agent/`

Main capabilities:
- fetch logs by request id
- fetch logs by service
- fetch error logs by service
- fetch heap metrics
- fetch thread metrics
- fetch request-rate metrics
- list observable services

REST endpoints include:
- `/api/observability/logs/request/{requestId}`
- `/api/observability/logs/service/{serviceName}`
- `/api/observability/logs/errors/{serviceName}`
- `/api/observability/metrics/heap/{serviceName}`
- `/api/observability/metrics/threads/{serviceName}`
- `/api/observability/metrics/request-rate/{serviceName}`
- `/api/observability/services`

MCP tools include:
- `get_logs_by_request_id`
- `get_logs_by_service`
- `get_error_logs_by_service`
- `get_heap_metrics`
- `get_thread_metrics`
- `get_request_rate`
- `list_observable_services`

## Mock Data Tooling

Files:
- `mock-observability-data.bat`
- `scripts/generate-mock-observability-data.ps1`
- `mock-data-generation-prompt.md`

Purpose:
- load synthetic observability data for demos and testing
- simulate realistic metrics and correlated logs for:
  - full-day ecommerce sawtooth heap / GC behavior
  - night batch high-load window

## Repo Structure

```text
microservices/
  ecommerce/
  product/
  images/
  observability-agent/
k8s/
  ecommerce/
  product/
  images/
  ingress/
  observability/
    prometheus/
    loki/
    promtail/
    grafana/
  observability-agent/
start.bat
stop.bat
mock-observability-data.bat
mock-data-generation-prompt.md
scripts/
  generate-mock-observability-data.ps1
README.md
```

## Start / Stop

### Start everything
- `start.bat`

Builds and deploys:
- `observability-agent`
- `product`
- `images`
- `ecommerce`
- Prometheus
- Loki
- Promtail
- Grafana

### Stop everything
- `stop.bat`

Removes:
- app resources
- observability resources

## Important Agent Notes

1. App services are on Java 21 and Spring Boot 3.3.5.
2. `jakarta.*` imports are required in app code, not `javax.*`.
3. Use Kubernetes DNS names for internal calls, never `HOST_IP`.
4. Do not reintroduce `consul`, `nginx`, or compose-based routing.
5. App APIs should remain unchanged.
6. Local testing should prefer the `localhost:8090` service endpoint.
7. Observability stack and observability-agent are separate concerns and separate namespaces.
8. Request-rate metrics come from `http_server_requests_seconds_count`.

## Last Updated

`2026-05-13`
