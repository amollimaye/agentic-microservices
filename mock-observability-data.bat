@echo off
setlocal

set "ROOT_DIR=%~dp0"
if "%ROOT_DIR:~-1%"=="\" set "ROOT_DIR=%ROOT_DIR:~0,-1%"

echo [1/3] Switching to repo root...
cd /d "%ROOT_DIR%" || goto :fail

echo [2/3] Validating Kubernetes observability pods...
kubectl get pods -n observability || goto :fail

echo [3/3] Loading mock metrics and logs...
powershell -ExecutionPolicy Bypass -File "%ROOT_DIR%\scripts\generate-mock-observability-data.ps1"
if errorlevel 1 goto :fail

echo.
echo Mock data load complete.
goto :eof

:fail
echo.
echo Mock data load failed. Check the command output above.
exit /b 1
