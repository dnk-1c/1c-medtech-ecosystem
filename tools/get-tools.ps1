# tools/get-tools.ps1
# Auto-install portable PM tools into tools/ (no admin rights required)
#
# Pinned versions (tested with 1C Extension Ecosystem v1.0):
#   Python      3.12.10
#   OneScript   2.0.1
#   BSL LS      0.29.0
#   Temurin JRE 21.0.11+10 (LTS)
#   saby v8unpack 1.2.6  (installed via pip)
#   mcp-server-git latest (installed via pip)
#
# Usage (from project folder):
#   powershell -ExecutionPolicy Bypass -File tools/get-tools.ps1
#   powershell -ExecutionPolicy Bypass -File tools/get-tools.ps1 -Tool python
#
# Tools: python | oscript | bsl-ls | all
# Log:   tools/logs/get-tools.log

param(
    [string]$Tool = "all"
)

$ErrorActionPreference = "Stop"
$ToolsDir = $PSScriptRoot
$Headers  = @{ "User-Agent" = "1c-extension-ecosystem/get-tools" }
$LogDir   = Join-Path $ToolsDir "logs"
$LogFile  = Join-Path $LogDir "get-tools.log"

# -- Pinned versions --------------------------------------------------
$V_PYTHON   = "3.12.10"
$V_OSCRIPT  = "2.0.1"
$V_BSLLS    = "0.29.0"
$V_JRE      = "21.0.11+10"
$V_V8UNPACK = "3.0.43"

# -- Pinned download URLs ---------------------------------------------
$URL_PYTHON  = "https://www.python.org/ftp/python/$V_PYTHON/python-$V_PYTHON-embed-amd64.zip"
$URL_OSCRIPT = "https://github.com/EvilBeaver/OneScript/releases/download/v$V_OSCRIPT/OneScript-$V_OSCRIPT-win-x64.zip"
$URL_BSLLS   = "https://github.com/1c-syntax/bsl-language-server/releases/download/v$V_BSLLS/bsl-language-server-$V_BSLLS-exec.jar"
$URL_JRE     = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.11%2B10/OpenJDK21U-jre_x64_windows_hotspot_21.0.11_10.zip"
$URL_V8UNPACK= "https://github.com/e8tools/v8unpack/releases/download/v.$V_V8UNPACK/v8unpack.exe"

# -- Logging ----------------------------------------------------------

function Write-Log([string]$Level, [string]$Msg) {
    $Stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Line  = "[$Stamp] [$Level] $Msg"
    switch ($Level) {
        "INFO"  { Write-Host "  $Msg" -ForegroundColor Gray }
        "OK"    { Write-Host "  OK: $Msg" -ForegroundColor Green }
        "SKIP"  { Write-Host "  SKIP: $Msg (already installed)" -ForegroundColor Gray }
        "STEP"  { Write-Host ""; Write-Host "> $Msg" -ForegroundColor Cyan }
        "ERROR" { Write-Host "  ERROR: $Msg" -ForegroundColor Red }
    }
    try {
        if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory $LogDir -Force | Out-Null }
        Add-Content -Path $LogFile -Value $Line -Encoding UTF8
    } catch { }
}

function Write-Step([string]$Msg)  { Write-Log "STEP"  $Msg }
function Write-OK([string]$Msg)    { Write-Log "OK"    $Msg }
function Write-Skip([string]$Msg)  { Write-Log "SKIP"  $Msg }
function Write-LogError([string]$Msg) { Write-Log "ERROR" $Msg }

function Download-File([string]$Url, [string]$OutPath) {
    Write-Log "INFO" "Downloading: $Url"
    try {
        Invoke-WebRequest -Uri $Url -OutFile $OutPath -Headers $Headers -TimeoutSec 120
    } catch {
        Write-LogError "Download failed: $Url - $_"
        throw
    }
}

function Expand-ZipTo([string]$ZipPath, [string]$Dest) {
    if (Test-Path $Dest) { Remove-Item $Dest -Recurse -Force }
    Expand-Archive -Path $ZipPath -DestinationPath $Dest -Force
}

# ==================================================================
# TOOL 1: Python 3.12 embeddable
# ==================================================================
function Install-Python {
    Write-Step "Python $V_PYTHON embeddable"

    $PythonDir = Join-Path $ToolsDir "python"
    $PythonExe = Join-Path $PythonDir "python.exe"
    $PipExe    = Join-Path $PythonDir "Scripts\pip.exe"

    if (-not (Test-Path $PythonExe)) {
        $ZipPath = Join-Path $env:TEMP "python-embed.zip"
        Download-File $URL_PYTHON $ZipPath
        Expand-ZipTo $ZipPath $PythonDir
        Remove-Item $ZipPath -Force

        # Enable pip: uncomment 'import site' in ._pth file
        $PthFile = Get-ChildItem $PythonDir -Filter "python*._pth" | Select-Object -First 1
        if ($PthFile) {
            $Lines = Get-Content $PthFile.FullName
            $Lines = $Lines | ForEach-Object { $_ -replace "^#import site", "import site" }
            Set-Content -Path $PthFile.FullName -Value $Lines
        }

        Write-Log "INFO" "Installing pip..."
        $GetPipPath = Join-Path $env:TEMP "get-pip.py"
        Download-File "https://bootstrap.pypa.io/get-pip.py" $GetPipPath
        & $PythonExe $GetPipPath --no-warn-script-location --quiet
        Remove-Item $GetPipPath -Force

        Write-OK "Python $V_PYTHON -> tools/python/"
    } else {
        Write-Skip "tools/python/python.exe"
    }

    # Verify pip
    $PipTest = & $PythonExe -m pip --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-LogError "pip not working: $PipTest"
        return
    }

    # saby v8unpack - full .cfe pipeline in one step
    $V8Pkg = Join-Path $PythonDir "Lib\site-packages\v8unpack"
    if (Test-Path $V8Pkg) {
        Write-Skip "saby v8unpack"
    } else {
        Write-Log "INFO" "Installing saby v8unpack..."
        & $PythonExe -m pip install v8unpack --no-warn-script-location --quiet
        if ($LASTEXITCODE -eq 0) { Write-OK "saby v8unpack installed" }
        else { Write-LogError "saby v8unpack install failed" }
    }

    # anthropic SDK
    $AntPkg = Join-Path $PythonDir "Lib\site-packages\anthropic"
    if (Test-Path $AntPkg) {
        Write-Skip "anthropic SDK"
    } else {
        Write-Log "INFO" "Installing anthropic SDK..."
        & $PythonExe -m pip install anthropic --no-warn-script-location --quiet
        if ($LASTEXITCODE -eq 0) { Write-OK "anthropic SDK installed" }
        else { Write-LogError "anthropic SDK install failed" }
    }

    # mcp-server-git
    $McpPkg = Join-Path $PythonDir "Lib\site-packages\mcp_server_git"
    if (Test-Path $McpPkg) {
        Write-Skip "mcp-server-git"
    } else {
        Write-Log "INFO" "Installing mcp-server-git..."
        & $PythonExe -m pip install mcp-server-git --no-warn-script-location --quiet
        if ($LASTEXITCODE -eq 0) { Write-OK "mcp-server-git installed" }
        else { Write-LogError "mcp-server-git install failed" }
    }
}

# ==================================================================
# TOOL 2: OneScript 2.0.1 portable
# ==================================================================
function Install-OScript {
    Write-Step "OneScript $V_OSCRIPT portable"

    $OScriptDir = Join-Path $ToolsDir "oscript"
    $OScriptExe = Join-Path $OScriptDir "oscript.exe"
    if (Test-Path $OScriptExe) { Write-Skip "tools/oscript/oscript.exe"; return }

    try {
        $ZipPath = Join-Path $env:TEMP "oscript.zip"
        Download-File $URL_OSCRIPT $ZipPath
        Expand-ZipTo $ZipPath $OScriptDir
        Remove-Item $ZipPath -Force

        # Flatten subfolder if needed
        $SubDir = Get-ChildItem $OScriptDir -Directory | Select-Object -First 1
        if ($SubDir -and (Test-Path (Join-Path $SubDir.FullName "oscript.exe"))) {
            Get-ChildItem $SubDir.FullName | Move-Item -Destination $OScriptDir -Force
            Remove-Item $SubDir.FullName -Recurse -Force
        }
        Write-OK "OneScript $V_OSCRIPT -> tools/oscript/"
    } catch {
        Write-LogError "OneScript download error: $_"
        Write-Log "INFO" "Download manually: https://github.com/EvilBeaver/OneScript/releases/tag/v$V_OSCRIPT"
    }
}

# ==================================================================
# TOOL 3: BSL Language Server + Temurin JRE 21
# ==================================================================
function Install-BslLs {
    Write-Step "BSL Language Server $V_BSLLS + Temurin JRE $V_JRE"

    $BslJar  = Join-Path $ToolsDir "bsl-ls.jar"
    $JreDir  = Join-Path $ToolsDir "jre"
    $JavaExe = Join-Path $JreDir "bin\java.exe"

    if (Test-Path $BslJar) {
        Write-Skip "tools/bsl-ls.jar"
    } else {
        try {
            Download-File $URL_BSLLS $BslJar
            Write-OK "bsl-ls.jar $V_BSLLS -> tools/"
        } catch {
            Write-LogError "BSL LS download error: $_"
        }
    }

    if (Test-Path $JavaExe) {
        Write-Skip "tools/jre/bin/java.exe"
    } else {
        try {
            Write-Log "INFO" "Downloading Temurin JRE $V_JRE..."
            $ZipPath = Join-Path $env:TEMP "temurin-jre.zip"
            Download-File $URL_JRE $ZipPath
            if (-not (Test-Path $JreDir)) { New-Item -ItemType Directory $JreDir | Out-Null }
            Expand-Archive -Path $ZipPath -DestinationPath $JreDir -Force
            Remove-Item $ZipPath -Force
            # Flatten subfolder
            $SubDir = Get-ChildItem $JreDir -Directory | Select-Object -First 1
            if ($SubDir -and (Test-Path (Join-Path $SubDir.FullName "bin\java.exe"))) {
                Get-ChildItem $SubDir.FullName | Move-Item -Destination $JreDir -Force
                Remove-Item $SubDir.FullName -Recurse -Force
            }
            Write-OK "Temurin JRE $V_JRE -> tools/jre/"
        } catch {
            Write-LogError "JRE download error: $_"
            Write-Log "INFO" "Download manually: https://adoptium.net/temurin/releases/?version=21"
        }
    }
}

# ==================================================================
# SUMMARY
# ==================================================================
function Show-Summary {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor DarkGray
    Write-Host "  Tools status"                             -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor DarkGray

    $Checks = @(
        @{ Name = "Python 3.12";    Path = "python\python.exe"                       },
        @{ Name = "pip";            Path = "python\Scripts\pip.exe"                 },
        @{ Name = "saby v8unpack";  Path = "python\Lib\site-packages\v8unpack"     },
        @{ Name = "anthropic SDK";  Path = "python\Lib\site-packages\anthropic"    },
        @{ Name = "mcp-server-git"; Path = "python\Lib\site-packages\mcp_server_git" },
        @{ Name = "oscript.exe";    Path = "oscript\oscript.exe"                     },
        @{ Name = "bsl-ls.jar";     Path = "bsl-ls.jar"                               },
        @{ Name = "Temurin JRE 21"; Path = "jre\bin\java.exe"                       }
    )

    foreach ($c in $Checks) {
        $FullPath = Join-Path $ToolsDir $c.Path
        if (Test-Path $FullPath) {
            Write-Host ("  [OK  ] {0,-22} tools\{1}" -f $c.Name, $c.Path) -ForegroundColor Green
        } else {
            Write-Host ("  [MISS] {0,-22} tools\{1}" -f $c.Name, $c.Path) -ForegroundColor Red
        }
    }
    Write-Host ""
}

# ==================================================================
# ENTRY POINT
# ==================================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  1C Extension Ecosystem - get-tools.ps1"   -ForegroundColor Cyan
Write-Host "  Pinned: OS=$V_OSCRIPT  Py=$V_PYTHON  JRE=$V_JRE" -ForegroundColor DarkCyan
Write-Host "============================================" -ForegroundColor Cyan

Write-Log "INFO" "=== get-tools.ps1 started (Tool: $Tool) ==="

try {
    switch ($Tool.ToLower()) {
        "python"   { Install-Python  }
        "oscript"  { Install-OScript }
        "bsl-ls"   { Install-BslLs   }
        "all" {
            Install-Python
            Install-OScript
            Install-BslLs
        }
        default {
            Write-Host "Unknown tool: $Tool" -ForegroundColor Red
            Write-Host "Available: all | python | oscript | bsl-ls"
            Write-LogError "Unknown tool: $Tool"
            exit 1
        }
    }
    Write-Log "INFO" "=== get-tools.ps1 completed successfully ==="
} catch {
    Write-LogError "=== get-tools.ps1 FAILED: $_ ==="
    Write-Host ""
    Write-Host "  See log: $LogFile" -ForegroundColor Yellow
    throw
}

Show-Summary
Write-Log "INFO" "Log: $LogFile"
