# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/10_gds/Makefile
# Created     : 2026-09-08
# Description : Make entrypoint for APB GDS streamout.
# ===============================================================================

PROJECT_ROOT := $(abspath ..)
PDK_ROOT ?= $(shell find $(HOME)/.ciel -path "*/sky130A/libs.tech/netgen/sky130A_setup.tcl" -print -quit 2>/dev/null | sed 's#/sky130A/libs.tech/netgen/sky130A_setup.tcl##')
export PDK_ROOT

.PHONY: all gds clean

all: gds

gds:
	cd "$(PROJECT_ROOT)" && if [ ! -f 09_place_and_route/route.def ]; then $(MAKE) -C 09_place_and_route route; fi
	cd "$(PROJECT_ROOT)" && bash 10_gds/run_gds_streamout.sh

clean:
	cd "$(PROJECT_ROOT)" && rm -f 10_gds/APB_Protocol.gds
