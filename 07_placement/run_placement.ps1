# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/07_placement/run_placement.ps1
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

$floorplanDb = Join-Path $projectRoot "06_floorplanning\floorplan.odb"
if (-not (Test-Path $floorplanDb)) {
    Write-Error "Missing $floorplanDb -- run 06_floorplanning/run_floorplan.ps1 first."
    exit 1
}

$scriptPath = Join-Path $scriptDir "openroad_placement.tcl"

Write-Host "Running OpenROAD placement for APB_Protocol"
Write-Host "Project root: $projectRoot"
Write-Host "PDK_ROOT: $env:PDK_ROOT"

openroad -exit $scriptPath
