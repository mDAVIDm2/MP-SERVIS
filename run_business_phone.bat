@echo off
set "RUN_EXIT=0"

echo ========================================
echo   MP-Servis Business - phone / emulator
echo ========================================
echo.
echo Connect USB device or start an emulator.
echo.
echo API: по умолчанию прод https://api.mp-servis.ru/api/v1
echo       Для Nest в LAN: set USE_LAN_API=1 перед запуском этого bat.
echo.
echo Если установка падает ^(подпись не совпадает^): adb uninstall ru.mpservis.business
echo.

cd /d "%~dp0autohub_business"
if errorlevel 1 (
  echo ERROR - Cannot cd to autohub_business.
  set "RUN_EXIT=1"
  goto :final
)
if not exist "pubspec.yaml" (
  echo ERROR - pubspec.yaml missing in autohub_business.
  set "RUN_EXIT=1"
  goto :final
)

where flutter >nul 2>&1
if errorlevel 1 (
  echo ERROR - flutter not in PATH.
  set "RUN_EXIT=9001"
  goto :final
)

echo flutter pub get...
call flutter pub get
if errorlevel 1 (
  set "RUN_EXIT=%errorlevel%"
  goto :final
)

if "%USE_LAN_API%"=="1" (
  call flutter run
) else (
  call flutter run --dart-define=MP_SERVIS_API_BASE_URL=https://api.mp-servis.ru/api/v1
)
set "RUN_EXIT=%errorlevel%"

:final
echo.
if not "%RUN_EXIT%"=="0" (
  echo Finished with error, code %RUN_EXIT%.
) else (
  echo flutter run finished OK.
)
echo.
if "%NO_PAUSE%"=="1" exit /b %RUN_EXIT%
echo Press any key to close...
pause
exit /b %RUN_EXIT%
