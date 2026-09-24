# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/11_physical_verification/Makefile
# Created     : 2026-09-08
# Description : Make entrypoint for APB DRC and LVS physical verification.
# ===============================================================================

PROJECT_ROOT := $(abspath ..)

.PHONY: all physical clean

all: physical

physical:
	cd "$(PROJECT_ROOT)" && if [ ! -f 10_gds/APB_Protocol.gds ]; then $(MAKE) -C 10_gds; fi
	cd "$(PROJECT_ROOT)" && bash 11_physical_verification/run_physical_verification.sh

clean:
	cd "$(PROJECT_ROOT)" && rm -f 11_physical_verification/results/*.ext 11_physical_verification/results/*.log 11_physical_verification/results/*.spice 11_physical_verification/results/*.v 11_physical_verification/results/*.commands 11_physical_verification/results/physical_verification_status.txt 11_physical_verification/results/openroad_route_drc.rpt
