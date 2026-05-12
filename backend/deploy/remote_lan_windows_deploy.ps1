# Runs ON the Windows API host (via ssh ... powershell -File).
# Args: backend dir, path to .tgz from push_backend_to_lan_windows.ps1
param(
    [Parameter(Mandatory = $true)]
    [string] $BackendDir,
    [Parameter(Mandatory = $true)]
    [string] $ArchivePath,
    [ValidateSet('None', 'Service', 'NodeBackground')]
    [string] $RestartMode = 'NodeBackground',
    [string] $ServiceName = ''
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $BackendDir)) { throw "BackendDir not found: $BackendDir" }
if (-not (Test-Path -LiteralPath $ArchivePath)) { throw "ArchivePath not found: $ArchivePath" }

function Read-BackendPort {
    param([string] $EnvPath)
    $port = 3001
    if (-not (Test-Path -LiteralPath $EnvPath)) { return $port }
    foreach ($line in Get-Content -LiteralPath $EnvPath -Encoding UTF8) {
        if ($line -match '^\s*PORT\s*=\s*(\d+)\s*$') {
            return [int]$Matches[1]
        }
    }
    return $port
}

function Stop-ListenPortProcesses {
    param([int] $Port)
    $lines = netstat -ano | Select-String ":$Port\s" | ForEach-Object { $_.Line }
    $pids = New-Object 'System.Collections.Generic.HashSet[int]'
    foreach ($line in $lines) {
        if ($line -match '\sLISTENING\s+(\d+)\s*$') {
            [void]$pids.Add([int]$Matches[1])
        }
    }
    foreach ($pid in $pids) {
        try {
            Stop-Process -Id $pid -Force -ErrorAction Stop
            Write-Host "[deploy] Stopped PID $pid (port $Port)"
        }
        catch {
            Write-Warning "[deploy] Could not stop PID ${pid}: $($_.Exception.Message)"
        }
    }
}

Push-Location -LiteralPath $BackendDir
try {
    Write-Host '[deploy] tar extract...' -ForegroundColor Cyan
    & tar -xzf $ArchivePath
    if ($LASTEXITCODE -ne 0) { throw "tar extract failed: $LASTEXITCODE" }

    Write-Host '[deploy] npm ci...' -ForegroundColor Cyan
    npm ci
    if ($LASTEXITCODE -ne 0) { throw "npm ci failed: $LASTEXITCODE" }

    Write-Host '[deploy] npm run build...' -ForegroundColor Cyan
    npm run build
    if ($LASTEXITCODE -ne 0) { throw "npm run build failed: $LASTEXITCODE" }

    Write-Host '[deploy] npm run migration:run:prod...' -ForegroundColor Cyan
    npm run migration:run:prod
    if ($LASTEXITCODE -ne 0) { throw "npm run migration:run:prod failed: $LASTEXITCODE" }

    Write-Host '[deploy] npm prune --omit=dev...' -ForegroundColor Cyan
    npm prune --omit=dev
    if ($LASTEXITCODE -ne 0) { throw "npm prune failed: $LASTEXITCODE" }
}
finally {
    Pop-Location
}

$envFile = Join-Path $BackendDir '.env'
$port = Read-BackendPort -EnvPath $envFile
$mainJs = Join-Path $BackendDir 'dist\src\main.js'
if (-not (Test-Path -LiteralPath $mainJs)) {
    throw "Missing $mainJs after build"
}

if ($RestartMode -eq 'Service') {
    if (-not $ServiceName) { throw "RestartMode=Service requires -ServiceName" }
    Write-Host "[deploy] Restart-Service $ServiceName" -ForegroundColor Cyan
    Restart-Service -Name $ServiceName -Force -ErrorAction Stop
}
elseif ($RestartMode -eq 'NodeBackground') {
    Write-Host "[deploy] Restart node on port $port (NodeBackground)" -ForegroundColor Cyan
    Stop-ListenPortProcesses -Port $port
    $env:NODE_ENV = 'production'
    $node = (Get-Command node -ErrorAction Stop).Source
    $arg = @('--env-file=.env', 'dist/src/main.js')
    Start-Process -FilePath $node -ArgumentList $arg -WorkingDirectory $BackendDir -WindowStyle Hidden
    Start-Sleep -Seconds 2
}
else {
    Write-Host '[deploy] RestartMode=None — start API manually on this host.' -ForegroundColor Yellow
}

try {
    $uri = "http://127.0.0.1:$port/api/v1/reference/car-brands"
    $code = (Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec 15).StatusCode
    Write-Host "[deploy] HTTP check $uri -> $code" -ForegroundColor Green
}
catch {
    Write-Warning "[deploy] HTTP check failed (API may still be starting): $($_.Exception.Message)"
}

Write-Host '[deploy] Done.' -ForegroundColor Green
