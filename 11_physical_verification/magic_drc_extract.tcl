# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/11_physical_verification/magic_drc_extract.tcl
# Created     : 2026-09-07
# Description : Magic DRC and LVS extraction deck for the APB routed GDS.
# ===============================================================================

# This is intentionally Tcl. A Magic build with Tcl/Tk support can source it
# non-interactively; the current Igny-packaged Magic build may fail before this
# point if it was compiled without Tcl support.

set script_dir [file dirname [file normalize [info script]]]
set project_root [file dirname $script_dir]
set top APB_Protocol
set gds_path [file join $project_root 10_gds APB_Protocol.gds]
set results_dir [file join $script_dir results]
set drc_report [file join $results_dir magic_drc.rpt]
set layout_spice [file join $results_dir ${top}.layout.spice]

file mkdir $results_dir

gds read $gds_path
load $top
select top cell
expand

drc euclidean on
drc style drc(full)
drc check

set drc_count [drc list count total]
set fh [open $drc_report w]
puts $fh "Magic foundry DRC report for $top"
puts $fh "Total DRC errors: $drc_count"
puts $fh ""
puts $fh [drc listall why]
close $fh

extract do local
extract all
ext2spice lvs
ext2spice cthresh 0
ext2spice extresist off
ext2spice -o $layout_spice

quit -noprompt
