# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/00_lint/run_lint.ps1
# Created     : 2026-09-07
# Description : APB project source, configuration, or documentation file.
# ===============================================================================

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path
$rtlDir = Join-Path $projectRoot "01_rtl"
$reportPath = Join-Path $scriptDir "lint_report.txt"
$stdoutPath = Join-Path $scriptDir "lint_stdout.tmp"

# This install's `verilator` wrapper is a Perl script that fails under Git
# Bash's Perl (missing Pod::Usage) and, separately, has a hardcoded wrong
# include path baked in (looks for /yosyshq/share/verilator instead of this
# machine's real install location) -- confirmed live, 2026-08-28. Both are
# worked around here: call verilator_bin.exe directly, and set
# VERILATOR_ROOT explicitly so it finds its own built-in .vlt/.sv files.
if (-not $env:VERILATOR_ROOT) {
    $env:VERILATOR_ROOT = "C:/Users/ignyt/Downloads/oss-cad-suite/share/verilator"
}
if (-not (Test-Path (Join-Path $env:VERILATOR_ROOT "include\verilated_std_waiver.vlt"))) {
    Write-Error "VERILATOR_ROOT ($env:VERILATOR_ROOT) doesn't look right -- verilated_std_waiver.vlt not found under it. Set `$env:VERILATOR_ROOT to your own oss-cad-suite's share/verilator directory."
    exit 1
}

Write-Host "Linting 01_rtl/apb_protocol.v (+ included master.v/slave1.v/slave2.v)"

# Windows PowerShell 5.1 wraps a native command's stderr lines in
# ErrorRecord objects (extra "At ... / CategoryInfo / FullyQualifiedErrorId"
# noise) even with plain '2>' file redirection -- confirmed live,
# 2026-08-28. Verilator's lint output is entirely on stderr, so route
# around the problem with Start-Process's OS-level redirection instead,
# which bypasses PowerShell's stream handling entirely and gives a clean
# plain-text report.
$verilatorExe = (Get-Command verilator_bin.exe).Source
$proc = Start-Process -FilePath $verilatorExe `
    -ArgumentList @("--lint-only", "-Wall", "-I`"$rtlDir`"", "`"$(Join-Path $rtlDir 'apb_protocol.v')`"") `
    -NoNewWindow -Wait -PassThru `
    -RedirectStandardOutput $stdoutPath -RedirectStandardError $reportPath
$lintExit = $proc.ExitCode
Remove-Item $stdoutPath -ErrorAction SilentlyContinue

Get-Content $reportPath
Write-Host ""
Write-Host "Report saved to: $reportPath"
if ($lintExit -eq 0) {
    Write-Host "Lint: CLEAN (0 warnings)"
} else {
    Write-Host "Lint: warnings found -- see $reportPath. Non-blocking by design (see README); review it."
}
