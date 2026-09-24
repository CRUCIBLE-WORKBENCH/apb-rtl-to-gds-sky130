# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/03_verification/py_verification_apb/apb_env/__init__.py
# Created     : 2026-09-07
# Description : APB project source, configuration, or documentation file.
# ===============================================================================

"""UVM-style verification environment for APB_Protocol.

sequence item -> sequence -> sequencer -> driver -> monitor -> agent
-> scoreboard -> env -> test.

Ports driven on the DUT match the custom APB_Protocol wrapper interface
(transfer, READ_WRITE, apb_write_paddr, apb_write_data, apb_read_paddr,
apb_read_data_out, PSLVERR) -- not a standard APB PSEL/PENABLE/PADDR
boundary, since that is what the RTL under test exposes at its top level.
"""
