# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/03_verification/py_verification_apb/apb_env/apb_env.py
# Created     : 2026-09-07
# Description : APB project source, configuration, or documentation file.
# ===============================================================================

"""apb_env -- composes the agent, the scoreboard, and the coverage collector.
The monitor's analysis port broadcasts to both subscribers -- scoreboard for
correctness checking, coverage for purely observational tracking. Neither
affects the other."""
from __future__ import annotations

from pyuvm import uvm_env

from .apb_agent import apb_agent
from .apb_coverage import apb_coverage
from .apb_scoreboard import apb_scoreboard


class apb_env(uvm_env):
    def build_phase(self):
        self.agent = apb_agent("agent", self)
        self.scoreboard = apb_scoreboard("scoreboard", self)
        self.coverage = apb_coverage("coverage", self)

    def connect_phase(self):
        self.agent.monitor.ap.connect(self.scoreboard.analysis_export)
        self.agent.monitor.ap.connect(self.coverage.analysis_export)
