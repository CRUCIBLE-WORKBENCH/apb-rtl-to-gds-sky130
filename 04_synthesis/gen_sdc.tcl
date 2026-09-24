# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/04_synthesis/gen_sdc.tcl
# Created     : 2026-09-07
# Description : APB project source, configuration, or documentation file.
# ===============================================================================

# Regenerates 04_synthesis/constraints.sdc from the port list of the
# synthesized netlist (04_synthesis/synth_output.v), so the SDC always
# matches what synthesis actually produced.
# Run from the repo root: yosys -c 04_synthesis/gen_sdc.tcl

yosys read_verilog 04_synthesis/synth_output.v
yosys hierarchy -top APB_Protocol

set top APB_Protocol
set clock_port PCLK
set clock_period_ns 40
set io_delay_ns 2

yosys tee -q -o 04_synthesis/_in.txt select -list $top/i:*
yosys tee -q -o 04_synthesis/_out.txt select -list $top/o:*

proc read_portnames {path top} {
    set fp [open $path r]
    set raw [read $fp]
    close $fp
    file delete $path
    set names {}
    foreach line [split $raw "\n"] {
        set line [string trim $line]
        if {$line eq ""} { continue }
        if {[string first "$top/" $line] != 0} { continue }
        lappend names [string range $line [string length "$top/"] end]
    }
    return $names
}

set input_ports  [read_portnames 04_synthesis/_in.txt  $top]
set output_ports [read_portnames 04_synthesis/_out.txt $top]

set input_ports [lsearch -all -inline -not -exact $input_ports $clock_port]

set out [open 04_synthesis/constraints.sdc w]
puts $out "# Timing constraints for $top"
puts $out "# Auto-generated from 04_synthesis/synth_output.v by 04_synthesis/gen_sdc.tcl -- do not hand-edit."
puts $out "# Clock: $clock_port, $clock_period_ns ns period ([expr {1000 / $clock_period_ns}] MHz)"
puts $out ""
puts $out "create_clock -name $clock_port -period $clock_period_ns \[get_ports $clock_port\]"
puts $out ""
puts $out "set_input_delay  -clock $clock_port $io_delay_ns \[get_ports {$input_ports}\]"
puts $out "set_output_delay -clock $clock_port $io_delay_ns \[get_ports {$output_ports}\]"
close $out

puts "wrote 04_synthesis/constraints.sdc ([llength $input_ports] in, [llength $output_ports] out, clock=$clock_port)"
