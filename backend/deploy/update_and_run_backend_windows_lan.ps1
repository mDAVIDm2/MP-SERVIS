# MP-Servis: Windows LAN server -- start PostgreSQL, git pull, npm ci/build/migrations/prune, start API.
# Run on the API host from repo clone. PowerShell 5.1+. Admin rights may be required for Start-Service (PostgreSQL).
#
# Examples:
#   cd D:\path\to\MP\backend\deploy
#   .\update_and_run_backend_windows_lan.ps1
#
#   .\update_and_run_backend_windows_lan.ps1 -RepoRoot "D:\share\DA\MP"
#   .\update_and_run_backend_windows_lan.ps1 -PostgresServiceName "postgresql-x64-18"
#   .\update_and_run_backend_windows_lan.ps1 -HardReset
#   .\update_and_run_backend_windows_lan.ps1 -SkipPostgresStart -SkipGitPull
#
# Only stops LISTEN on API port from backend/.env (PORT, default 3001). Port 3000 is never touched.

param(
    [string] $RepoRoot = "",
    [string] $GitBranch = "master",
    [string] $PostgresServiceName = "",
    [switch] $SkipPostgresStart,
    [switch] $SkipGitPull,
    [switch] $HardReset,
    [switch] $SkipNpm,
    [switch] $SkipStartApi
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = $env:MP_LAN_REPO_ROOT
    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
    }
}

$backend = [System.IO.Path]::Combine($RepoRoot, "backend")
$envFile = [System.IO.Path]::Combine($backend, ".env")

if (-not (Test-Path -LiteralPath $RepoRoot)) { throw "RepoRoot not found: $RepoRoot" }
if (-not (Test-Path -LiteralPath $backend)) { throw "backend folder not found: $backend" }
if (-not (Test-Path -LiteralPath $envFile)) { throw "Missing .env: $envFile" }

function Read-BackendPortFromEnv {
    param([string] $Path)
    $port = 3001
    foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
        if ($line -match '^\s*PORT\s*=\s*(\d+)\s*$') {
            return [int]$Matches[1]
        }
    }
    return $port
}

function Stop-MpServisApiListener {
    param([int[]] $Ports)
    foreach ($p in $Ports) {
        Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue |
            ForEach-Object {
                try { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue } catch {}
            }
    }
    Start-Sleep -Milliseconds 500
}

function Start-PostgresLan {
    param(
        [string] $ExplicitName,
        [bool] $Skip
    )
    if ($Skip) {
        Write-Host "[1/5] PostgreSQL: skipped (-SkipPostgresStart)" -ForegroundColor Yellow
        return
    }
    $svc = $null
    if ($ExplicitName) {
        $svc = Get-Service -Name $ExplicitName -ErrorAction SilentlyContinue
        if (-not $svc) { throw "PostgreSQL service not found: $ExplicitName" }
    }
    if (-not $svc) {
        $svc = @(Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'postgresql*' } | Select-Object -First 1)[0]
    }
    if (-not $svc) {
        Write-Warning "No service matching name 'postgresql*'. Start PostgreSQL manually or pass -PostgresServiceName (e.g. postgresql-x64-18)."
        return
    }
    Write-Host "[1/5] PostgreSQL: $($svc.Name) ($($svc.DisplayName))" -ForegroundColor Cyan
    if ($svc.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Running) {
        try {
            Start-Service -Name $svc.Name
            Start-Sleep -Seconds 2
            $svc.Refresh()
        }
        catch {
            $err = $_.Exception.Message
            throw "Start-Service failed for $($svc.Name). Run as Administrator or start PostgreSQL manually. $err"
        }
    }
    Write-Host "        status: $($svc.Status)" -ForegroundColor Green
}

$apiPort = Read-BackendPortFromEnv -Path $envFile
$portsToFree = @($apiPort) | Sort-Object -Unique

Write-Host "=== MP-Servis LAN: repo=$RepoRoot branch=$GitBranch apiPort=$apiPort (only this listen port is stopped; other ports unchanged) ===" -ForegroundColor Cyan

Start-PostgresLan -ExplicitName $PostgresServiceName -Skip:$SkipPostgresStart

Write-Host "[2/5] Stopping listener(s) on API port(s) only: $($portsToFree -join ', ') ..." -ForegroundColor Cyan
Stop-MpServisApiListener -Ports $portsToFree

if (-not $SkipGitPull) {
    Write-Host "[3/5] Git: fetch + $GitBranch ..." -ForegroundColor Cyan
    Push-Location -LiteralPath $RepoRoot
    try {
        git fetch origin
        if ($LASTEXITCODE -ne 0) { throw "git fetch failed" }
        git checkout $GitBranch
        if ($LASTEXITCODE -ne 0) { throw "git checkout failed" }
        if ($HardReset) {
            Write-Host "        git reset --hard origin/$GitBranch" -ForegroundColor Yellow
            git reset --hard "origin/$GitBranch"
            if ($LASTEXITCODE -ne 0) { throw "git reset --hard failed" }
        }
        else {
            git pull origin $GitBranch
            if ($LASTEXITCODE -ne 0) { throw "git pull failed; try -HardReset after backing up local changes" }
        }
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Host "[3/5] Git: skipped (-SkipGitPull)" -ForegroundColor Yellow
}

if (-not $SkipNpm) {
    Write-Host "[4/5] npm ci / build / migrations / prune ..." -ForegroundColor Cyan
    Push-Location -LiteralPath $backend
    try {
        npm ci
        if ($LASTEXITCODE -ne 0) { throw "npm ci failed" }
        npm run build
        if ($LASTEXITCODE -ne 0) { throw "npm run build failed" }
        npm run migration:run:prod
        if ($LASTEXITCODE -ne 0) { throw "npm run migration:run:prod failed" }
        npm prune --omit=dev
        if ($LASTEXITCODE -ne 0) { throw "npm prune failed" }
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Host "[4/5] npm: skipped (-SkipNpm)" -ForegroundColor Yellow
}

if (-not $SkipStartApi) {
    Write-Host "[5/5] Starting API (NODE_ENV=production)..." -ForegroundColor Cyan
    $mainJs = [System.IO.Path]::Combine($backend, "dist", "src", "main.js")
    if (-not (Test-Path -LiteralPath $mainJs)) {
        throw "Missing build output: $mainJs (run without -SkipNpm)"
    }
    $env:NODE_ENV = "production"
    $node = (Get-Command node -ErrorAction Stop).Source
    Start-Process -FilePath $node -ArgumentList @("--env-file=.env", "dist/src/main.js") -WorkingDirectory $backend -WindowStyle Hidden
    Start-Sleep -Seconds 2
    try {
        $code = (Invoke-WebRequest -Uri "http://127.0.0.1:$apiPort/api/v1/reference/car-brands" -UseBasicParsing -TimeoutSec 20).StatusCode
        Write-Host "        HTTP $code http://127.0.0.1:$apiPort/api/v1/reference/car-brands" -ForegroundColor Green
    }
    catch {
        $w = $_.Exception.Message
        Write-Warning "HTTP check failed (API may still be starting): $w"
    }
}
else {
    Write-Host "[5/5] Start API: skipped (-SkipStartApi)" -ForegroundColor Yellow
}

Write-Host "=== Done ===" -ForegroundColor Green
