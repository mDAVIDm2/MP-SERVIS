@echo off
set "DB_EXIT=0"

echo ========================================
echo   MP-Servis - PostgreSQL (Docker)
echo ========================================
echo.

where docker >nul 2>&1
if errorlevel 1 (
  echo ERROR - Docker not in PATH. Install Docker Desktop.
  set "DB_EXIT=9001"
  goto :final
)

docker info >nul 2>&1
if errorlevel 1 (
  echo ERROR - Docker daemon not running. Start Docker Desktop.
  set "DB_EXIT=9002"
  goto :final
)

docker ps -a --filter "name=mp-servis-pg" --format "{{.Names}}" | findstr /x "mp-servis-pg" >nul 2>&1
if errorlevel 1 goto :db_create
echo Container mp-servis-pg found. Starting...
docker start mp-servis-pg
goto :db_after

:db_create
echo Creating and starting PostgreSQL 16 container...
docker run -d --name mp-servis-pg -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=postgres -p 5432:5432 postgres:16-alpine

:db_after
set "DB_EXIT=%errorlevel%"
if not "%DB_EXIT%"=="0" (
  echo.
  echo Docker error, code %DB_EXIT%.
  goto :final
)

echo Waiting for postgres...
:wait_loop
docker exec mp-servis-pg pg_isready -U postgres >nul 2>&1
if errorlevel 1 (
  timeout /t 1 /nobreak >nul
  goto :wait_loop
)

echo Ensuring databases mp_servis and autohub exist...
docker exec mp-servis-pg psql -U postgres -c "CREATE DATABASE mp_servis;" 2>nul
docker exec mp-servis-pg psql -U postgres -c "CREATE DATABASE autohub;" 2>nul

echo.
echo Use in backend .env for example:
echo   postgresql://postgres:postgres@localhost:5432/mp_servis
echo   postgresql://postgres:postgres@localhost:5432/autohub
echo.

:final
if "%NO_PAUSE%"=="1" exit /b %DB_EXIT%
echo.
echo Press any key to close...
pause
exit /b %DB_EXIT%
