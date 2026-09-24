# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/03_verification/py_verification_apb/apb_env/apb_agent.py
# Created     : 2026-09-07
# Description : APB project source, configuration, or documentation file.
# ===============================================================================

"""apb_agent -- composes sequencer + driver + monitor, connects the driver
to the sequencer's export."""
from __future__ import annotations

from pyuvm import uvm_agent

from .apb_driver import apb_driver
from .apb_monitor import apb_monitor
from .apb_sequencer import apb_sequencer


class apb_agent(uvm_agent):
    def build_phase(self):
        self.sequencer = apb_sequencer("sequencer", self)
        self.driver = apb_driver("driver", self)
        self.monitor = apb_monitor("monitor", self)

    def connect_phase(self):
        self.driver.seq_item_port.connect(self.sequencer.seq_item_export)
