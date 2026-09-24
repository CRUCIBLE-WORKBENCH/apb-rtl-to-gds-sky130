# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/09_place_and_route/openroad_route.tcl
# Created     : 2026-09-07
# Description : APB project source, configuration, or documentation file.
# ===============================================================================

# OpenROAD global + detailed routing for APB_Protocol
# Usage:
#   openroad -exit 09_place_and_route/openroad_route.tcl
#
# Prereqs: 09_place_and_route/cts.odb exists.

set script_dir [file dirname [file normalize [info script]]]
set project_root [file normalize [file join $script_dir ..]]
set synth_dir [file join $project_root "04_synthesis"]
set sdc [file join $synth_dir "constraints.sdc"]
set cts_db [file join $script_dir "cts.odb"]

if { ![file exists $cts_db] } {
    puts stderr "Missing CTS database: $cts_db"
    puts stderr "Run 09_place_and_route/openroad_cts.tcl first."
    exit 1
}

if { [info exists ::env(PDK_ROOT)] } {
    set pdk_root $::env(PDK_ROOT)
} else {
    puts stderr "PDK_ROOT is not set. Example: \$env:PDK_ROOT = 'C:/Users/<you>/src/sky130A'"
    exit 1
}

set liberty_tt [file join $pdk_root "sky130A" "libs.ref" "sky130_fd_sc_hd" "lib" "sky130_fd_sc_hd__tt_025C_1v80.lib"]
set rcx_rules [file join $pdk_root "sky130A" "libs.tech" "openlane" "rcx_rules.info"]

foreach path [list $liberty_tt $sdc] {
    if { ![file exists $path] } {
        puts stderr "Missing required file: $path"
        exit 1
    }
}

puts "Loading CTS database: $cts_db"
read_db $cts_db
read_liberty $liberty_tt
read_sdc $sdc

# Global routing: congestion-driven route plan. met1-met5 for signal, keep
# the clock net on the upper, lower-resistance layers.
set_routing_layers -signal met1-met5 -clock met3-met5
global_route -guide_file [file join $script_dir "route.guide"]

# Detailed routing (TritonRoute, built into OpenROAD's detailed_route).
detailed_route \
  -output_drc [file join $script_dir "route_drc.rpt"] \
  -output_maze [file join $script_dir "route_maze.log"]

# Extracted parasitics for signoff STA -- 08_sta picks this up automatically.
# write_spef needs real RC extraction data first (define_process_corner +
# extract_parasitics), not just a bare write_spef call -- confirmed live,
# 2026-08-27 (bare write_spef silently no-ops with "no extraction data" and
# never creates the file). rcx_rules.info is OpenRCX's per-process
# extraction ruleset, distributed under libs.tech/openlane/ in this PDK.
if { [file exists $rcx_rules] } {
    define_process_corner -ext_model_index 0 $rcx_rules
    extract_parasitics -ext_model_file $rcx_rules
    write_spef [file join $script_dir "route.spef"]
} else {
    puts "WARNING: no RCX rules file at $rcx_rules -- skipping parasitic extraction."
    puts "  08_sta will fall back to placement-based estimated parasitics."
}

write_def [file join $script_dir "route.def"]
write_db [file join $script_dir "route.odb"]
write_verilog [file join $script_dir "route_output.v"]

puts "Routing complete. Output files:"
puts "  [file join $script_dir "route.def"]"
puts "  [file join $script_dir "route.odb"]"
puts "  [file join $script_dir "route.spef"]"
puts "  [file join $script_dir "route_output.v"]"
puts "  [file join $script_dir "route_drc.rpt"]"

exit
