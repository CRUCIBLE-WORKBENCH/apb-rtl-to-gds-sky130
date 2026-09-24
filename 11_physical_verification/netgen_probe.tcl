# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/11_physical_verification/netgen_probe.tcl
# Created     : 2026-09-07
# Description : Netgen availability probe for the APB LVS lane.
# ===============================================================================

puts "Netgen probe: OK"
puts "Tcl patchlevel: [info patchlevel]"
puts "LVS command available: [expr {[llength [info commands lvs]] > 0}]"
exit
