# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/07_placement/openroad_placement.tcl
# Created     : 2026-09-07
# Description : APB project source, configuration, or documentation file.
# ===============================================================================

# OpenROAD global + detailed placement for APB_Protocol
# Usage:
#   openroad -exit 07_placement/openroad_placement.tcl
#
# Prereqs:
#   - 06_floorplanning/floorplan.odb exists (run 06_floorplanning first)
#   - PDK_ROOT set to the Sky130 install root (needed again here because
#     Liberty/SDC constraints are not preserved by write_db/read_db --
#     only the physical LEF-derived database is)

set script_dir [file dirname [file normalize [info script]]]
set project_root [file normalize [file join $script_dir ..]]
set synth_dir [file join $project_root "04_synthesis"]
set sdc [file join $synth_dir "constraints.sdc"]
set floorplan_db [file join $project_root "06_floorplanning" "floorplan.odb"]

if { ![file exists $floorplan_db] } {
    puts stderr "Missing floorplan database: $floorplan_db"
    puts stderr "Run 06_floorplanning/openroad_floorplan.tcl first."
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

puts "Loading floorplan database: $floorplan_db"
read_db $floorplan_db

# Liberty and SDC constraints live in OpenSTA's own object model, not in the
# .odb -- must be re-read in every downstream stage that needs timing.
read_liberty $liberty_tt
read_sdc $sdc

# Global placement: spread cells to minimize wirelength/congestion while
# respecting the core area and any fixed pins from the floorplan stage.
# density 0.60 leaves headroom for CTS buffer insertion later.
global_placement -density 0.60 -pad_left 2 -pad_right 2

# Detailed placement: legalize cells onto the site grid after global placement.
set_placement_padding -global -left 1 -right 1
detailed_placement

# Sanity check: confirms every instance is legally placed (no overlaps, on-grid).
check_placement -verbose

write_def [file join $script_dir "placement.def"]
write_db [file join $script_dir "placement.odb"]

puts "Placement complete. Output files:"
puts "  [file join $script_dir "placement.def"]"
puts "  [file join $script_dir "placement.odb"]"

exit
