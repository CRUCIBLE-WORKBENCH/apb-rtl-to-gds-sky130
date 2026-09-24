# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/00_lint/Makefile
# Created     : 2026-09-08
# Description : Make entrypoint for APB Verilator lint.
# ===============================================================================

PROJECT_ROOT := $(abspath ..)

.PHONY: all lint clean 	

all: lint

lint:
	cd "$(PROJECT_ROOT)" && igny run verilator --lint-only -Wall -Wno-fatal -I01_rtl 01_rtl/apb_protocol.v

clean:
	cd "$(PROJECT_ROOT)" && rm -f 00_lint/lint_report.txt 00_lint/lint_stdout.tmp
