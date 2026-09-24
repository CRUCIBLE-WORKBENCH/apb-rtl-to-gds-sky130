#!/usr/bin/env python3
# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/11_physical_verification/scripts/strip_power_pins.py
# Created     : 2026-09-08
# Description : Strip VPB/VNB/VPWR/VGND (power/body-tie) pins from a
#               Magic-extracted SPICE netlist before LVS, since
#               route_output.v never declares any of them.
# ===============================================================================
#
# route_output.v (the gate-level golden reference) never declares power or
# body-tie pins at all -- structural Verilog netlists don't model them. That
# makes every .subckt VPB/VNB pin position, and every instance's matching
# connection, dead weight for LVS: there is nothing on the other side to
# compare it against. Confirmed live, 2026-09-08 via netgen's -json badnets
# report: with real signal routing visible (see ../../10_gds/lefdef_layer_map.txt)
# and a real PDN + tap-cell substrate connectivity in place, VPB/VNB were the
# only remaining mismatch -- until stripping them exposed the identical
# problem one layer down for VPWR/VGND: route_output.v generates a fresh
# "dummy_N / proxyVPWR" placeholder net per instance for those too (it
# never models supply pins either), while the real layout correctly merges
# them into one clean global net via the PDN (see
# ../../06_floorplanning/openroad_floorplan.tcl). All four power-related
# pins share the same root cause and the same fix: neither side ever
# modeled them meaningfully, so remove them from circuit1's pin lists
# instead of trying to match noise against noise.

import sys

POWER_PINS = ("VPB", "VNB", "VPWR", "VGND")


def get_subckt_pin_indices(text: str) -> dict:
    result = {}
    for line in text.split("\n"):
        if line.strip().upper().startswith(".SUBCKT"):
            parts = line.split()
            name = parts[1]
            pins = parts[2:]
            result[name] = {i for i, p in enumerate(pins) if p in POWER_PINS}
    return result


def strip_instance_connections(text: str, subckt_pin_indices: dict) -> str:
    lines = text.split("\n")
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if line.startswith("X"):
            stmt_lines = [line]
            j = i + 1
            while j < len(lines) and lines[j].startswith("+"):
                stmt_lines.append(lines[j])
                j += 1
            first_tokens = stmt_lines[0].split()
            inst_name = first_tokens[0]
            tokens = first_tokens[1:]
            for cont in stmt_lines[1:]:
                tokens.extend(cont.split()[1:])
            subckt_name = tokens[-1]
            net_tokens = tokens[:-1]
            drop = subckt_pin_indices.get(subckt_name, set())
            new_nets = [t for idx, t in enumerate(net_tokens) if idx not in drop]
            new_tokens = [inst_name] + new_nets + [subckt_name]
            out.append(new_tokens[0] + " " + " ".join(new_tokens[1:5]))
            rest = new_tokens[5:]
            while rest:
                chunk, rest = rest[:4], rest[4:]
                out.append("+ " + " ".join(chunk))
            i = j
            continue
        out.append(line)
        i += 1
    return "\n".join(out)


def strip_subckt_headers(text: str) -> tuple[str, set]:
    """Strip power pins from .subckt headers; return the set of subckt
    names left with zero pins (e.g. decap_4, which only ever had VPWR/VGND)."""
    lines = text.split("\n")
    out = []
    zero_pin = set()
    for line in lines:
        if line.strip().upper().startswith(".SUBCKT"):
            parts = line.split()
            name = parts[1]
            new_pins = [p for p in parts[2:] if p not in POWER_PINS]
            if not new_pins:
                zero_pin.add(name)
            out.append(" ".join(parts[:2] + new_pins))
        else:
            out.append(line)
    return "\n".join(out), zero_pin


def remove_zero_pin_cells(text: str, zero_pin: set) -> str:
    """Netgen segfaults on a cell with no pins (a known upstream bug --
    see RTimothyEdwards/netgen changelog rev 312, "segfault ... when a
    cell has no pins"). A subckt reduced to zero pins by the power-pin
    strip above (decap_4: only ever had VPWR/VGND, no signal pins) has
    nothing left to verify anyway, so drop its .subckt definition and
    every instance of it outright rather than leave a dangling crash
    trigger. Confirmed live, 2026-09-08 -- this was the actual cause of
    netgen's SIGSEGV immediately after printing a device/net count that
    already matched exactly between layout and netlist."""
    if not zero_pin:
        return text
    lines = text.split("\n")
    out = []
    i = 0
    in_dead_subckt = False
    while i < len(lines):
        line = lines[i]
        if line.strip().upper().startswith(".SUBCKT"):
            name = line.split()[1]
            if name in zero_pin:
                in_dead_subckt = True
                i += 1
                continue
        if in_dead_subckt:
            if line.strip().upper().startswith(".ENDS"):
                in_dead_subckt = False
            i += 1
            continue
        if line.startswith("X"):
            stmt_lines = [line]
            j = i + 1
            while j < len(lines) and lines[j].startswith("+"):
                stmt_lines.append(lines[j])
                j += 1
            tokens = stmt_lines[0].split()[1:]
            for cont in stmt_lines[1:]:
                tokens.extend(cont.split()[1:])
            subckt_name = tokens[-1] if tokens else ""
            if subckt_name in zero_pin:
                i = j
                continue
            out.extend(stmt_lines)
            i = j
            continue
        out.append(line)
        i += 1
    return "\n".join(out)


def main():
    src, dst = sys.argv[1], sys.argv[2]
    with open(src) as f:
        text = f.read()
    pin_indices = get_subckt_pin_indices(text)
    text = strip_instance_connections(text, pin_indices)
    text, zero_pin = strip_subckt_headers(text)
    text = remove_zero_pin_cells(text, zero_pin)
    with open(dst, "w") as f:
        f.write(text)
    print(f"Stripped power pins from {len(pin_indices)} subckt definitions -> {dst}")
    if zero_pin:
        print(f"Removed {len(zero_pin)} now-zero-pin cell(s) entirely: {sorted(zero_pin)}")


if __name__ == "__main__":
    main()
