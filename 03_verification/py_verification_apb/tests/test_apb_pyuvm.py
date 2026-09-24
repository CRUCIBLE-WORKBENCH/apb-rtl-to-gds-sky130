# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/03_verification/py_verification_apb/tests/test_apb_pyuvm.py
# Created     : 2026-09-07
# Description : APB project source, configuration, or documentation file.
# ===============================================================================

"""pyuvm smoke test for the APB_Protocol RTL."""
from __future__ import annotations

import json
import os
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer
from cocotb.utils import get_sim_time
from pyuvm import ConfigDB, uvm_root, uvm_test


NUM_REGS = 16


def _value_is(signal, expected: int) -> bool:
    return signal.value.is_resolvable and int(signal.value) == expected


def _signal_int(dut, name: str) -> int | None:
    try:
        signal = getattr(dut, name)
    except AttributeError:
        return None
    return int(signal.value) if signal.value.is_resolvable else None


def _hex(value: int | None, width: int) -> str:
    if value is None:
        return "--"
    return f"0x{value:0{width}x}"


class APBPyuvmSmokeTest(uvm_test):
    """UVM-style smoke test that mirrors the self-checking Verilog testbench."""

    async def run_phase(self):
        self.raise_objection()
        try:
            self.dut = ConfigDB().get(self, "", "dut")
            self.errors = 0
            self.checks = 0
            self.transaction_count = 0
            self.monitor_header_printed = False
            self.shadow1 = [0] * 64
            self.shadow2 = [0] * 64

            await self.reset()
            await self.run_write_readback_phase()
            await self.run_back_to_back_phase()
            self.write_summary()

            assert self.errors == 0, f"APB pyuvm smoke found {self.errors} mismatch(es)"
        finally:
            self.drop_objection()

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
        self.monitor_event("RESET_RELEASED", note="PRESETn=1, APB smoke sequence starting")

    async def wait_ready(self, value: int = 1) -> None:
        for _ in range(100):
            if _value_is(self.dut.PREADY, value):
                return
            await Timer(1, unit="ns")
        raise TimeoutError(f"Timed out waiting for PREADY == {value}")

    async def apb_write(self, addr: int, data: int, note: str = "directed_write") -> None:
        dut = self.dut
        await FallingEdge(dut.PCLK)
        dut.READ_WRITE.value = 0
        dut.apb_write_paddr.value = addr
        dut.apb_write_data.value = data
        dut.transfer.value = 1
        await self.wait_ready(1)
        bus = self.capture_bus()
        await FallingEdge(dut.PCLK)
        dut.transfer.value = 0
        await RisingEdge(dut.PCLK)

        if addr & 0x100:
            self.shadow2[addr & 0x3F] = data
        else:
            self.shadow1[addr & 0x3F] = data

        self.monitor_transaction("WRITE", addr, bus=bus, write_data=data, status="DONE", note=note)

    async def apb_read(self, addr: int, expected: int | None = None, note: str = "directed_read") -> int:
        dut = self.dut
        await FallingEdge(dut.PCLK)
        dut.READ_WRITE.value = 1
        dut.apb_read_paddr.value = addr
        dut.transfer.value = 1
        await self.wait_ready(1)
        bus = self.capture_bus()
        await FallingEdge(dut.PCLK)
        dut.transfer.value = 0
        await RisingEdge(dut.PCLK)
        await Timer(1, unit="ns")
        read_data = int(dut.apb_read_data_out.value)
        status = "PASS" if expected is None or read_data == expected else "FAIL"
        self.monitor_transaction(
            "READ",
            addr,
            bus=bus,
            read_data=read_data,
            expected=expected,
            status=status,
            note=note,
        )
        return read_data

    def check(self, addr: int, actual: int, expected: int) -> None:
        self.checks += 1
        if actual != expected:
            self.errors += 1
            self.logger.error(
                "MISMATCH addr=0x%03x expected=0x%02x actual=0x%02x",
                addr,
                expected,
                actual,
            )

    async def run_write_readback_phase(self) -> None:
        for index in range(NUM_REGS):
            await self.apb_write(index, 0xA0 + index)
        for index in range(NUM_REGS):
            await self.apb_write(0x100 | index, 0x50 + index)

        for index in range(NUM_REGS):
            actual = await self.apb_read(index, expected=self.shadow1[index], note="slave1_readback")
            self.check(index, actual, self.shadow1[index])
        for index in range(NUM_REGS):
            addr = 0x100 | index
            actual = await self.apb_read(addr, expected=self.shadow2[index], note="slave2_readback")
            self.check(addr, actual, self.shadow2[index])

    async def run_back_to_back_phase(self) -> None:
        dut = self.dut
        await FallingEdge(dut.PCLK)
        dut.READ_WRITE.value = 0
        dut.apb_write_paddr.value = 20
        dut.apb_write_data.value = 0xCC
        dut.transfer.value = 1
        await self.wait_ready(1)
        bus = self.capture_bus()
        await RisingEdge(dut.PCLK)
        self.shadow1[20] = 0xCC
        self.monitor_transaction(
            "WRITE",
            20,
            bus=bus,
            write_data=0xCC,
            status="DONE",
            note="back_to_back_write_1_transfer_held",
        )

        dut.apb_write_paddr.value = 21
        dut.apb_write_data.value = 0xDD
        await self.wait_ready(0)
        await self.wait_ready(1)
        bus = self.capture_bus()
        await FallingEdge(dut.PCLK)
        dut.transfer.value = 0
        await RisingEdge(dut.PCLK)

        self.shadow1[21] = 0xDD
        self.monitor_transaction(
            "WRITE",
            21,
            bus=bus,
            write_data=0xDD,
            status="DONE",
            note="back_to_back_write_2",
        )
        self.check(20, await self.apb_read(20, expected=self.shadow1[20], note="back_to_back_readback"), self.shadow1[20])
        self.check(21, await self.apb_read(21, expected=self.shadow1[21], note="back_to_back_readback"), self.shadow1[21])

    def monitor_event(self, event: str, note: str = "") -> None:
        self.print_monitor_header()
        self.logger.info(
            "APB_MON | %-4s | %-8s | %-5s | %-5s | %-8s | %-8s | %-7s | %-7s | %-7s | %-5s | %-5s | %-3s | %-6s | %-6s | %-6s | %-6s | %s",
            "--",
            f"{get_sim_time('ns')}ns",
            event,
            "--",
            "--",
            "--",
            "--",
            "--",
            "--",
            "--",
            "--",
            "--",
            "--",
            "--",
            "--",
            "--",
            note,
        )

    def monitor_transaction(
        self,
        op: str,
        addr: int,
        *,
        bus: dict[str, int | None],
        write_data: int | None = None,
        read_data: int | None = None,
        expected: int | None = None,
        status: str,
        note: str,
    ) -> None:
        self.transaction_count += 1
        self.print_monitor_header()
        slave = "S2" if addr & 0x100 else "S1"
        self.logger.info(
            "APB_MON | %04d | %-8s | %-5s | %-5s | %-8s | %-8s | %-7s | %-7s | %-7s | %-5s | %-5s | %-3s | %-6s | %-6s | %-6s | %-6s | %s",
            self.transaction_count,
            f"{get_sim_time('ns')}ns",
            op,
            slave,
            _hex(addr, 3),
            _hex(bus["PADDR"], 3),
            _hex(write_data, 2),
            _hex(read_data, 2),
            _hex(expected, 2),
            str(bus["PSEL1"]),
            str(bus["PSEL2"]),
            str(bus["PENABLE"]),
            str(bus["PWRITE"]),
            str(bus["PREADY"]),
            str(bus["PSLVERR"]),
            status,
            note,
        )

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

    def print_monitor_header(self) -> None:
        if self.monitor_header_printed:
            return
        self.monitor_header_printed = True
        self.logger.info(
            "APB_MON | %-4s | %-8s | %-5s | %-5s | %-8s | %-8s | %-7s | %-7s | %-7s | %-5s | %-5s | %-3s | %-6s | %-6s | %-6s | %-6s | %s",
            "TXN",
            "TIME",
            "RW",
            "SLAVE",
            "REQ_ADDR",
            "BUS_ADDR",
            "WR_DATA",
            "RD_DATA",
            "EXP",
            "PSEL1",
            "PSEL2",
            "PEN",
            "PWRITE",
            "PREADY",
            "PSLV",
            "STATUS",
            "NOTE",
        )

    def write_summary(self) -> None:
        path = Path(os.environ.get("APB_PYUVM_STATUS", "py_verification_apb/results/apb_pyuvm_status.json"))
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(
                {
                    "status": "PASS" if self.errors == 0 else "FAIL",
                    "checks": self.checks,
                    "errors": self.errors,
                    "transactions": self.transaction_count,
                    "test": self.__class__.__name__,
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
        self.logger.info("Wrote summary artifact: %s", path)


@cocotb.test()
async def apb_pyuvm_smoke(dut):
    cocotb.start_soon(Clock(dut.PCLK, 10, unit="ns").start())
    ConfigDB().set(None, "*", "dut", dut)
    await uvm_root().run_test("APBPyuvmSmokeTest", keep_set={ConfigDB})
