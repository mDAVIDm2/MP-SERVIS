@echo off
setlocal
cd /d "%~dp0"

set "ARGS=--dart-define=MP_SERVIS_API_BASE_URL=https://api.mp-servis.ru/api/v1"
if exist "config\firebase_define.json" (
  set "ARGS=%ARGS% --dart-define-from-file=config/firebase_define.json"
)

echo flutter build apk --release %ARGS%
flutter build apk --release %ARGS%

echo.
echo APK: build\app\outputs\flutter-apk\app-release.apk
if not exist "android\key.properties" (
  echo.
  echo ВНИМАНИЕ: нет android\key.properties — APK подписан debug-ключом.
  echo Скопируйте android\key.properties.example в key.properties и создайте keystore.
)
if not exist "android\app\google-services.json" (
  echo.
  echo Подсказка: для FCM положите google-services.json в android\app\ ^(package ru.mpservis.business^).
)
endlocal
