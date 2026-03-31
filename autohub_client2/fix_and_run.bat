@echo off
chcp 65001 >nul 2>&1
set "RUN_EXIT=0"

cd /d "%~dp0"
if errorlevel 1 (
  echo Ошибка: не удалось перейти в папку скрипта.
  set "RUN_EXIT=1"
  goto :final
)

echo Removing flutter ephemeral folders...
rmdir /s /q "windows\flutter\ephemeral" 2>nul
rmdir /s /q "linux\flutter\ephemeral" 2>nul
rmdir /s /q "macos\flutter\ephemeral" 2>nul
echo flutter clean...
call flutter clean
if errorlevel 1 (
  set "RUN_EXIT=%errorlevel%"
  goto :final
)
echo flutter pub get...
call flutter pub get
if errorlevel 1 (
  set "RUN_EXIT=%errorlevel%"
  echo Ошибка на этапе flutter pub get.
  goto :final
)
echo flutter run -d windows...
call flutter run -d windows
set "RUN_EXIT=%errorlevel%"

:final
echo.
if not "%RUN_EXIT%"=="0" (
  echo Завершено с ошибкой (код %RUN_EXIT%).
) else (
  echo Готово (код 0).
)
echo.
echo Нажмите любую клавишу, чтобы закрыть окно...
pause
exit /b %RUN_EXIT%
