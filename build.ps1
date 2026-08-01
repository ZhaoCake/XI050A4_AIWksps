<#
.SYNOPSIS
    Colorlight i9+ v6.1 board project -- command-line workflow entry (no GUI)
.DESCRIPTION
    Wraps vivado -mode batch running scripts/build.tcl, tees output to
    build/logs/, and propagates the exit code (0=success, non-zero=failure)
    so scripts and AI tooling can judge the result reliably.

    All output is ASCII-only to avoid Windows GBK/UTF-8 console encoding issues.

.EXAMPLE
    .\build.ps1 init            # create project
    .\build.ps1 bitstream       # synth + impl + bitstream (daily driver)
    .\build.ps1 program         # download to FPGA over JTAG
    .\build.ps1 sim             # run RTL simulation
    .\build.ps1 help            # list all targets
#>
[CmdletBinding()]
param(
    [ValidateSet('init','synth','impl','bitstream','program','flash','sim','report','clean','help')]
    [string]$Target = 'help',
    [string]$VivadoBin = '',
    [switch]$NoLog
)

$ErrorActionPreference = 'Stop'

# ---- UTF-8 console + log encoding (harmless for ASCII output, keeps logs UTF-8) ----
$OutputEncoding = [System.Text.UTF8Encoding]::new()
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch { }

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

# ---- Locate vivado.bat: -VivadoBin > $env:VIVADO_BIN > default path ----
if (-not $VivadoBin) { $VivadoBin = $env:VIVADO_BIN }
if (-not $VivadoBin) { $VivadoBin = 'D:\Xilinx\Vivado\2023.2\bin' }
$vivado = Join-Path $VivadoBin 'vivado.bat'
if (-not (Test-Path $vivado)) {
    Write-Host "ERROR: vivado.bat not found: $vivado" -ForegroundColor Red
    Write-Host "       Pass -VivadoBin <path> (e.g. -VivadoBin D:\Xilinx\Vivado\2022.2\bin)" -ForegroundColor Yellow
    exit 2
}

# ---- Log file ----
$LogDir = Join-Path $Root 'build\logs'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$LogFile = Join-Path $LogDir ("{0}_{1:yyyyMMdd_HHmmss}.log" -f $Target, (Get-Date))

Write-Host "==> target: $Target"
Write-Host "==> vivado: $vivado"
Write-Host "==> log: $LogFile"

Push-Location $Root
try {
    if ($NoLog) {
        & $vivado -mode batch -notrace -nolog -nojournal -source scripts\build.tcl -tclargs $Target 2>&1
    } else {
        & $vivado -mode batch -notrace -nolog -nojournal -source scripts\build.tcl -tclargs $Target 2>&1 | Tee-Object -FilePath $LogFile
    }
    $code = $LASTEXITCODE
    if ($code -eq 0) {
        Write-Host "==> OK: $Target" -ForegroundColor Green
    } else {
        Write-Host "==> FAILED: $Target (exit=$code), see $LogFile" -ForegroundColor Red
    }
    exit $code
} finally {
    Pop-Location
}
