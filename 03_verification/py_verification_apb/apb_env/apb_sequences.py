# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/03_verification/py_verification_apb/apb_env/apb_sequences.py
# Created     : 2026-09-07
# Description : APB project source, configuration, or documentation file.
# ===============================================================================

"""ApbRegressionSequence -- reproduces the three-phase exercise proven by
both the Verilog testbench (RTL/test.v) and the earlier cocotb/pyuvm smoke
test (tests/test_apb_pyuvm.py): write 16 registers to each completer, read
all 32 back, then one back-to-back write pair with `transfer` held high
across the item boundary. The sequence only issues items -- it does not
know expected values or do any checking; that is the scoreboard's job,
kept deliberately separate.
"""
from __future__ import annotations

from pyuvm import uvm_sequence

from .apb_transaction import apb_transaction

NUM_REGS = 16


class ApbRegressionSequence(uvm_sequence):
    async def body(self):
        await self.write_phase()
        await self.readback_phase()
        await self.back_to_back_phase()

    async def issue(self, **kwargs) -> apb_transaction:
        item = apb_transaction(**kwargs)
        await self.start_item(item)
        await self.finish_item(item)
        return item

    async def write_phase(self) -> None:
        for i in range(NUM_REGS):
            await self.issue(addr=i, data=0xA0 + i, is_write=True, note="slave1_write")
        for i in range(NUM_REGS):
            await self.issue(addr=0x100 | i, data=0x50 + i, is_write=True, note="slave2_write")

    async def readback_phase(self) -> None:
        for i in range(NUM_REGS):
            await self.issue(addr=i, is_write=False, note="slave1_readback")
        for i in range(NUM_REGS):
            await self.issue(addr=0x100 | i, is_write=False, note="slave2_readback")

    async def back_to_back_phase(self) -> None:
        await self.issue(addr=20, data=0xCC, is_write=True, hold_transfer=True, note="back_to_back_write_1")
        await self.issue(addr=21, data=0xDD, is_write=True, note="back_to_back_write_2")
        await self.issue(addr=20, is_write=False, note="back_to_back_readback")
        await self.issue(addr=21, is_write=False, note="back_to_back_readback")
