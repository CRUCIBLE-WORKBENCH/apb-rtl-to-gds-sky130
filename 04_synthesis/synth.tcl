# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/04_synthesis/synth.tcl
# Created     : 2026-09-07
# Description : APB project source, configuration, or documentation file.
# ===============================================================================

# Yosys script for the APB2 Protocol design.
# Technology mapping targets the Sky130 HD standard-cell library, worst-case
# (slow-slow, 100C, 1.60V) corner -- the standard sign-off convention, since
# a netlist optimized for the slowest corner is guaranteed to meet timing
# at typical/best-case corners too.
#
# Available corner libs (04_synthesis/lib/):
#   sky130_fd_sc_hd__ss_100C_1v60.lib  <- used for synthesis/mapping below
#   sky130_fd_sc_hd__tt_025C_1v80.lib  <- used only for the area/stat report
#   sky130_fd_sc_hd__ff_n40C_1v95.lib  <- best-case, available for cross-checks
#
# Timing constraints: 04_synthesis/constraints.sdc (PCLK @ 10ns / 100MHz)
# Run from the repo root: yosys -s 04_synthesis/synth.tcl

read_verilog -I 01_rtl 01_rtl/apb_protocol.v
hierarchy -check -top APB_Protocol

proc
opt
fsm
opt
memory
opt

synth -top APB_Protocol

dfflibmap -liberty 04_synthesis/lib/sky130_fd_sc_hd__ss_100C_1v60.lib
abc -liberty 04_synthesis/lib/sky130_fd_sc_hd__ss_100C_1v60.lib -D 10000

clean

# Report area/cell breakdown against the typical corner for a representative view
stat -liberty 04_synthesis/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

write_verilog -noattr 04_synthesis/synth_output.v
