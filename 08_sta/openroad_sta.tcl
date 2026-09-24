# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/08_sta/openroad_sta.tcl
# Created     : 2026-09-07
# Description : APB project source, configuration, or documentation file.
# ===============================================================================

# OpenROAD/OpenSTA static timing analysis for APB_Protocol
# Usage:
#   openroad -exit 08_sta/openroad_sta.tcl
#
# Picks up the most-implemented stage database available (route > placement
# > floorplan), so this same script works as a quick post-placement sanity
# check early on and as the signoff check once routing exists. Prints a
# full timing report plus WNS/TNS summaries; capture it to a file with the
# Makefile targets. STA_CORNER selects tt (default), ss, or ff.

set script_dir [file dirname [file normalize [info script]]]
set project_root [file normalize [file join $script_dir ..]]
set synth_dir [file join $project_root "04_synthesis"]
set sdc [file join $synth_dir "constraints.sdc"]

if { [info exists ::env(PDK_ROOT)] } {
    set pdk_root $::env(PDK_ROOT)
} else {
    puts stderr "PDK_ROOT is not set. Example: \$env:PDK_ROOT = 'C:/Users/<you>/src/sky130A'"
    exit 1
}

if { [info exists ::env(STA_CORNER)] } {
    set sta_corner [string tolower $::env(STA_CORNER)]
} else {
    set sta_corner tt
}

switch -- $sta_corner {
    tt {
        set liberty_name "sky130_fd_sc_hd__tt_025C_1v80.lib"
    }
    ss {
        set liberty_name "sky130_fd_sc_hd__ss_100C_1v60.lib"
    }
    ff {
        set liberty_name "sky130_fd_sc_hd__ff_n40C_1v95.lib"
    }
    default {
        puts stderr "Unsupported STA_CORNER '$sta_corner'. Use tt, ss, or ff."
        exit 1
    }
}

set liberty [file join $pdk_root "sky130A" "libs.ref" "sky130_fd_sc_hd" "lib" $liberty_name]
if { ![file exists $liberty] } {
    set local_lib [file join $synth_dir "lib" $liberty_name]
    if { [file exists $local_lib] } {
        set liberty $local_lib
    }
}

foreach path [list $liberty $sdc] {
    if { ![file exists $path] } {
        puts stderr "Missing required file: $path"
        exit 1
    }
}

# Most-implemented stage wins: post-route is signoff-accurate, post-placement
# is a fast early sanity check, post-floorplan is a last resort.
set candidates [list \
    [file join $project_root "09_place_and_route" "route.odb"] \
    [file join $project_root "07_placement" "placement.odb"] \
    [file join $project_root "06_floorplanning" "floorplan.odb"] \
]

set db ""
foreach c $candidates {
    if { [file exists $c] } {
        set db $c
        break
    }
}

if { $db eq "" } {
    puts stderr "No stage database found. Run 06_floorplanning first (at minimum)."
    exit 1
}

puts "Loading design database: $db"
read_db $db
read_liberty $liberty
read_sdc $sdc

# Measure the implemented CTS network instead of continuing to report ideal
# clock delay after loading the routed database.
set_propagated_clock [all_clocks]
puts {Clock mode: propagated (set_propagated_clock [all_clocks])}
puts "Fanout mode: unconstrained measurement baseline (no timing repair applied)"

# Extracted parasitics beat estimated ones -- use them if routing produced a SPEF.
set spef [file join $project_root "09_place_and_route" "route.spef"]
if { [file exists $spef] } {
    puts "Using extracted parasitics: $spef"
    read_spef $spef
} else {
    puts "No post-route SPEF found -- estimating parasitics from placement."
    estimate_parasitics -placement
}

puts "\n==== STA corner: $sta_corner ($liberty_name) ===="
puts "==== Full timing report (setup + hold) ===="
report_checks -path_delay min_max -format full_clock_expanded -group_count 10

puts "\n==== Summary ===="
report_wns
report_tns
report_worst_slack -max
report_worst_slack -min

puts "\n==== Clock skew ===="
report_clock_skew

exit
