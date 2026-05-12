@echo off
setlocal
cd /d "%~dp0"

set "ARGS=--dart-define=MP_SERVIS_API_BASE_URL=https://api.mp-servis.ru/api/v1"
rem Partner OSAGO: copy config\partner_osago_define.json.example to partner_osago_define.json and set token.
if exist "config\partner_osago_define.json" (
  set "ARGS=%ARGS% --dart-define-from-file=config/partner_osago_define.json"
)
if exist "config\firebase_define.json" (
  set "ARGS=%ARGS% --dart-define-from-file=config/firebase_define.json"
)

echo flutter build apk --release %ARGS%
flutter build apk --release %ARGS%

echo.
echo APK: build\app\outputs\flutter-apk\app-release.apk
if not exist "android\key.properties" (
  echo.
  echo WARNING: no android\key.properties - APK signed with debug key.
  echo Copy android\key.properties.example to key.properties and create keystore.
)
if not exist "android\app\google-services.json" (
  echo.
  echo Hint: for FCM place google-services.json in android\app\ ^(package ru.mpservis.client^).
)
endlocal
