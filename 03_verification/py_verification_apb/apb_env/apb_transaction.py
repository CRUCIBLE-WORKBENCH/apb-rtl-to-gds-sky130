# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/03_verification/py_verification_apb/apb_env/apb_transaction.py
# Created     : 2026-09-07
# Description : APB project source, configuration, or documentation file.
# ===============================================================================

"""apb_transaction -- the sequence item passed from sequence to driver, and
from monitor to scoreboard.

One class serves both directions: a sequence fills in `addr`/`data`/
`is_write`/`hold_transfer` before sending it to the driver; the driver fills
in `result`/`bus` while executing it; the monitor builds its own instances
(observed, not requested) with the same fields and sends them to the
scoreboard.
"""
from __future__ import annotations

from pyuvm import uvm_sequence_item


class apb_transaction(uvm_sequence_item):
    def __init__(
        self,
        name: str = "apb_transaction",
        addr: int = 0,
        data: int = 0,
        is_write: bool = True,
        hold_transfer: bool = False,
        note: str = "",
    ):
        super().__init__(name)
        self.addr = addr
        self.data = data
        self.is_write = is_write
        self.hold_transfer = hold_transfer
        self.note = note
        # Filled in by the driver after driving the item on the DUT.
        self.result: int | None = None
        self.bus: dict[str, int | None] = {}

    def slave(self) -> str:
        return "S2" if self.addr & 0x100 else "S1"

    def __str__(self) -> str:
        op = "WRITE" if self.is_write else "READ"
        val = self.data if self.is_write else self.result
        return f"{op} addr=0x{self.addr:03x} val={val} ({self.note})"
