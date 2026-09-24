# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/08_sta/run_sta.ps1
# Created     : 2026-09-07
# Description : APB project source, configuration, or documentation file.
# ===============================================================================

param(
    [ValidateSet("tt", "ss", "ff")]
    [string]$Corner = "tt"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path

if (-not $env:PDK_ROOT) {
    Write-Error "Set PDK_ROOT first, for example: `$env:PDK_ROOT = 'C:/path/to/sky130A'"
    exit 1
}

$scriptPath = Join-Path $scriptDir "openroad_sta.tcl"
$reportPath = Join-Path $scriptDir "timing_report_$Corner.txt"
$env:STA_CORNER = $Corner

Write-Host "Running OpenROAD/OpenSTA timing analysis for APB_Protocol ($Corner corner)"
Write-Host "Project root: $projectRoot"
Write-Host "PDK_ROOT: $env:PDK_ROOT"
Write-Host "Report will be saved to: $reportPath"

openroad -exit $scriptPath | Tee-Object -FilePath $reportPath
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
