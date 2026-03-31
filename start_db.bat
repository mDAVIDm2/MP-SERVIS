@echo off
chcp 65001 >nul 2>&1
set "DB_EXIT=0"

echo ========================================
echo   AutoHub: запуск БД (PostgreSQL)
echo ========================================
echo.

docker ps -a --filter "name=autohub-pg" --format "{{.Names}}" | findstr /x "autohub-pg" >nul 2>&1
if errorlevel 1 goto :db_create
echo Контейнер autohub-pg найден. Запуск...
docker start autohub-pg
goto :db_after

:db_create
echo Создание и запуск контейнера PostgreSQL...
docker run -d --name autohub-pg -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=autohub -p 5432:5432 postgres:16-alpine

:db_after
set "DB_EXIT=%errorlevel%"
if not "%DB_EXIT%"=="0" (
  echo.
  echo Ошибка Docker (код %DB_EXIT%). Убедитесь, что Docker запущен.
  goto :final
)

echo.
echo БД: postgresql://postgres:postgres@localhost:5432/autohub
echo.

:final
echo.
echo Нажмите любую клавишу, чтобы закрыть окно...
pause
exit /b %DB_EXIT%
