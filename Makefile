# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/Makefile
# Created     : 2026-09-08
# Description : Top-level Make orchestration for the APB RTL-to-GDS flow.
# ===============================================================================

PROJECT_ROOT := $(abspath .)
PYTHON ?= python

.PHONY: all flow lint rtl sim verify synth dft floorplan place cts route sta gds physical clean

all: flow

flow: lint sim verify synth floorplan place cts route sta gds physical

lint:
	$(MAKE) -C 00_lint

rtl:
	$(MAKE) -C 01_rtl

sim:
	$(MAKE) -C 02_sim

verify:
	$(MAKE) -C 03_verification

synth:
	$(MAKE) -C 04_synthesis

dft:
	$(MAKE) -C 05_dft

floorplan:
	$(MAKE) -C 06_floorplanning

place:
	$(MAKE) -C 07_placement

cts:
	$(MAKE) -C 09_place_and_route cts

route:
	$(MAKE) -C 09_place_and_route route

sta:
	$(MAKE) -C 08_sta

gds:
	$(MAKE) -C 10_gds

physical:
	$(MAKE) -C 11_physical_verification

clean:
	$(MAKE) -C 00_lint clean
	$(MAKE) -C 02_sim clean
	$(MAKE) -C 03_verification clean
	$(MAKE) -C 04_synthesis clean
	$(MAKE) -C 05_dft clean
	$(MAKE) -C 06_floorplanning clean
	$(MAKE) -C 07_placement clean
	$(MAKE) -C 09_place_and_route clean
	$(MAKE) -C 08_sta clean
	$(MAKE) -C 10_gds clean
	$(MAKE) -C 11_physical_verification clean
	$(PYTHON) "$(PROJECT_ROOT)/run.py" clean_files "$(PROJECT_ROOT)" "apbWaveform.vcd"