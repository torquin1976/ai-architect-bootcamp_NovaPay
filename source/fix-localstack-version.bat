@echo off
REM Fix LocalStack Version - Windows batch script

echo =========================================
echo LocalStack Version Fix
echo =========================================
echo.

echo This script will:
echo 1. Stop LocalStack container
echo 2. Remove development/nightly images
echo 3. Pull stable Community Edition (3.5.0)
echo 4. Restart with correct version
echo.

set /p CONTINUE="Continue? (y/n): "
if /i not "%CONTINUE%"=="y" exit /b

REM Stop containers
echo.
echo Stopping containers...
docker-compose -f docker-compose.windows.yml down 2>nul

REM Remove LocalStack images
echo.
echo Removing LocalStack images...
for /f "tokens=*" %%i in ('docker images localstack/localstack -q') do (
    docker rmi -f %%i
)
echo [OK] Removed old LocalStack images

REM Pull stable version
echo.
echo Pulling LocalStack Community Edition 3.5.0...
docker pull localstack/localstack:3.5.0

if errorlevel 1 (
    echo [ERROR] Failed to pull LocalStack 3.5.0
    exit /b 1
)

echo [OK] Successfully pulled LocalStack 3.5.0

REM Verify version
echo.
echo Verifying image...
docker images | findstr localstack

REM Restart services
echo.
echo Restarting services...
docker-compose -f docker-compose.windows.yml up -d

REM Wait for LocalStack to start
echo.
echo Waiting for LocalStack to start...
timeout /t 10 /nobreak >nul

REM Check version
echo.
echo Checking LocalStack version...
docker logs novapay-localstack 2>&1 | findstr "LocalStack version"

REM Check for auth errors
echo.
echo Checking for authentication errors...
docker logs novapay-localstack 2>&1 | findstr /i "license auth credential"

if errorlevel 1 (
    echo [OK] No authentication errors
) else (
    echo [WARNING] Found authentication errors
)

REM Check SQS
echo.
echo Checking SQS availability...
timeout /t 5 /nobreak >nul
curl -s http://localhost:4566/_localstack/health

echo.
echo =========================================
echo Done!
echo =========================================
echo.
echo Check logs with:
echo   docker logs novapay-localstack
echo.
echo Verify version with:
echo   docker logs novapay-localstack ^| findstr "LocalStack version"
echo.
pause
