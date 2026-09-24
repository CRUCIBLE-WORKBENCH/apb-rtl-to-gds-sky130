# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/07_placement/Makefile
# Created     : 2026-09-08
# Description : Make entrypoint for APB OpenROAD placement.
# ===============================================================================

PROJECT_ROOT := $(abspath ..)

PDK_ROOT ?= $(shell find $(HOME)/.ciel -path "*/sky130A/libs.tech/netgen/sky130A_setup.tcl" -print -quit 2>/dev/null | sed 's#/sky130A/libs.tech/netgen/sky130A_setup.tcl##')
export PDK_ROOT

.PHONY: all place clean

all: place

place:
	cd "$(PROJECT_ROOT)" && if [ ! -f 06_floorplanning/floorplan.odb ]; then $(MAKE) -C 06_floorplanning; fi
	cd "$(PROJECT_ROOT)" && igny run openroad -exit 07_placement/openroad_placement.tcl

clean:
	cd "$(PROJECT_ROOT)" && rm -f 07_placement/placement.def 07_placement/placement.odb
