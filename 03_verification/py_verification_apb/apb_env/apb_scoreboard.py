# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/03_verification/py_verification_apb/apb_env/apb_scoreboard.py
# Created     : 2026-09-07
# Description : APB project source, configuration, or documentation file.
# ===============================================================================

"""apb_scoreboard -- owns the reference (shadow-memory) model and checks
every observed transaction from the monitor against it. Same model shape
as the Verilog testbench's shadow1/shadow2 arrays and the smoke test's
self.shadow1/self.shadow2 -- ported, not reinvented.
"""
from __future__ import annotations

from pyuvm import uvm_subscriber


class apb_scoreboard(uvm_subscriber):
    def build_phase(self):
        self.shadow1 = [0] * 64
        self.shadow2 = [0] * 64
        self.checks = 0
        self.errors = 0
        self.transactions = 0

    def write(self, item) -> None:
        self.transactions += 1
        if item.is_write:
            if item.addr & 0x100:
                self.shadow2[item.addr & 0x3F] = item.data
            else:
                self.shadow1[item.addr & 0x3F] = item.data
            return

        expected = (
            self.shadow2[item.addr & 0x3F]
            if item.addr & 0x100
            else self.shadow1[item.addr & 0x3F]
        )
        self.checks += 1
        if item.result != expected:
            self.errors += 1
            self.logger.error(
                "MISMATCH addr=0x%03x expected=0x%02x actual=0x%02x",
                item.addr,
                expected,
                item.result if item.result is not None else -1,
            )
