@echo off
setlocal

set "ROOT_DIR=%~dp0"
if "%ROOT_DIR:~-1%"=="\" set "ROOT_DIR=%ROOT_DIR:~0,-1%"

echo [1/4] Switching to repo root...
cd /d "%ROOT_DIR%" || goto :fail

echo [2/4] Removing observability resources...
kubectl delete -f "%ROOT_DIR%\k8s\observability\grafana" --ignore-not-found
kubectl delete -f "%ROOT_DIR%\k8s\observability\promtail" --ignore-not-found
kubectl delete -f "%ROOT_DIR%\k8s\observability\loki" --ignore-not-found
kubectl delete -f "%ROOT_DIR%\k8s\observability\prometheus" --ignore-not-found

echo [3/4] Removing application resources...
kubectl delete -f "%ROOT_DIR%\k8s\ingress" --ignore-not-found
kubectl delete -f "%ROOT_DIR%\k8s\ecommerce" --ignore-not-found
kubectl delete -f "%ROOT_DIR%\k8s\images" --ignore-not-found
kubectl delete -f "%ROOT_DIR%\k8s\product" --ignore-not-found

echo [4/4] Current namespace status...
kubectl get pods -n ecommerce --ignore-not-found
kubectl get pods -n observability --ignore-not-found

echo.
echo Shutdown complete.
goto :eof

:fail
echo.
echo Shutdown failed. Check the command output above.
exit /b 1
