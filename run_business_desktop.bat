@echo off
chcp 65001 >nul 2>&1
set "RUN_EXIT=0"

echo ========================================
echo   AutoHub Business - запуск на desktop (Windows)
echo ========================================
echo.

cd /d "%~dp0autohub_business"
if errorlevel 1 (
  echo Ошибка: не удалось перейти в папку autohub_business.
  set "RUN_EXIT=1"
  goto :final
)
if not exist "pubspec.yaml" (
  echo Ошибка: нет pubspec.yaml в autohub_business.
  set "RUN_EXIT=1"
  goto :final
)

rem firebase_core на Windows требует Firebase C++ SDK (~912 МБ). Один раз скачивает prep-скрипт.
if not exist "build\windows\x64\extracted\firebase_cpp_sdk_windows\CMakeLists.txt" (
  echo.
  echo Первый запуск Windows: подготовка Firebase C++ SDK ^(около 912 МБ, curl^).
  echo При ошибке ZIP от CMake запустите вручную: tool\prep_firebase_cpp_windows.ps1
  echo.
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0autohub_business\tool\prep_firebase_cpp_windows.ps1"
  if errorlevel 1 (
    echo Ошибка подготовки Firebase SDK.
    set "RUN_EXIT=1"
    goto :final
  )
  echo.
)

call flutter run -d windows
set "RUN_EXIT=%errorlevel%"

:final
echo.
if not "%RUN_EXIT%"=="0" (
  echo Завершено с ошибкой (код %RUN_EXIT%).
) else (
  echo Сессия flutter run завершена (код 0).
)
echo.
echo Нажмите любую клавишу, чтобы закрыть окно...
pause
exit /b %RUN_EXIT%
