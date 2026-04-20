@echo off
setlocal EnableDelayedExpansion
set "RUN_EXIT=0"

echo ========================================
echo   MP-Servis Control Center (dev panel)
echo ========================================
echo.
echo API: по умолчанию https://api.mp-servis.ru/api/v1 (зашито в приложении).
echo       Локальный Nest: set MP_SERVIS_API_BASE=http://127.0.0.1:3000
echo.
echo Учётные данные: опционально control_center.credentials.dat (шаблон: .example.dat)
echo ВАЖНО: это логин из internal_operators на сервере, НЕ аккаунт клиентского приложения.
echo Если 401 — на сервере задайте INITIAL_SUPERADMIN_* в .env и перезапустите API, либо: backend npm run seed:internal
echo.

cd /d "%~dp0autohub_control_center"
if errorlevel 1 (
  echo ERROR: нет папки autohub_control_center.
  exit /b 1
)

set "EXTRA_DEFINES="
if exist "%~dp0control_center.credentials.dat" (
  for /f "usebackq eol=# tokens=1,* delims==" %%a in ("%~dp0control_center.credentials.dat") do (
    if /I "%%a"=="EMAIL" set "CC_USER_EMAIL=%%b"
    if /I "%%a"=="PASSWORD" set "CC_USER_PASSWORD=%%b"
  )
  if defined CC_USER_EMAIL (
    set "EXTRA_DEFINES=!EXTRA_DEFINES! --dart-define=MP_CONTROL_DEV_EMAIL=!CC_USER_EMAIL!"
  )
  if defined CC_USER_PASSWORD (
    set "EXTRA_DEFINES=!EXTRA_DEFINES! --dart-define=MP_CONTROL_DEV_PASSWORD=!CC_USER_PASSWORD!"
  )
  echo Подставлены учётные данные из control_center.credentials.dat
  echo.
)

if not "%MP_SERVIS_API_BASE%"=="" (
  set "EXTRA_DEFINES=!EXTRA_DEFINES! --dart-define=MP_SERVIS_API_BASE_URL=%MP_SERVIS_API_BASE%"
  echo Используется MP_SERVIS_API_BASE=%MP_SERVIS_API_BASE%
  echo.
)

where flutter >nul 2>&1
if errorlevel 1 (
  echo ERROR: flutter не в PATH.
  exit /b 9001
)

call flutter pub get
if errorlevel 1 exit /b %errorlevel%

echo flutter run -d windows !EXTRA_DEFINES!
call flutter run -d windows !EXTRA_DEFINES!
set "RUN_EXIT=%errorlevel%"

echo.
if not "%RUN_EXIT%"=="0" echo Код выхода: %RUN_EXIT%
if "%NO_PAUSE%"=="1" exit /b %RUN_EXIT%
pause
exit /b %RUN_EXIT%
