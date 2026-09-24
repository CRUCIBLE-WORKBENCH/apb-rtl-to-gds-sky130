# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/10_gds/Makefile
# Created     : 2026-09-08
# Description : Make entrypoint for APB GDS streamout.
# ===============================================================================

PROJECT_ROOT := $(abspath ..)
PYTHON ?= python

.PHONY: all gds clean

all: gds

gds:
	$(PYTHON) "$(PROJECT_ROOT)/run.py" ensure_stage "$(PROJECT_ROOT)" "09_place_and_route/route.def" "09_place_and_route" "route"
	$(PYTHON) "$(PROJECT_ROOT)/run.py" run_gds "$(PROJECT_ROOT)"

clean:
	$(PYTHON) "$(PROJECT_ROOT)/run.py" clean_files "$(PROJECT_ROOT)" "10_gds/APB_Protocol.gds"