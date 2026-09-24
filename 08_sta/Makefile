# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/08_sta/Makefile
# Created     : 2026-09-08
# Description : Make entrypoint for APB OpenROAD/OpenSTA timing analysis.
# ===============================================================================

PROJECT_ROOT := $(abspath ..)
SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

PDK_ROOT ?= $(shell find $(HOME)/.ciel -path "*/sky130A/libs.tech/netgen/sky130A_setup.tcl" -print -quit 2>/dev/null | sed 's#/sky130A/libs.tech/netgen/sky130A_setup.tcl##')
export PDK_ROOT

.PHONY: all sta sta-tt sta-ss corners clean

all: corners

sta: sta-tt

sta-tt:
	cd "$(PROJECT_ROOT)" && STA_CORNER=tt igny run openroad -exit 08_sta/openroad_sta.tcl | tee 08_sta/timing_report_tt.txt

sta-ss:
	cd "$(PROJECT_ROOT)" && STA_CORNER=ss igny run openroad -exit 08_sta/openroad_sta.tcl | tee 08_sta/timing_report_ss.txt

corners: sta-tt sta-ss

clean:
	cd "$(PROJECT_ROOT)" && rm -f 08_sta/timing_report.txt 08_sta/timing_report_tt.txt 08_sta/timing_report_ss.txt
