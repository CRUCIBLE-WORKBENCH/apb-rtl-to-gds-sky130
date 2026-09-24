#!/usr/bin/env bash
# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/11_physical_verification/run_physical_verification.sh
# Created     : 2026-09-07
# Description : Igny-driven DRC/LVS orchestration for the routed APB layout.
# ===============================================================================

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
results_dir="$script_dir/results"
mkdir -p "$results_dir"

top="APB_Protocol"
route_drc="$project_root/09_place_and_route/route_drc.rpt"
route_verilog="$project_root/09_place_and_route/route_output.v"
route_verilog_nodecap="$results_dir/route_output.nodecap.v"
gds="$project_root/10_gds/APB_Protocol.gds"
layout_spice="$results_dir/${top}.layout.spice"
layout_spice_nopwr="$results_dir/${top}.layout.nopwr.spice"
strip_power_pins="$script_dir/scripts/strip_power_pins.py"
magic_cmds="$results_dir/magic_drc_extract.commands"
drc_log="$results_dir/magic_drc_extract.log"
lvs_log="$results_dir/netgen_lvs.log"
netgen_probe_log="$results_dir/netgen_probe.log"
summary="$results_dir/physical_verification_status.txt"

find_pdk_root() {
    if [ -n "${PDK_ROOT:-}" ] && [ -d "$PDK_ROOT/sky130A" ]; then
        printf '%s\n' "$PDK_ROOT"
        return 0
    fi

    local candidate
    candidate="$(find "$HOME/.ciel" -path "*/sky130A/libs.tech/netgen/sky130A_setup.tcl" -print -quit 2>/dev/null || true)"
    if [ -n "$candidate" ]; then
        dirname "$(dirname "$(dirname "$(dirname "$candidate")")")"
        return 0
    fi

    return 1
}

require_file() {
    if [ ! -f "$1" ]; then
        echo "Missing required file: $1" >&2
        exit 1
    fi
}

run_netgen_lvs() {
    local pdk_root="$1"
    local setup="$pdk_root/sky130A/libs.tech/netgen/sky130A_setup.tcl"

    require_file "$layout_spice"
    require_file "$route_verilog"
    require_file "$setup"
    require_file "$strip_power_pins"

    # route_output.v carries ~262 disconnected "sky130_fd_sc_hd__decap_4
    # inst_name ();" instantiations -- physical-only row-endcap
    # placeholders (endcap_master in 06_floorplanning/openroad_floorplan.tcl)
    # that leaked into the write_verilog output despite having no signal
    # connectivity at all. Netgen silently coalesces these ~262 identical,
    # disconnected instances into a single reported "decap_4: 1" in its
    # device-count summary, which is why that count looked inconsistent
    # across runs before this was understood. The layout side already has
    # zero decap_4 instances left (they're zero-pin after
    # strip_power_pins.py removes VPWR/VGND, and get dropped outright --
    # see remove_zero_pin_cells there), so strip them here too for a
    # device count that's actually comparing the same thing on both sides.
    # Confirmed live, 2026-09-08.
    grep -v "sky130_fd_sc_hd__decap_4" "$route_verilog" > "$route_verilog_nodecap"

    # route_output.v (gate-level golden reference) never declares power or
    # body-tie pins (VPWR/VGND/VPB/VNB) -- structural Verilog doesn't model
    # them. Left in, every one of Magic's ~1850 per-instance power/body
    # pins comes out as an isolated node (or, for VPWR/VGND on the netlist
    # side, a fresh "dummy/proxyVPWR" placeholder per instance) with
    # nothing real to match -- confirmed live, 2026-09-08 via netgen's
    # -json badnets report: this was the entire remaining LVS mismatch
    # once real signal routing and the PDN were fixed, for VPB/VNB first
    # and then, once those were stripped, for VPWR/VGND underneath them.
    # Stripping all four from the layout side makes both circuits' pin
    # lists structurally match instead of relying on net-by-net
    # global-merge heuristics.
    python3 "$strip_power_pins" "$layout_spice" "$layout_spice_nopwr"

    echo "Running Netgen LVS through Igny..."
    # sky130A_setup.tcl has a dedicated "ignore class" block for fill and
    # tapvpwrvgnd cells (physical-only, never present in a gate-level
    # Verilog netlist) -- but it's gated behind this exact env var name,
    # off by default. Without it, tap cells (needed for real VPB/VNB
    # substrate connectivity, see 06_floorplanning/openroad_floorplan.tcl)
    # get compared as if they were real logic devices and both device and
    # net counts mismatch. Confirmed live, 2026-09-08.
    export MAGIC_EXT_USE_GDS=1
    igny run netgen lvs \
        "$layout_spice_nopwr $top" \
        "$route_verilog_nodecap $top" \
        "$setup" \
        "$lvs_log"
}

{
    echo "APB physical verification status"
    echo "Timestamp UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Project root: $project_root"
    echo ""
} > "$summary"
exit_code=0

require_file "$route_verilog"
require_file "$gds"

echo "Checking OpenROAD route DRC report..."
if [ -f "$route_drc" ]; then
    cp "$route_drc" "$results_dir/openroad_route_drc.rpt"
    if [ -s "$route_drc" ]; then
        {
            echo "OpenROAD route DRC report: copied to results/openroad_route_drc.rpt"
            echo "OpenROAD route DRC bytes: $(wc -c < "$route_drc")"
        } >> "$summary"
    else
        {
            echo "OpenROAD route DRC report: present and empty"
            echo "Interpretation: TritonRoute emitted no route-DRC entries."
        } >> "$summary"
    fi
else
    echo "OpenROAD route DRC report: missing" >> "$summary"
fi
echo "" >> "$summary"

pdk_root="$(find_pdk_root)" || {
    echo "Could not locate PDK_ROOT containing sky130A." | tee -a "$summary" >&2
    exit 1
}

magic_rc="$pdk_root/sky130A/libs.tech/magic/sky130A.magicrc"
magic_tech="$pdk_root/sky130A/libs.tech/magic/sky130A.tech"
netgen_setup="$pdk_root/sky130A/libs.tech/netgen/sky130A_setup.tcl"
require_file "$magic_rc"
require_file "$magic_tech"
require_file "$netgen_setup"

export PDK_ROOT="$pdk_root"
export CAD_ROOT="${CAD_ROOT:-$HOME/Crucible/tools/magic/8.3.682/magic/lib}"

echo "PDK_ROOT: $PDK_ROOT" >> "$summary"
echo "Netgen setup: $netgen_setup" >> "$summary"
echo "Magic techfile: $magic_tech" >> "$summary"
echo "" >> "$summary"

echo "Probing Netgen through Igny..."
if igny run netgen source "$script_dir/netgen_probe.tcl" > "$netgen_probe_log" 2>&1 && grep -q "Netgen probe: OK" "$netgen_probe_log"; then
    {
        echo "Netgen Igny probe: PASS"
        echo "Netgen probe log: results/netgen_probe.log"
    } >> "$summary"
else
    {
        echo "Netgen Igny probe: FAIL"
        echo "Netgen probe log: results/netgen_probe.log"
    } >> "$summary"
fi
echo "" >> "$summary"

echo "Attempting Magic foundry DRC and layout extraction through Igny..."
rm -f "$layout_spice" "$drc_log"
find "$project_root" -maxdepth 1 -name "*.ext" -type f -delete
# NOTE: no ":ext2spice cthresh 0" here on purpose. That sets the coupling-cap
# threshold to 0fF, which is correct for a post-layout parasitic SPICE deck
# (timing/power sims) but wrong for LVS: it dumped ~78k tiny coupling
# capacitors into the layout-side netlist that have no counterpart in the
# gate-level netlist, so every LVS run failed on device/net count mismatch
# even though every real standard-cell instance count already matched.
# ":ext2spice lvs" alone already sets LVS-appropriate defaults; don't
# override cthresh back down after it.
cat > "$magic_cmds" <<MAGIC_CMDS
:tech load $magic_tech
:gds read $gds
:load $top
:select top cell
:expand
:drc check
:drc count total
:extract do local
:extract all
:ext2spice lvs
:ext2spice extresist off
:ext2spice -o $layout_spice $top
:quit -noprompt
MAGIC_CMDS

if igny run magic -dnull -noconsole < "$magic_cmds" > "$drc_log" 2>&1; then
    echo "Magic DRC/extraction command exited successfully." >> "$summary"
else
    {
        echo "Magic DRC/extraction command failed."
        echo "Log: results/magic_drc_extract.log"
    } >> "$summary"
fi
find "$project_root" -maxdepth 1 -name "*.ext" -type f -exec mv -f {} "$results_dir" \;

if [ -f "$layout_spice" ]; then
    echo "Layout SPICE extracted: $layout_spice" >> "$summary"
    if grep -q "Total DRC errors found: 0" "$drc_log"; then
        echo "Magic foundry DRC: PASS (0 errors)" >> "$summary"
    else
        echo "Magic foundry DRC: see results/magic_drc_extract.log" >> "$summary"
        exit_code=2
    fi

    rm -f "$lvs_log"
    if run_netgen_lvs "$pdk_root" >> "$summary" 2>&1; then
        :
    fi
    echo "Netgen LVS log: results/netgen_lvs.log" >> "$summary"
    if grep -q "Netlists match uniquely" "$lvs_log"; then
        echo "Netgen LVS: PASS" >> "$summary"
    elif grep -q "Netlists do not match" "$lvs_log"; then
        echo "Netgen LVS: FAIL (netlists do not match)" >> "$summary"
        exit_code=3
    else
        echo "Netgen LVS: UNKNOWN (inspect log)" >> "$summary"
        exit_code=4
    fi
else
    {
        echo "Layout SPICE extracted: no"
        echo "Netgen LVS: not run because Magic did not produce ${top}.layout.spice"
        echo "Netgen command prepared:"
        echo "  igny run netgen lvs \"$layout_spice $top\" \"$route_verilog $top\" \"$netgen_setup\" \"$lvs_log\""
    } >> "$summary"
    exit_code=2
fi

echo ""
cat "$summary"
exit "$exit_code"
