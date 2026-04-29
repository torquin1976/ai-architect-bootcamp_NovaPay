@echo off
REM Rebuild Docker Services Script for Windows

echo =========================================
echo Rebuilding NovaPay Docker Services
echo =========================================
echo.

echo Stopping services...
docker-compose -f docker-compose.windows.yml down

echo.
echo Rebuilding images (this may take a few minutes)...
docker-compose -f docker-compose.windows.yml build --no-cache

echo.
echo Starting services...
docker-compose -f docker-compose.windows.yml up -d

echo.
echo Waiting for services to be healthy...
timeout /t 15 /nobreak >nul

echo.
echo Service Status:
docker-compose -f docker-compose.windows.yml ps

echo.
echo [OK] Done! Services have been rebuilt.
echo.
echo Check logs with:
echo   docker-compose -f docker-compose.windows.yml logs -f
echo.
echo Test services with:
echo   curl http://localhost:3001/health
echo   curl http://localhost:3002/health
echo.
pause
