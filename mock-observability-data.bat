@echo off
setlocal

set "ROOT_DIR=%~dp0"
if "%ROOT_DIR:~-1%"=="\" set "ROOT_DIR=%ROOT_DIR:~0,-1%"
set "PYTHON_CMD=py -3"
where py >nul 2>nul
if errorlevel 1 set "PYTHON_CMD=python"

echo [1/7] Switching to repo root...
cd /d "%ROOT_DIR%" || goto :fail

echo [2/7] Validating Kubernetes observability pods...
kubectl get pods -n observability || goto :fail

echo [3/7] Applying Prometheus and Promtail config...
kubectl apply -f "%ROOT_DIR%\k8s\observability\prometheus" || goto :fail
kubectl apply -f "%ROOT_DIR%\k8s\observability\promtail" || goto :fail
kubectl rollout restart deployment/prometheus -n observability || goto :fail
kubectl rollout status deployment/prometheus -n observability || goto :fail
kubectl rollout restart daemonset/promtail -n observability || goto :fail
kubectl rollout status daemonset/promtail -n observability || goto :fail

echo [4/7] Generating metrics and logs...
%PYTHON_CMD% "%ROOT_DIR%\scripts\generate_mock_observability_data.py" generate
if errorlevel 1 goto :fail

echo [5/7] Starting local mock metrics server if needed...
powershell -NoProfile -Command "try { Invoke-WebRequest -UseBasicParsing http://127.0.0.1:9105/ecommerce.prom | Out-Null; exit 0 } catch { exit 1 }"
if errorlevel 1 (
  start "mock-metrics-server" /min cmd /c %PYTHON_CMD% "%ROOT_DIR%\scripts\generate_mock_observability_data.py" serve --port 9105 --seconds-per-minute 1 ^> "%ROOT_DIR%\generated-metrics\server.log" 2^>^&1
  timeout /t 2 /nobreak >nul
)

echo [6/7] Copying generated logs into Promtail...
for /f %%P in ('kubectl get pods -n observability -l app=promtail -o jsonpath="{.items[0].metadata.name}"') do set "PROMTAIL_POD=%%P"
if "%PROMTAIL_POD%"=="" goto :fail
kubectl exec -n observability %PROMTAIL_POD% -- sh -c "mkdir -p /generated-logs && rm -f /generated-logs/*.log" || goto :fail
pushd "%ROOT_DIR%\generated-logs"
kubectl cp . "observability/%PROMTAIL_POD%:/generated-logs" || goto :fail
popd

echo [7/7] Mock data mechanism is ready...

echo.
echo Mock data load complete.
echo Metrics replay endpoint: http://localhost:9105/ecommerce.prom
goto :eof

:fail
echo.
echo Mock data load failed. Check the command output above.
exit /b 1
