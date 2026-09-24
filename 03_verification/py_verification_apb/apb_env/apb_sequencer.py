# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/03_verification/py_verification_apb/apb_env/apb_sequencer.py
# Created     : 2026-09-07
# Description : APB project source, configuration, or documentation file.
# ===============================================================================

"""apb_sequencer -- thin named subclass of uvm_sequencer; no APB-specific
behaviour is needed beyond what the base class already provides."""
from __future__ import annotations

from pyuvm import uvm_sequencer


class apb_sequencer(uvm_sequencer):
    pass
