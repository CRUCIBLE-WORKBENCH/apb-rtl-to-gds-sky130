# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/03_verification/py_verification_apb/apb_env/apb_monitor.py
# Created     : 2026-09-07
# Description : APB project source, configuration, or documentation file.
# ===============================================================================

"""apb_monitor -- passively samples the APB bus each clock edge and reports
one apb_transaction per completed transfer via an analysis port. Drives
nothing.

Timing note (ground-truthed by direct per-edge instrumentation across
several iterations of getting this wrong -- see git history / AGENTS.md for
the full trail): writes and reads need *different* capture timing, not the
same rule applied to both.

- Writes: PWDATA is valid for the whole SETUP+ACCESS window per spec, so a
  write is reported on the same edge PSEL&&PENABLE&&PREADY are first
  observed together. This matters especially for a held (back-to-back)
  transfer's first write -- waiting an extra edge, as reads need, races the
  *next* item's driver updating the bus for its own item on that same
  later edge, and can silently report the next item's data instead.
- Reads: `apb_read_data_out` in this specific RTL is a registered output
  that lags PREADY's rising transition by exactly one clock edge (confirmed
  against the driver's own proven-correct timing, which reads one edge
  after its own wait_ready(1) call returns, for the same reason). A read is
  therefore reported one edge after PREADY's 0->1 transition, not on the
  same edge.

An earlier version of this monitor applied the read-only delay to both
directions uniformly, which corrupted write capture specifically in the
back-to-back case (confirmed via scoreboard instrumentation: it received
one item's address/data reported twice and the other item's never, in both
directions depending on exactly where the delay was placed).
"""
from __future__ import annotations

from cocotb.triggers import RisingEdge, Timer

from pyuvm import ConfigDB, uvm_analysis_port, uvm_monitor

from .apb_transaction import apb_transaction


def _signal_int(dut, name: str) -> int | None:
    try:
        signal = getattr(dut, name)
    except AttributeError:
        return None
    return int(signal.value) if signal.value.is_resolvable else None


class apb_monitor(uvm_monitor):
    def build_phase(self):
        self.dut = ConfigDB().get(self, "", "dut")
        self.ap = uvm_analysis_port("ap", self)

    async def run_phase(self):
        dut = self.dut
        pready_prev = False
        pending_read_capture = False
        while True:
            await RisingEdge(dut.PCLK)
            pready = bool(_signal_int(dut, "PREADY"))
            penable = _signal_int(dut, "PENABLE")
            psel = bool(_signal_int(dut, "PSEL1")) or bool(_signal_int(dut, "PSEL2"))

            if pending_read_capture:
                pending_read_capture = False
                await Timer(1, unit="ns")
                self.report(dut)

            rising = pready and not pready_prev
            if rising and psel and penable:
                pwrite = _signal_int(dut, "PWRITE")
                if pwrite:
                    # PWDATA is valid for the whole SETUP+ACCESS window (per
                    # spec), so a write can be reported immediately on this
                    # edge -- no need for the extra-edge wait reads require,
                    # and in fact waiting is actively wrong for a held
                    # (back-to-back) transfer's first write: the following
                    # item's driver updates the bus for its own item as soon
                    # as this edge lands, so a delayed read of PWDATA here
                    # would race that update and can report the *next*
                    # item's data instead of this one's.
                    self.report(dut)
                else:
                    pending_read_capture = True
            pready_prev = pready

    def report(self, dut) -> None:
        paddr = _signal_int(dut, "PADDR")
        pwrite = _signal_int(dut, "PWRITE")
        if paddr is None or pwrite is None:
            return

        item = apb_transaction("observed", addr=paddr, is_write=bool(pwrite), note="monitor")
        if pwrite:
            item.data = _signal_int(dut, "PWDATA") or 0
        else:
            item.result = _signal_int(dut, "apb_read_data_out")
        item.bus = {
            "PADDR": paddr,
            "PSEL1": _signal_int(dut, "PSEL1"),
            "PSEL2": _signal_int(dut, "PSEL2"),
            "PENABLE": _signal_int(dut, "PENABLE"),
            "PWRITE": pwrite,
            "PREADY": _signal_int(dut, "PREADY"),
            "PSLVERR": _signal_int(dut, "PSLVERR"),
        }
        self.ap.write(item)
