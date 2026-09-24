# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/11_physical_verification/Makefile
# Created     : 2026-09-08
# Description : Make entrypoint for APB DRC and LVS physical verification.
# ===============================================================================

PROJECT_ROOT := $(abspath ..)
PYTHON ?= python

.PHONY: all physical clean

all: physical

physical:
	$(PYTHON) "$(PROJECT_ROOT)/run.py" ensure_stage "$(PROJECT_ROOT)" "10_gds/APB_Protocol.gds" "10_gds"
	$(PYTHON) "$(PROJECT_ROOT)/run.py" run_physical "$(PROJECT_ROOT)"

clean:
	$(PYTHON) "$(PROJECT_ROOT)/run.py" clean_glob "$(PROJECT_ROOT)" \
		"11_physical_verification/results/*.ext" \
		"11_physical_verification/results/*.log" \
		"11_physical_verification/results/*.spice" \
		"11_physical_verification/results/*.v" \
		"11_physical_verification/results/*.commands"

	$(PYTHON) "$(PROJECT_ROOT)/run.py" clean_files "$(PROJECT_ROOT)" \
		"11_physical_verification/results/physical_verification_status.txt" \
		"11_physical_verification/results/openroad_route_drc.rpt"