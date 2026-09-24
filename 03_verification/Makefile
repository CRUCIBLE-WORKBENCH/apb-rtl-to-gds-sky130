# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/03_verification/Makefile
# Created     : 2026-09-08
# Description : Make entrypoint for APB Python/cocotb/pyuvm verification.
# ===============================================================================

PROJECT_ROOT := $(abspath ..)
VERIFY_ROOT := 03_verification/py_verification_apb

.PHONY: all check smoke env clean

all: check smoke env

check:
	cd "$(PROJECT_ROOT)" && igny run script "$(VERIFY_ROOT)/check_env.py"

smoke:
	cd "$(PROJECT_ROOT)" && igny run script "$(VERIFY_ROOT)/run_apb_pyuvm.py"

env:
	cd "$(PROJECT_ROOT)" && igny run script "$(VERIFY_ROOT)/run_apb_env.py"

clean:
	cd "$(PROJECT_ROOT)" && rm -rf "$(VERIFY_ROOT)/results" "$(VERIFY_ROOT)/sim_build" "$(VERIFY_ROOT)/sim_build_env"
	cd "$(PROJECT_ROOT)" && find "$(VERIFY_ROOT)" -type d -name "__pycache__" -exec rm -rf {} +
