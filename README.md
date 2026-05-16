# microservices-ecommerce-2

## Prerequisites

* Java 21
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
* Ecommerce Actuator: `http://localhost:8090/ecommerce-service/actuator`
* Ecommerce Prometheus: `http://localhost:8090/ecommerce-service/actuator/prometheus`
* Prometheus: `http://localhost:9090`
* Grafana: `http://localhost:3000`

## Notes

* `start.bat` rebuilds and deploys fresh timestamp-tagged images for `product`, `images`, and `ecommerce`
* Observability includes Loki logs, Prometheus JVM metrics, and request-rate metrics
* View logs in Grafana from `Explore` using datasource `Loki`
