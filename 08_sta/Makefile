# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/08_sta/Makefile
# Created     : 2026-09-08
# Description : Make entrypoint for APB OpenROAD/OpenSTA timing analysis.
# ===============================================================================

PROJECT_ROOT := $(abspath ..)
PYTHON ?= python

.PHONY: all sta sta-tt sta-ss corners clean

all: corners

sta: sta-tt

sta-tt:
	$(PYTHON) "$(PROJECT_ROOT)/run.py" run_sta "$(PROJECT_ROOT)" "tt" "08_sta/timing_report_tt.txt"

sta-ss:
	$(PYTHON) "$(PROJECT_ROOT)/run.py" run_sta "$(PROJECT_ROOT)" "ss" "08_sta/timing_report_ss.txt"

corners: sta-tt sta-ss

clean:
	$(PYTHON) "$(PROJECT_ROOT)/run.py" clean_files "$(PROJECT_ROOT)" "08_sta/timing_report.txt" "08_sta/timing_report_tt.txt" "08_sta/timing_report_ss.txt"