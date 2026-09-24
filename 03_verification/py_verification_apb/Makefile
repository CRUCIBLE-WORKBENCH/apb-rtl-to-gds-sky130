# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/03_verification/py_verification_apb/Makefile
# Created     : 2026-09-07
# Description : APB project source, configuration, or documentation file.
# ===============================================================================

TOPLEVEL_LANG ?= verilog
SIM ?= icarus
WAVES ?= 1

VERILOG_SOURCES := $(abspath ../../01_rtl/apb_protocol.v)
COMPILE_ARGS += -I$(abspath ../../01_rtl)

TOPLEVEL := APB_Protocol
MODULE := tests.test_apb_pyuvm
SIM_BUILD ?= sim_build

.PHONY: sim
sim:
	$(MAKE) -f $(shell cocotb-config --makefiles)/Makefile.sim
