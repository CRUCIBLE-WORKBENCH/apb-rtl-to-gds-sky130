# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/06_floorplanning/openroad_floorplan.tcl
# Created     : 2026-09-07
# Description : APB project source, configuration, or documentation file.
# ===============================================================================

# OpenROAD floorplan script for APB_Protocol
# Usage:
#   openroad -exit 06_floorplanning/openroad_floorplan.tcl
#
# Prereqs:
#   - OpenROAD installed and on PATH
#   - PDK_ROOT set to the Sky130 install root, or update the paths below
#   - 04_synthesis/synth_output.v and 04_synthesis/constraints.sdc exist

set script_dir [file dirname [file normalize [info script]]]
set project_root [file normalize [file join $script_dir ..]]
set synth_dir [file join $project_root "04_synthesis"]
set netlist [file join $synth_dir "synth_output.v"]
set sdc [file join $synth_dir "constraints.sdc"]

if { ![file exists $netlist] } {
    puts stderr "Missing synthesized netlist: $netlist"
    exit 1
}

if { ![file exists $sdc] } {
    puts stderr "Missing SDC file: $sdc"
    exit 1
}

# User can either export PDK_ROOT or edit these paths.
if { [info exists ::env(PDK_ROOT)] } {
    set pdk_root $::env(PDK_ROOT)
} else {
    puts stderr "PDK_ROOT is not set. Example: \$env:PDK_ROOT = 'C:/Users/<you>/src/sky130A'"
    puts stderr "Update this script or export the variable before running OpenROAD."
    exit 1
}

set tech_lef_src [file join $pdk_root "sky130A" "libs.ref" "sky130_fd_sc_hd" "techlef" "sky130_fd_sc_hd.tlef"]
set stdcell_lef [file join $pdk_root "sky130A" "libs.ref" "sky130_fd_sc_hd" "lef" "sky130_fd_sc_hd.lef"]
set liberty_tt [file join $pdk_root "sky130A" "libs.ref" "sky130_fd_sc_hd" "lib" "sky130_fd_sc_hd__tt_025C_1v80.lib"]

foreach path [list $tech_lef_src $stdcell_lef $liberty_tt] {
    if { ![file exists $path] } {
        puts stderr "Missing PDK file: $path"
        exit 1
    }
}

# OpenROAD's read_lef derives OpenDB's internal library name from the LEF
# file's basename. The Sky130 tech LEF and the standard-cell LEF are both
# literally named sky130_fd_sc_hd.* -- reading them back to back under their
# real PDK filenames collides ("library already exists") and silently drops
# the standard-cell macros, breaking link_design later. Read the tech LEF
# from a locally renamed copy to dodge the collision; the PDK itself is
# never modified. (Confirmed live against this exact PDK install, 2026-08-27.)
set tech_lef [file join $script_dir "_sky130_tech.tlef"]
file copy -force $tech_lef_src $tech_lef

puts "Using PDK root: $pdk_root"
puts "Netlist: $netlist"
puts "SDC: $sdc"

# Read design and technology files
read_liberty $liberty_tt
read_lef $tech_lef
read_lef $stdcell_lef
read_verilog $netlist
link_design APB_Protocol

# Load timing constraints
read_sdc $sdc

# Initial die/core floorplan.
# Sized from a real global_placement run against this netlist: with cell
# padding applied, movable-instance area comes out to ~50,207 um^2 (vs.
# ~39,970 um^2 raw from synthesis -- padding/pin-density adjustment adds
# real overhead). A 250x250 die / 230x230 core (previous placeholder guess)
# gave only 43,362 um^2 of core area -> 115.8% utilization, which
# global_placement rejects outright (must be < 100%, and needs real margin
# below that to converge at all). 400x400 die / 380x380 core gives ~129,600
# um^2 of core area -> ~38.7% utilization at the actual movable area, well
# under the -density 0.60 target 07_placement/ asks for, with comfortable
# routing headroom for CTS/route later. Confirmed live, 2026-08-27.
initialize_floorplan \
  -site unithd \
  -die_area "0 0 400 400" \
  -core_area "20 20 380 380"

# Generate the routing-track grid from the tech LEF's layer pitch/offset --
# place_pins needs this to exist per-layer before it can lay out I/O pins;
# without it, place_pins fails with "Horizontal routing tracks not found"
# (confirmed live, 2026-08-27).
make_tracks

# Pin placement: allow OpenROAD to keep the pads on the periphery.
# This is a practical starting point for a small digital block.
# NOTE: flags are -hor_layers/-ver_layers (plural) in this OpenROAD build --
# the singular forms are silently ignored, and -random is obsolete (also
# silently ignored) -- both confirmed live, 2026-08-27.
place_pins -hor_layers met3 -ver_layers met2

# Well-tap / endcap insertion. Every standard cell's VPB (nwell/PMOS body
# tie) and VNB (pwell/NMOS body tie) pin needs a real physical path to
# VPWR/VGND -- normal cells don't provide that themselves, only dedicated
# tap cells placed periodically through each row do (foundry latch-up rule,
# universal to every real sky130 digital flow). Without this, LVS
# (11_physical_verification) extracts each cell's VPB/VNB as its own
# isolated node instead of one shared network -- confirmed live,
# 2026-09-08: this was the entire remaining LVS net-count gap after the PDN
# fix above (6544 "no matching net" + 637 direct VPB mismatches out of
# 7184 total LVS problem nets, ALL of them VPB/VNB -- zero real signal
# nets were ever affected). add_global_connection tells OpenROAD's power
# network that VPB/VNB belong to VPWR/VGND electrically; tapcell provides
# the physical silicon connection those pins need to actually reach them.
add_global_connection -net VPWR -pin_pattern "^VPB$" -power
add_global_connection -net VGND -pin_pattern "^VNB$" -ground

tapcell \
  -tapcell_master "sky130_fd_sc_hd__tapvpwrvgnd_1" \
  -endcap_master "sky130_fd_sc_hd__decap_4" \
  -distance 14

# Power distribution network. Without this, standard cells only get VPWR/
# VGND connectivity through row-to-row abutment (Sky130 cells share power
# rails with their neighbors automatically) -- nothing ties those local rail
# segments into one continuous, chip-wide VPWR net and one chip-wide VGND
# net. That's not just cosmetic: LVS (11_physical_verification) compares the
# extracted layout against the gate-level netlist, and a layout without a
# real PDN extracts as hundreds of disconnected power/ground islands with no
# counterpart on the netlist side (which has no power pins at all -- normal
# for a functional Verilog netlist) -- confirmed live, 2026-09-08, before
# this was added.
#
# The synthesized netlist has no VPWR/VGND nets at all (sky130 std-cell
# power pins are implicit, not present in the Verilog), so before PDN
# generation can reference those nets they have to be created and hooked
# up to every cell's power/ground pins -- PDN-1002 "Unable to find power
# net: VPWR" is what OpenROAD reports when this step is skipped (confirmed
# live, 2026-09-08).
add_global_connection -net VPWR -pin_pattern "^VPWR$" -power
add_global_connection -net VGND -pin_pattern "^VGND$" -ground

set_voltage_domain -name Core -power VPWR -ground VGND
define_pdn_grid -name Core -voltage_domains Core

# Standard-cell row rails on met1, tied to every cell's power pins via
# abutment ("followpins" -- one stripe definition, not one per row).
add_pdn_stripe -grid Core -layer met1 -width 0.48 -followpins

# Ring around the core on the two topmost routing layers, so every met4/met5
# strap below has something continuous to land on at the edges.
add_pdn_ring -grid Core -layers {met4 met5} -widths {1.6 1.6} -spacings {1.6 1.6} -core_offsets 2

# Vertical/horizontal straps distributing power into the core interior.
# Pitch chosen for this die size (380x380 um core) -- a handful of straps
# each direction, not a dense grid; this is a small block, not a full chip.
add_pdn_stripe -grid Core -layer met4 -width 1.6 -pitch 90 -offset 20 -extend_to_core_ring
add_pdn_stripe -grid Core -layer met5 -width 1.6 -pitch 90 -offset 20 -extend_to_core_ring

# Via stitching between the layers actually used above.
add_pdn_connect -grid Core -layers {met1 met4}
add_pdn_connect -grid Core -layers {met4 met5}

pdngen

# No check_placement here: the netlist's 1732 instances haven't been placed
# onto sites yet at this stage -- initialize_floorplan only creates rows/
# sites, it doesn't place standard cells. check_placement legality checking
# belongs after global_placement + detailed_placement (07_placement/), which
# already calls it; calling it here always fails ("Site aligned check
# failed") since every cell still sits at its unplaced default location
# (confirmed live, 2026-08-27).
write_def [file join $script_dir "floorplan.def"]
write_db [file join $script_dir "floorplan.odb"]

puts "Floorplan complete. Output files:"
puts "  [file join $script_dir "floorplan.def"]"
puts "  [file join $script_dir "floorplan.odb"]"

exit
