@echo off
REM NovaPay Local Environment Startup Script for Windows

echo =========================================
echo NovaPay Local Environment Setup
echo =========================================
echo.

REM Check if Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo Error: Docker is not running. Please start Docker Desktop.
    exit /b 1
)

echo [OK] Docker is running

REM Check if docker-compose is available
docker-compose --version >nul 2>&1
if errorlevel 1 (
    echo Error: docker-compose is not installed.
    exit /b 1
)

echo [OK] docker-compose is available

REM Stop any existing containers
echo.
echo Stopping existing containers...
docker-compose -f docker-compose.windows.yml down 2>nul

REM Build and start services
echo.
echo Building and starting services...
docker-compose -f docker-compose.windows.yml up --build -d

REM Wait for services to be healthy
echo.
echo Waiting for services to be healthy...
timeout /t 10 /nobreak >nul

REM Show service status
echo.
echo Service Status:
echo ---------------
docker-compose -f docker-compose.windows.yml ps

REM Show service URLs
echo.
echo Service URLs:
echo -------------
echo Payment Service: http://localhost:3001
echo   - POST /auth    - Card authorization
echo   - POST /charge  - Payment capture
echo   - POST /refund  - Payment refund
echo   - GET  /health  - Health check
echo.
echo KYC Service: http://localhost:3002
echo   - POST /kyc     - SSN validation
echo   - GET  /health  - Health check
echo.
echo PostgreSQL: localhost:5432
echo   - Database: novapay
echo   - User: np
echo   - Password: np
echo.
echo Redis: localhost:6379
echo.
echo LocalStack (SQS): http://localhost:4566
echo.

REM Show logs command
echo View logs with:
echo   docker-compose -f docker-compose.windows.yml logs -f
echo.
echo Stop services with:
echo   docker-compose -f docker-compose.windows.yml down
echo.

echo [OK] Local environment is ready!
pause
