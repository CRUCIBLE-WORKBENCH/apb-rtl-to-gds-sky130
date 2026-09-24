# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/09_place_and_route/openroad_cts.tcl
# Created     : 2026-09-07
# Description : APB project source, configuration, or documentation file.
# ===============================================================================

# OpenROAD clock tree synthesis for APB_Protocol
# Usage:
#   openroad -exit 09_place_and_route/openroad_cts.tcl
#
# Prereqs: 07_placement/placement.odb exists.

set script_dir [file dirname [file normalize [info script]]]
set project_root [file normalize [file join $script_dir ..]]
set synth_dir [file join $project_root "04_synthesis"]
set sdc [file join $synth_dir "constraints.sdc"]
set placement_db [file join $project_root "07_placement" "placement.odb"]

if { ![file exists $placement_db] } {
    puts stderr "Missing placement database: $placement_db"
    puts stderr "Run 07_placement/openroad_placement.tcl first."
    exit 1
}

if { [info exists ::env(PDK_ROOT)] } {
    set pdk_root $::env(PDK_ROOT)
} else {
    puts stderr "PDK_ROOT is not set. Example: \$env:PDK_ROOT = 'C:/Users/<you>/src/sky130A'"
    exit 1
}

set liberty_tt [file join $pdk_root "sky130A" "libs.ref" "sky130_fd_sc_hd" "lib" "sky130_fd_sc_hd__tt_025C_1v80.lib"]

foreach path [list $liberty_tt $sdc] {
    if { ![file exists $path] } {
        puts stderr "Missing required file: $path"
        exit 1
    }
}

puts "Loading placement database: $placement_db"
read_db $placement_db
read_liberty $liberty_tt
read_sdc $sdc

set_propagated_clock [all_clocks]

# Sky130 HD clock buffers, used as the CTS buffer library. Sizes 4/8 give the
# tool enough range for this small a design without pulling in every buffer.
clock_tree_synthesis \
  -buf_list {sky130_fd_sc_hd__clkbuf_4 sky130_fd_sc_hd__clkbuf_8} \
  -sink_clustering_enable \
  -sink_clustering_size 20

# Re-legalize placement after CTS inserts buffers into the core area.
detailed_placement
check_placement -verbose

write_def [file join $script_dir "cts.def"]
write_db [file join $script_dir "cts.odb"]

puts "CTS complete. Output files:"
puts "  [file join $script_dir "cts.def"]"
puts "  [file join $script_dir "cts.odb"]"

exit
