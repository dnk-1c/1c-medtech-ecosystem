# tools/get-v8unpack.ps1
# Download e8tools/v8unpack.exe (step 1 of .cfe unpack pipeline)
# NOTE: e8tools/v8unpack produces binary blocks only, not readable BSL/JSON.
# For full pipeline use tasks/unpack.os (method selected automatically).
#
# Usage: powershell -ExecutionPolicy Bypass -File tools/get-v8unpack.ps1
# Log:   tools/logs/get-v8unpack.log

$ToolsDir    = $PSScriptRoot
$ExePath     = Join-Path $ToolsDir "v8unpack.exe"
$ApiUrl      = "https://api.github.com/repos/e8tools/v8unpack/releases/latest"
$FallbackUrl = "https://github.com/e8tools/v8unpack/releases/download/v.3.0.43/v8unpack.exe"
$LogDir      = Join-Path $ToolsDir "logs"
$LogFile     = Join-Path $LogDir "get-v8unpack.log"

function Write-Log([string]$Level, [string]$Msg) {
    $Stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Line  = "[$Stamp] [$Level] $Msg"
    switch ($Level) {
        "OK"    { Write-Host "  OK: $Msg" -ForegroundColor Green }
        "ERROR" { Write-Host "  ERROR: $Msg" -ForegroundColor Red }
        default { Write-Host "  $Msg" -ForegroundColor Gray }
    }
    try {
        if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory $LogDir -Force | Out-Null }
        Add-Content -Path $LogFile -Value $Line -Encoding UTF8
    } catch { }
}

Write-Log "INFO" "=== get-v8unpack.ps1 started ==="

if (Test-Path $ExePath) {
    Write-Log "OK" "v8unpack.exe already exists: $ExePath"
    exit 0
}

Write-Log "INFO" "Downloading v8unpack.exe from GitHub..."

try {
    $headers = @{ "User-Agent" = "1c-extension-ecosystem" }
    $release = Invoke-RestMethod -Uri $ApiUrl -Headers $headers -TimeoutSec 15
    $asset   = $release.assets | Where-Object { $_.name -eq "v8unpack.exe" } | Select-Object -First 1
    $DownloadUrl = if ($asset) { $asset.browser_download_url } else { $FallbackUrl }
    Write-Log "INFO" "Version: $($release.tag_name)"
} catch {
    Write-Log "INFO" "GitHub API unavailable, using fallback v3.0.43"
    $DownloadUrl = $FallbackUrl
}

try {
    Write-Log "INFO" "URL: $DownloadUrl"
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ExePath -TimeoutSec 60
    $size = (Get-Item $ExePath).Length / 1KB
    Write-Log "OK" ("v8unpack.exe downloaded ({0:N0} KB) -> tools/" -f $size)
    Write-Log "INFO" "=== get-v8unpack.ps1 completed successfully ==="
} catch {
    Write-Log "ERROR" "Download failed: $_"
    Write-Log "ERROR" "Download manually: $FallbackUrl"
    Write-Log "ERROR" "Place to: $ExePath"
    Write-Log "ERROR" "=== get-v8unpack.ps1 FAILED ==="
    Write-Host "  See log: $LogFile" -ForegroundColor Yellow
    exit 1
}
