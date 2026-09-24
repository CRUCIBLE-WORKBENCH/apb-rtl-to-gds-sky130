# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/06_floorplanning/Makefile
# Created     : 2026-09-08
# Description : Make entrypoint for APB OpenROAD floorplanning.
# ===============================================================================

PROJECT_ROOT := $(abspath ..)

# openroad_floorplan.tcl reads the Sky130 tech LEF and liberty from $PDK_ROOT.
# Discover it from the ciel install so the stage runs without the caller having
# exported anything; an already-set PDK_ROOT wins.
PDK_ROOT ?= $(shell find $(HOME)/.ciel -path "*/sky130A/libs.tech/netgen/sky130A_setup.tcl" -print -quit 2>/dev/null | sed 's#/sky130A/libs.tech/netgen/sky130A_setup.tcl##')
export PDK_ROOT

.PHONY: all floorplan clean

all: floorplan

floorplan:
	cd "$(PROJECT_ROOT)" && igny run openroad -exit 06_floorplanning/openroad_floorplan.tcl

clean:
	python "$(PROJECT_ROOT)/run.py" clean_files "$(PROJECT_ROOT)" "06_floorplanning/floorplan.def" "06_floorplanning/floorplan.odb" "06_floorplanning/_sky130_tech.tlef"
