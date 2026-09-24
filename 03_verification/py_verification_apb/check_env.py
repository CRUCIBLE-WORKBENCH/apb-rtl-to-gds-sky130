# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/03_verification/py_verification_apb/check_env.py
# Created     : 2026-09-07
# Description : APB project source, configuration, or documentation file.
# ===============================================================================

"""Check the APB Python verification environment under Crucible."""
from __future__ import annotations

import importlib.util
import shutil


def report(name: str, ok: bool, detail: str = "") -> None:
    suffix = f" ({detail})" if detail else ""
    print(f"{name}: {'OK' if ok else 'MISSING'}{suffix}")


def main() -> int:
    for module in ("cocotb", "cocotb_tools.runner", "pyuvm"):
        spec = importlib.util.find_spec(module)
        report(module, spec is not None, spec.origin if spec else "")

    for binary in ("iverilog", "vvp", "make"):
        path = shutil.which(binary)
        report(binary, path is not None, path or "")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
