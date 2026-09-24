# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/03_verification/py_verification_apb/run_apb_pyuvm.py
# Created     : 2026-09-07
# Description : APB project source, configuration, or documentation file.
# ===============================================================================

"""Run the APB cocotb/pyuvm smoke test with Icarus.

The script writes a small JSON status file even when dependencies are missing,
so setup gaps are explicit and easy to fix.
"""
from __future__ import annotations

import importlib.util
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent
PROJECT_ROOT = ROOT.parent
REPO_ROOT = PROJECT_ROOT.parent
RESULTS_DIR = ROOT / "results"
STATUS_PATH = RESULTS_DIR / "apb_pyuvm_status.json"


def write_status(status: str, **details: object) -> None:
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    payload = {"status": status, **details}
    STATUS_PATH.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"[artifact] {STATUS_PATH}")


def missing_modules() -> list[str]:
    return [
        module
        for module in ("cocotb", "pyuvm")
        if importlib.util.find_spec(module) is None
    ]


def crucible_iverilog_paths() -> list[Path]:
    tool_root = Path.home() / "Crucible" / "tools" / "iverilog"
    if not tool_root.exists():
        return []

    candidates: list[Path] = []
    for version_dir in sorted(tool_root.iterdir(), reverse=True):
        bin_dir = version_dir / "iverilog" / "bin"
        lib_dir = version_dir / "iverilog" / "lib"
        tool_bin_dir = version_dir / "tool_bin"
        if (bin_dir / "iverilog.exe").exists():
            candidates.extend([bin_dir, lib_dir, tool_bin_dir])
            break
    return [path for path in candidates if path.exists()]


def prepare_sim_env() -> dict[str, str]:
    env = os.environ.copy()
    env["APB_PYUVM_STATUS"] = str(STATUS_PATH)
    env["PYTHONPATH"] = str(ROOT) + os.pathsep + str(PROJECT_ROOT) + os.pathsep + env.get("PYTHONPATH", "")
    tool_paths = [str(path) for path in crucible_iverilog_paths()]
    if tool_paths:
        env["PATH"] = os.pathsep.join(tool_paths + [env.get("PATH", "")])
    return env


def prepare_python_path() -> None:
    """Expose the project package to cocotb's embedded Python interpreter."""
    project_root = str(PROJECT_ROOT)
    if project_root not in sys.path:
        sys.path.insert(0, project_root)


def validate_results(results_xml: Path) -> int:
    from cocotb_tools.runner import get_results

    try:
        num_tests, num_failed = get_results(results_xml)
    except (OSError, RuntimeError) as exc:
        write_status(
            "FAIL",
            reason="missing_or_invalid_cocotb_results",
            results_xml=str(results_xml),
            error=str(exc),
        )
        return 1

    if num_tests == 0 or num_failed:
        write_status(
            "FAIL",
            reason="cocotb_test_failure",
            tests=num_tests,
            failures=num_failed,
            results_xml=str(results_xml),
        )
        return 1

    try:
        status = json.loads(STATUS_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        write_status(
            "FAIL",
            reason="missing_or_invalid_pyuvm_status",
            results_xml=str(results_xml),
            error=str(exc),
        )
        return 1

    if status.get("status") != "PASS":
        write_status(
            "FAIL",
            reason="pyuvm_status_not_pass",
            pyuvm_status=status,
            results_xml=str(results_xml),
        )
        return 1
    return 0


def run_with_make() -> int:
    if shutil.which("make") is None:
        write_status(
            "GATED",
            reason="missing_make",
            install="igny tool install make",
        )
        print("GATED: make was not found on PATH")
        return 0

    write_status(
        "RUNNING",
        simulator="icarus",
        runner="cocotb_makefile",
        build_dir=str(ROOT / "sim_build"),
    )
    completed = subprocess.run(
        ["make", "-C", str(ROOT), "sim"],
        env=prepare_sim_env(),
        check=False,
    )
    if completed.returncode != 0:
        write_status(
            "FAIL",
            reason="cocotb_make_failed",
            exit_code=completed.returncode,
        )
    return completed.returncode


def main() -> int:
    missing = missing_modules()
    if missing:
        write_status(
            "GATED",
            reason="missing_python_packages",
            missing=missing,
            install="python -m pip install -r py_verification_apb/requirements.txt",
        )
        print(f"GATED: missing Python package(s): {', '.join(missing)}")
        return 0

    sim_env = prepare_sim_env()

    if shutil.which("iverilog", path=sim_env.get("PATH")) is None:
        write_status(
            "GATED",
            reason="missing_simulator",
            simulator="iverilog",
            install="igny tool install iverilog",
        )
        print("GATED: iverilog was not found on PATH")
        return 0

    rtl_dir = REPO_ROOT / "01_rtl"
    build_dir = ROOT / "sim_build"

    if importlib.util.find_spec("cocotb_tools.runner") is None:
        print("cocotb_tools.runner is unavailable; falling back to cocotb Makefile flow")
        return run_with_make()

    from cocotb_tools.runner import get_runner

    os.environ.update(sim_env)
    prepare_python_path()
    runner = get_runner("icarus")
    runner.build(
        sources=[rtl_dir / "apb_protocol.v"],
        includes=[rtl_dir],
        hdl_toplevel="APB_Protocol",
        build_dir=build_dir,
        always=True,
        waves=True,
    )

    write_status("RUNNING", simulator="icarus", build_dir=str(build_dir))
    results_xml = runner.test(
        hdl_toplevel="APB_Protocol",
        test_module="py_verification_apb.tests.test_apb_pyuvm",
        build_dir=build_dir,
        waves=True,
    )
    return validate_results(results_xml)


if __name__ == "__main__":
    raise SystemExit(main())
