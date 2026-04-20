@echo off
chcp 65001 >nul 2>&1
set "BUILD_EXIT=0"

cd /d "%~dp0"
if errorlevel 1 (
  echo Ошибка: не удалось перейти в папку скрипта.
  set "BUILD_EXIT=1"
  goto :final
)

echo Cleaning...
call flutter clean
if errorlevel 1 (
  set "BUILD_EXIT=%errorlevel%"
  echo flutter clean завершился с кодом %BUILD_EXIT%.
  goto :final
)

call flutter pub get
if errorlevel 1 (
  set "BUILD_EXIT=%errorlevel%"
  echo flutter pub get завершился с кодом %BUILD_EXIT%.
  goto :final
)

echo.
echo Building Windows (verbose). Log: build_log.txt
call flutter build windows -v > build_log.txt 2>&1
set "BUILD_EXIT=%errorlevel%"

echo.
echo Exit code: %BUILD_EXIT%
echo First/last lines of build_log.txt:
echo ---
powershell -NoProfile -Command "Get-Content build_log.txt -Head 80"
echo ...
powershell -NoProfile -Command "Get-Content build_log.txt -Tail 40"
echo ---
echo Full log: build_log.txt

:final
echo.
if not "%BUILD_EXIT%"=="0" (
  echo Сборка завершилась с ошибкой (код %BUILD_EXIT%).
) else (
  echo Готово (код 0).
)
echo.
echo Нажмите любую клавишу, чтобы закрыть окно...
pause
exit /b %BUILD_EXIT%