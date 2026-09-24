# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/03_verification/py_verification_apb/apb_env/apb_coverage.py
# Created     : 2026-09-07
# Description : APB project source, configuration, or documentation file.
# ===============================================================================

"""apb_coverage -- functional coverage collector. Same subscriber pattern as
apb_scoreboard.py (a uvm_subscriber sitting on the monitor's analysis port),
but purely observational: it never checks correctness and never affects
scoreboard behavior, it only records which transaction shapes were actually
exercised by the regression.

Coverage model: direction (write/read) and target slave (S1/S2), plus their
cross -- "did we exercise every combination, not just every dimension
independently." Deliberately does NOT include hold_transfer/back-to-back
mode: that field is sequence-side intent (set by the item the *sequence*
sends to the driver), and apb_monitor.py's observed items are built purely
from bus signals (PADDR/PWRITE/PWDATA) -- it has no way to see "was this
driven with hold_transfer=True" on the wire, so every monitor-sourced item
has hold_transfer=False by construction. A coverpoint on it would silently
read a fixed, meaningless percentage rather than measuring anything real;
better to not claim coverage the monitor structurally can't provide than to
show a number that looks like a gap but isn't one.
"""
from __future__ import annotations

from cocotb_coverage.coverage import CoverCross, CoverPoint, coverage_db
from pyuvm import uvm_subscriber


@CoverPoint(
    "apb.direction",
    xf=lambda item: "write" if item.is_write else "read",
    bins=["write", "read"],
)
@CoverPoint(
    "apb.slave",
    xf=lambda item: item.slave(),
    bins=["S1", "S2"],
)
@CoverCross("apb.cross.slave_x_direction", items=["apb.slave", "apb.direction"])
def _sample(item) -> None:
    """Registers one observed transaction against every coverpoint/cross
    above. Body is empty on purpose -- cocotb_coverage's decorators do the
    actual sampling before this function runs."""


class apb_coverage(uvm_subscriber):
    def write(self, item) -> None:
        _sample(item)

    def report(self) -> dict[str, float]:
        """Returns {coverpoint_name: percent_covered} for every point/cross
        registered above. Called explicitly from the test at the end of the
        run (pyuvm's phase set doesn't guarantee an auto-invoked report
        phase the way full UVM does)."""
        names = ["apb.direction", "apb.slave", "apb.cross.slave_x_direction"]
        return {name: coverage_db[name].cover_percentage for name in names}
