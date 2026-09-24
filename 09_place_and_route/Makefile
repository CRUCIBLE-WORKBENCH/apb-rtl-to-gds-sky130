# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/09_place_and_route/Makefile
# Created     : 2026-09-08
# Description : Make entrypoint for APB OpenROAD CTS and routing.
# ===============================================================================

PROJECT_ROOT := $(abspath ..)

PDK_ROOT ?= $(shell find $(HOME)/.ciel -path "*/sky130A/libs.tech/netgen/sky130A_setup.tcl" -print -quit 2>/dev/null | sed 's#/sky130A/libs.tech/netgen/sky130A_setup.tcl##')
export PDK_ROOT

.PHONY: all cts route clean

all: route

cts:
	cd "$(PROJECT_ROOT)" && if [ ! -f 07_placement/placement.odb ]; then $(MAKE) -C 07_placement; fi
	cd "$(PROJECT_ROOT)" && igny run openroad -exit 09_place_and_route/openroad_cts.tcl

route: cts
	cd "$(PROJECT_ROOT)" && igny run openroad -exit 09_place_and_route/openroad_route.tcl

clean:
	cd "$(PROJECT_ROOT)" && rm -f 09_place_and_route/cts.def 09_place_and_route/cts.odb \
		09_place_and_route/route.def 09_place_and_route/route.odb 09_place_and_route/route.spef \
		09_place_and_route/route_output.v 09_place_and_route/route.guide \
		09_place_and_route/route_drc.rpt 09_place_and_route/route_maze.log
