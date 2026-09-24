# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/03_verification/py_verification_apb/tests/test_apb_env.py
# Created     : 2026-09-07
# Description : APB project source, configuration, or documentation file.
# ===============================================================================

"""UVM-style environment test for APB_Protocol.

This is the sequence item -> sequence -> sequencer -> driver -> monitor ->
agent -> scoreboard -> env -> test build-out described in AGENTS.md's next
steps. It exercises the same three phases as the existing cocotb/pyuvm
smoke test (tests/test_apb_pyuvm.py) and the Verilog testbench
(02_sim/test.v), through a proper component architecture instead of one
monolithic uvm_test. Keep the smoke test as-is; it remains a smaller,
faster toolchain sanity check.
"""
from __future__ import annotations

import json
import os
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from pyuvm import ConfigDB, uvm_root, uvm_test

from py_verification_apb.apb_env.apb_env import apb_env
from py_verification_apb.apb_env.apb_sequences import ApbRegressionSequence


class ApbEnvTest(uvm_test):
    def build_phase(self):
        self.env = apb_env("env", self)

    async def reset(self) -> None:
        dut = self.dut
        dut.PRESETn.value = 0
        dut.transfer.value = 0
        dut.READ_WRITE.value = 0
        dut.apb_write_paddr.value = 0
        dut.apb_write_data.value = 0
        dut.apb_read_paddr.value = 0
        await RisingEdge(dut.PCLK)
        await RisingEdge(dut.PCLK)
        dut.PRESETn.value = 1
        await RisingEdge(dut.PCLK)

    async def run_phase(self):
        self.raise_objection()
        try:
            self.dut = ConfigDB().get(self, "", "dut")
            await self.reset()
            seq = ApbRegressionSequence("apb_regression")
            await seq.start(self.env.agent.sequencer)

            # Drain time: the driver's item_done() for the final item can
            # unblock this run_phase in the same simulation instant the
            # monitor still has a pending report scheduled for (both key
            # off the same rising edge, one Timer(1ns) apart in scheduling
            # order). Without this, the last transaction can be dropped
            # from the scoreboard's count even though the DUT behaved
            # correctly. Two cycles is generous slack, not a tuned minimum.
            for _ in range(2):
                await RisingEdge(self.dut.PCLK)

            sb = self.env.scoreboard
            self.write_summary(sb)
            self.report_coverage(self.env.coverage)
            assert sb.errors == 0, f"APB env test found {sb.errors} mismatch(es)"
        finally:
            self.drop_objection()

    def write_summary(self, sb) -> None:
        path = Path(
            os.environ.get(
                "APB_PYUVM_STATUS",
                "py_verification_apb/results/apb_env_status.json",
            )
        )
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(
                {
                    "status": "PASS" if sb.errors == 0 else "FAIL",
                    "checks": sb.checks,
                    "errors": sb.errors,
                    "transactions": sb.transactions,
                    "test": self.__class__.__name__,
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
        self.logger.info("Wrote summary artifact: %s", path)

    def report_coverage(self, cov) -> None:
        self.logger.info("==== Functional coverage ====")
        for name, percent in cov.report().items():
            self.logger.info("  %-32s %6.1f%%", name, percent)


@cocotb.test()
async def apb_env_regression(dut):
    cocotb.start_soon(Clock(dut.PCLK, 10, unit="ns").start())
    ConfigDB().set(None, "*", "dut", dut)
    await uvm_root().run_test("ApbEnvTest", keep_set={ConfigDB})
