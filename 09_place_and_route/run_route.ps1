# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/09_place_and_route/run_route.ps1
# Created     : 2026-09-07
# Description : APB project source, configuration, or documentation file.
# ===============================================================================

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path

if (-not $env:PDK_ROOT) {
    Write-Error "Set PDK_ROOT first, for example: `$env:PDK_ROOT = 'C:/path/to/sky130A'"
    exit 1
}

$ctsDb = Join-Path $scriptDir "cts.odb"
if (-not (Test-Path $ctsDb)) {
    Write-Error "Missing $ctsDb -- run 09_place_and_route/run_cts.ps1 first."
    exit 1
}

Write-Host "Running OpenROAD global + detailed routing for APB_Protocol"
openroad -exit (Join-Path $scriptDir "openroad_route.tcl")
