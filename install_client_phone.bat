@echo off
setlocal EnableDelayedExpansion
set "RUN_EXIT=0"

echo ========================================
echo   MP-Servis Client - install on device
echo ========================================
echo.
echo Подключите телефон по USB ^(отладка USB^) или запустите эмулятор.
echo   Список устройств: flutter devices
echo   Другой девайс: set DEVICE_ID=^<id^> перед запуском.
echo.
echo Сборка: по умолчанию release ^(как прод^).
echo   Быстрый debug: set DEBUG_INSTALL=1
echo API: по умолчанию https://api.mp-servis.ru/api/v1
echo   Локальный Nest: set USE_LAN_API=1
echo.
echo Конфликт подписи: adb uninstall ru.mpservis.client
echo.

cd /d "%~dp0autohub_client2"
if errorlevel 1 (
  echo ERROR: не удалось перейти в autohub_client2.
  exit /b 1
)
if not exist "pubspec.yaml" (
  echo ERROR: нет pubspec.yaml.
  exit /b 1
)

where flutter >nul 2>&1
if errorlevel 1 (
  echo ERROR: flutter не в PATH.
  exit /b 9001
)

set "ARGS="
if not "%USE_LAN_API%"=="1" (
  set "ARGS=--dart-define=MP_SERVIS_API_BASE_URL=https://api.mp-servis.ru/api/v1"
)
if exist "config\firebase_define.json" (
  if defined ARGS (
    set "ARGS=!ARGS! --dart-define-from-file=config/firebase_define.json"
  ) else (
    set "ARGS=--dart-define-from-file=config/firebase_define.json"
  )
)

echo flutter pub get...
call flutter pub get
if errorlevel 1 exit /b %errorlevel%

if "%DEBUG_INSTALL%"=="1" (
  echo.
  echo Сборка APK ^(debug^)...
  if defined ARGS (
    call flutter build apk --debug !ARGS!
  ) else (
    call flutter build apk --debug
  )
  set "APK=build\app\outputs\flutter-apk\app-debug.apk"
) else (
  echo.
  echo Сборка APK ^(release^)...
  if defined ARGS (
    call flutter build apk --release !ARGS!
  ) else (
    call flutter build apk --release
  )
  set "APK=build\app\outputs\flutter-apk\app-release.apk"
)
if errorlevel 1 (
  echo ERROR: сборка не удалась.
  exit /b %errorlevel%
)

if not exist "!APK!" (
  echo ERROR: APK не найден: !APK!
  exit /b 2
)

echo.
echo Установка: !APK!
if not "%DEVICE_ID%"=="" (
  call flutter install --use-application-binary="!APK!" -d "!DEVICE_ID!"
) else (
  call flutter install --use-application-binary="!APK!"
)
set "RUN_EXIT=%errorlevel%"

echo.
if not "%RUN_EXIT%"=="0" (
  echo Ошибка установки, код %RUN_EXIT%.
) else (
  echo Готово: приложение установлено.
)
if not exist "android\key.properties" (
  echo.
  echo Подсказка: без android\key.properties release подписан debug-ключом.
)

if "%NO_PAUSE%"=="1" exit /b %RUN_EXIT%
echo.
pause
exit /b %RUN_EXIT%
