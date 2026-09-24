# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/03_verification/py_verification_apb/apb_env/apb_driver.py
# Created     : 2026-09-07
# Description : APB project source, configuration, or documentation file.
# ===============================================================================

"""apb_driver -- pulls apb_transactions off the sequencer and drives them on
the DUT's custom control interface (transfer/READ_WRITE/apb_write_paddr/...).

Timing is ported from the proven cocotb smoke test
(tests/test_apb_pyuvm.py::apb_write/apb_read), not reinvented: assert
`transfer` at a falling edge, wait for PREADY high, drop `transfer` one
falling edge before the completing rising edge (see the sky130 repo's
AGENTS.md Experiment 04 for why the drop has to happen *before* the
completing edge, not after -- dropping it late makes the FSM's
ACCESS-exit decision see transfer still high and loop back into SETUP
instead of returning to IDLE).

For a `hold_transfer` item (the first half of a back-to-back pair),
`transfer` is deliberately not dropped, and the following item skips the
falling-edge preamble since transfer is already asserted. PREADY reads
high for two consecutive edges per transfer, so re-arming a wait for it
immediately after a held transfer must first wait for it to drop, or the
wait spuriously fires on the *previous* transfer's trailing pulse -- the
same race documented (and fixed) in the Verilog testbench.
"""
from __future__ import annotations

from cocotb.triggers import FallingEdge, RisingEdge, Timer
from pyuvm import ConfigDB, uvm_driver


def _signal_int(dut, name: str) -> int | None:
    try:
        signal = getattr(dut, name)
    except AttributeError:
        return None
    return int(signal.value) if signal.value.is_resolvable else None


def _value_is(signal, expected: int) -> bool:
    return signal.value.is_resolvable and int(signal.value) == expected


class apb_driver(uvm_driver):
    def build_phase(self):
        self.dut = ConfigDB().get(self, "", "dut")
        self._transfer_held = False

    async def run_phase(self):
        while True:
            item = await self.seq_item_port.get_next_item()
            await self.drive_item(item)
            self.seq_item_port.item_done()

    async def wait_ready(self, value: int) -> None:
        for _ in range(200):
            if _value_is(self.dut.PREADY, value):
                return
            await Timer(1, unit="ns")
        raise TimeoutError(f"Timed out waiting for PREADY == {value}")

    def capture_bus(self) -> dict[str, int | None]:
        dut = self.dut
        return {
            "PADDR": _signal_int(dut, "PADDR"),
            "PSEL1": _signal_int(dut, "PSEL1"),
            "PSEL2": _signal_int(dut, "PSEL2"),
            "PENABLE": _signal_int(dut, "PENABLE"),
            "PWRITE": _signal_int(dut, "PWRITE"),
            "PREADY": _signal_int(dut, "PREADY"),
            "PSLVERR": _signal_int(dut, "PSLVERR"),
        }

    async def drive_item(self, item) -> None:
        dut = self.dut

        if self._transfer_held:
            # Continuing a back-to-back sequence: transfer is already
            # asserted. Update the bus to the new item's address/data
            # *before* waiting for PREADY to drop -- the RTL re-enters
            # SETUP and re-samples apb_write_paddr/apb_write_data almost
            # immediately once PREADY drops, so if the new values are not
            # already in place by then, it silently re-captures the
            # *previous* item's stale values instead (confirmed by
            # instrumenting the scoreboard: it received the first write's
            # address/data twice, never the second write's own values).
            dut.READ_WRITE.value = 0 if item.is_write else 1
            if item.is_write:
                dut.apb_write_paddr.value = item.addr
                dut.apb_write_data.value = item.data
            else:
                dut.apb_read_paddr.value = item.addr
            await self.wait_ready(0)
            # transfer is already 1 from the held item; nothing else to set.
        else:
            await FallingEdge(dut.PCLK)
            dut.READ_WRITE.value = 0 if item.is_write else 1
            if item.is_write:
                dut.apb_write_paddr.value = item.addr
                dut.apb_write_data.value = item.data
            else:
                dut.apb_read_paddr.value = item.addr
            dut.transfer.value = 1

        await self.wait_ready(1)
        item.bus = self.capture_bus()

        if item.hold_transfer:
            await RisingEdge(dut.PCLK)
            self._transfer_held = True
        else:
            await FallingEdge(dut.PCLK)
            dut.transfer.value = 0
            await RisingEdge(dut.PCLK)
            self._transfer_held = False

        if not item.is_write:
            await Timer(1, unit="ns")
            signal = dut.apb_read_data_out
            item.result = int(signal.value) if signal.value.is_resolvable else None
