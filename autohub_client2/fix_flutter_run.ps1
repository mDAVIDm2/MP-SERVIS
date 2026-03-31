# Fix Flutter symlink errors (PathExistsException .plugin_symlinks) on Windows/Linux/macOS
# Run in PowerShell from project folder: .\fix_flutter_run.ps1
# If scripts are disabled: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

$root = $PSScriptRoot
@("windows\flutter\ephemeral", "linux\flutter\ephemeral", "macos\flutter\ephemeral") | ForEach-Object {
    $path = Join-Path $root $_
    if (Test-Path $path) { Remove-Item $path -Recurse -Force; Write-Host "Removed $_" }
}
Write-Host "Running: flutter clean"
flutter clean
Write-Host "Running: flutter pub get"
flutter pub get
Write-Host "Running: flutter run -d windows"
flutter run -d windows
