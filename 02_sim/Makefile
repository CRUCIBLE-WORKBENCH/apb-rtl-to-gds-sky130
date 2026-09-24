# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/02_sim/Makefile
# Created     : 2026-09-08
# Description : Make entrypoint for APB Icarus simulation.
# ===============================================================================

PROJECT_ROOT := $(abspath ..)
SIM_OUT := 02_sim/apb_sim.out
WAVE_OUT := 02_sim/apbWaveform.vcd

.PHONY: all sim compile run clean

all: sim

sim: compile run

compile:
	cd "$(PROJECT_ROOT)" && igny run iverilog -o "$(SIM_OUT)" -s test -I 01_rtl 01_rtl/apb_protocol.v 02_sim/test.v

run:
	cd "$(PROJECT_ROOT)" && igny run vvp "$(SIM_OUT)"
	python ../run.py move_waveform "$(PROJECT_ROOT)" "$(WAVE_OUT)"
	
clean:
	python ../run.py clean_files "$(PROJECT_ROOT)" "$(SIM_OUT)" "$(WAVE_OUT)"
