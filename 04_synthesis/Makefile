# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/04_synthesis/Makefile
# Created     : 2026-09-08
# Description : Make entrypoint for APB Yosys synthesis and SDC generation.
# ===============================================================================

PROJECT_ROOT := $(abspath ..)

.PHONY: all synth sdc clean

all: synth sdc

synth:
	cd "$(PROJECT_ROOT)" && igny run yosys -s 04_synthesis/synth.tcl

sdc:
	cd "$(PROJECT_ROOT)" && igny run yosys -c 04_synthesis/gen_sdc.tcl

clean:
	python "$(PROJECT_ROOT)/run.py" clean_files "$(PROJECT_ROOT)" \
		"04_synthesis/_in.txt" \
		"04_synthesis/_out.txt" \
		"04_synthesis/synth_output.v" \
		"04_synthesis/constraints.sdc"
