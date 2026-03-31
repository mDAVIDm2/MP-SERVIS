# Downloads Firebase C++ SDK for Windows (firebase_core). ~912 MB once.
# If build fails: cmake -E tar: ZIP decompression failed (-5)
# Run: powershell -NoProfile -ExecutionPolicy Bypass -File tool\prep_firebase_cpp_windows.ps1

$ErrorActionPreference = 'Stop'
$version = '13.5.0'
$projRoot = Split-Path $PSScriptRoot -Parent
$root = Join-Path $projRoot 'build\windows\x64'
New-Item -ItemType Directory -Path $root -Force | Out-Null
$zip = Join-Path $root "firebase_cpp_sdk_windows_$version.zip"
$ext = Join-Path $root 'extracted'
$url = "https://dl.google.com/firebase/sdk/cpp/firebase_cpp_sdk_windows_$version.zip"
$marker = Join-Path $ext 'firebase_cpp_sdk_windows\CMakeLists.txt'

Write-Host "Target: $root"
if (Test-Path -LiteralPath $marker) {
  Write-Host 'SDK already present.'
  exit 0
}

Remove-Item -Recurse -Force $ext -ErrorAction SilentlyContinue

$zipOk = (Test-Path -LiteralPath $zip) -and ((Get-Item -LiteralPath $zip).Length -ge 800MB)
if (-not $zipOk) {
  Remove-Item -Force $zip -ErrorAction SilentlyContinue
  Write-Host 'Downloading ~912 MB (curl, may take many minutes)...'
  & curl.exe -fL --retry 5 --retry-delay 3 -o $zip $url
  if ($LASTEXITCODE -ne 0) { throw "curl exit $LASTEXITCODE" }
} else {
  Write-Host "Reusing existing zip ($( [math]::Round((Get-Item $zip).Length/1MB) ) MB)"
}

New-Item -ItemType Directory -Path $ext -Force | Out-Null
Write-Host "Extracting to $ext (tar.exe, not Expand-Archive)..."
& tar.exe -xf $zip -C $ext
if ($LASTEXITCODE -ne 0) { throw "tar extract failed, exit $LASTEXITCODE" }

if (-not (Test-Path -LiteralPath $marker)) {
  Get-ChildItem $ext -Recurse -Filter 'CMakeLists.txt' -ErrorAction SilentlyContinue | Select-Object -First 5 FullName
  throw "Missing $marker"
}
Write-Host "OK: $marker"
Write-Host 'Next: flutter run -d windows'
