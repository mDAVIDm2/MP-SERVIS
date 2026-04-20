@echo off
set "RUN_EXIT=0"

echo ========================================
echo   MP-Servis Backend - NestJS
echo ========================================
echo.

cd /d "%~dp0backend"
if errorlevel 1 (
  echo ERROR - Cannot cd to backend.
  set "RUN_EXIT=1"
  goto :final
)
if not exist "package.json" (
  echo ERROR - package.json missing in backend.
  set "RUN_EXIT=1"
  goto :final
)

where node >nul 2>&1
if errorlevel 1 (
  echo ERROR - node not in PATH.
  set "RUN_EXIT=9001"
  goto :final
)

if not exist "node_modules\" (
  echo npm install...
  call npm install
  if errorlevel 1 (
    set "RUN_EXIT=%errorlevel%"
    goto :final
  )
)

echo npm run start:dev ^(Ctrl+C to stop^)
echo.
call npm run start:dev
set "RUN_EXIT=%errorlevel%"

:final
echo.
if not "%RUN_EXIT%"=="0" (
  echo Finished with error, code %RUN_EXIT%.
)
if "%NO_PAUSE%"=="1" exit /b %RUN_EXIT%
echo.
echo Press any key to close...
pause
exit /b %RUN_EXIT%
