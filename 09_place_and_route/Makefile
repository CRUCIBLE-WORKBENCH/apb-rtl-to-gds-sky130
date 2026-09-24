# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/09_place_and_route/Makefile
# Created     : 2026-09-08
# Description : Make entrypoint for APB OpenROAD CTS and routing.
# ===============================================================================

PROJECT_ROOT := $(abspath ..)
PYTHON ?= python

.PHONY: all cts route clean

all: route

cts:
	$(PYTHON) "$(PROJECT_ROOT)/run.py" ensure_stage "$(PROJECT_ROOT)" "07_placement/placement.odb" "07_placement"
	$(PYTHON) "$(PROJECT_ROOT)/run.py" run_openroad "$(PROJECT_ROOT)" "09_place_and_route/openroad_cts.tcl"

route: cts
	$(PYTHON) "$(PROJECT_ROOT)/run.py" run_openroad "$(PROJECT_ROOT)" "09_place_and_route/openroad_route.tcl"

clean:
	$(PYTHON) "$(PROJECT_ROOT)/run.py" clean_files "$(PROJECT_ROOT)" \
		"09_place_and_route/cts.def" \
		"09_place_and_route/cts.odb" \
		"09_place_and_route/route.def" \
		"09_place_and_route/route.odb" \
		"09_place_and_route/route.spef" \
		"09_place_and_route/route_output.v" \
		"09_place_and_route/route.guide" \
		"09_place_and_route/route_drc.rpt" \
		"09_place_and_route/route_maze.log"