@echo off
setlocal enabledelayedexpansion

set "ROOT_DIR=%~dp0"
if "%ROOT_DIR:~-1%"=="\" set "ROOT_DIR=%ROOT_DIR:~0,-1%"

echo [1/10] Switching to repo root...
cd /d "%ROOT_DIR%" || goto :fail

echo [2/10] Removing old Kubernetes resources if present...
kubectl delete -f "%ROOT_DIR%\k8s\ingress" --ignore-not-found
kubectl delete -f "%ROOT_DIR%\k8s\ecommerce" --ignore-not-found
kubectl delete -f "%ROOT_DIR%\k8s\images" --ignore-not-found
kubectl delete -f "%ROOT_DIR%\k8s\product" --ignore-not-found
kubectl delete -f "%ROOT_DIR%\k8s\observability\grafana" --ignore-not-found
kubectl delete -f "%ROOT_DIR%\k8s\observability\promtail" --ignore-not-found
kubectl delete -f "%ROOT_DIR%\k8s\observability\loki" --ignore-not-found
kubectl delete -f "%ROOT_DIR%\k8s\observability\prometheus" --ignore-not-found

echo [3/10] Removing stale local Docker images...
docker rmi ecommerce:v2 images:v2 product-service:v2 2>nul

echo [4/10] Building product-service...
cd /d "%ROOT_DIR%\microservices\product" || goto :fail
call mvn clean package
if errorlevel 1 goto :fail
docker build --no-cache -t product-service:v2 .
if errorlevel 1 goto :fail

echo [5/10] Building images...
cd /d "%ROOT_DIR%\microservices\images" || goto :fail
call mvn clean package
if errorlevel 1 goto :fail
docker build --no-cache -t images:v2 .
if errorlevel 1 goto :fail

echo [6/10] Building ecommerce...
cd /d "%ROOT_DIR%\microservices\ecommerce" || goto :fail
call mvn clean package
if errorlevel 1 goto :fail
docker build --no-cache -t ecommerce:v2 .
if errorlevel 1 goto :fail

echo [7/10] Deploying application Kubernetes resources...
cd /d "%ROOT_DIR%" || goto :fail
kubectl apply -f "%ROOT_DIR%\k8s\namespace.yaml"
if errorlevel 1 goto :fail
kubectl apply -f "%ROOT_DIR%\k8s\product"
if errorlevel 1 goto :fail
kubectl apply -f "%ROOT_DIR%\k8s\images"
if errorlevel 1 goto :fail
kubectl apply -f "%ROOT_DIR%\k8s\ecommerce"
if errorlevel 1 goto :fail
kubectl apply -f "%ROOT_DIR%\k8s\ingress"
if errorlevel 1 goto :fail

echo [8/10] Deploying observability stack...
kubectl apply -f "%ROOT_DIR%\k8s\observability\namespace.yaml"
if errorlevel 1 goto :fail
kubectl apply -f "%ROOT_DIR%\k8s\observability\prometheus"
if errorlevel 1 goto :fail
kubectl apply -f "%ROOT_DIR%\k8s\observability\loki"
if errorlevel 1 goto :fail
kubectl apply -f "%ROOT_DIR%\k8s\observability\promtail"
if errorlevel 1 goto :fail
kubectl apply -f "%ROOT_DIR%\k8s\observability\grafana"
if errorlevel 1 goto :fail

echo [9/10] Waiting for application deployments...
kubectl rollout status deployment/product -n ecommerce
if errorlevel 1 goto :fail
kubectl rollout status deployment/images -n ecommerce
if errorlevel 1 goto :fail
kubectl rollout status deployment/ecommerce -n ecommerce
if errorlevel 1 goto :fail

echo [10/10] Waiting for observability deployments...
kubectl rollout status deployment/prometheus -n observability
if errorlevel 1 goto :fail
kubectl rollout status deployment/loki -n observability
if errorlevel 1 goto :fail
kubectl rollout status deployment/grafana -n observability
if errorlevel 1 goto :fail

echo.
echo Pods:
kubectl get pods -n ecommerce
echo.
echo Observability Pods:
kubectl get pods -n observability
echo.
echo Services:
kubectl get svc -n ecommerce
echo.
echo Observability Services:
kubectl get svc -n observability
echo.
echo Ingress:
kubectl get ingress -n ecommerce
echo.
echo Startup complete.
echo Test with:
echo   kubectl logs -n ecommerce deploy/product
echo   kubectl logs -n ecommerce deploy/images
echo   kubectl logs -n ecommerce deploy/ecommerce
echo   curl http://localhost:8090/ecommerce-service/ecommerceProducts
echo   http://localhost:9090
echo   http://localhost:3000
goto :eof

:fail
echo.
echo Startup failed. Check the command output above.
exit /b 1
