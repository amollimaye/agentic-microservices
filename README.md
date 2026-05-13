# microservices-ecommerce-2

## Prerequisites

* Java 17
* Maven
* Docker Desktop
* Kubernetes enabled in Docker Desktop
* `kubectl`

## Start

```powershell
cd C:\git\microservices-ecommerce-2
start.bat
```

## Stop

```powershell
cd C:\git\microservices-ecommerce-2
stop.bat
```

## URLs

* App: `http://localhost:8090/ecommerce-service/ecommerceProducts`
* Prometheus: `http://localhost:9090`
* Grafana: `http://localhost:3000`

## Notes

* `start.bat` builds `observability-agent`, `product`, `images`, and `ecommerce`
* Observability includes logs, JVM metrics, and request-rate metrics
