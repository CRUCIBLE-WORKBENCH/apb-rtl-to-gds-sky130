#!/usr/bin/env bash
# ===============================================================================
# Ignytion IO - CRUCIBLE CORE
# Copyright (c) 2026 Ignytion IO. All rights reserved.
# Author      : IGNYTION_TECH
# File        : apb_synthesis_with_sky130pdk/10_gds/run_gds_streamout.sh
# Created     : 2026-09-07
# Description : APB project source, configuration, or documentation file.
# ===============================================================================

# GDS streamout for APB_Protocol via KLayout's strm2gds (klayout-stream tool).
# Usage (WSL/igny, from the repo root):
#   igny init
#   export PDK_ROOT=<sky130A PDK root, containing libs.ref/...>
#   10_gds/run_gds_streamout.sh
#
# strm2gds reads the routed DEF directly, resolving each standard-cell
# instance's real mask geometry via the cell LEF's FOREIGN references
# against the PDK's real sky130_fd_sc_hd.gds -- this does NOT go through
# Magic (see README.md: the igny-packaged Magic has no Tcl support and
# can't be scripted -- IB-42). Confirmed live, 2026-09-03: produces a real
# GDS with the full routed hierarchy (APB_Protocol top cell, ~19.7k cell
# instances), not an empty/placeholder file.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
route_def="$project_root/09_place_and_route/route.def"
out_gds="$script_dir/APB_Protocol.gds"
layer_map="$script_dir/lefdef_layer_map.txt"

if [ -z "${PDK_ROOT:-}" ]; then
    echo "PDK_ROOT is not set. Example: export PDK_ROOT=/home/<you>/.ciel/ciel/sky130/versions/<hash>" >&2
    exit 1
fi

pdk="$PDK_ROOT/sky130A"
tech_lef="$pdk/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd.tlef"
cell_lef="$pdk/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef"
cell_gds="$pdk/libs.ref/sky130_fd_sc_hd/gds/sky130_fd_sc_hd.gds"

for f in "$route_def" "$tech_lef" "$cell_lef" "$cell_gds" "$layer_map"; do
    if [ ! -f "$f" ]; then
        echo "Missing required file: $f" >&2
        exit 1
    fi
done

echo "Streaming out GDS from routed DEF..."
# --lefdef-map pins top-level DEF geometry (routing + specialnets, i.e. the
# PDN) to the exact GDS layer/datatype numbers Magic's techfile expects.
# Without it, strm2gds invents its own small layer numbers for this
# geometry and Magic can't see any of it on readback -- see
# lefdef_layer_map.txt for the full story (confirmed live, 2026-09-08).
igny run klayout-stream strm2gds \
    --lefdef-lefs="$tech_lef,$cell_lef" \
    --lefdef-lef-layouts="$cell_gds" \
    --lefdef-map="$layer_map" \
    -d 10 \
    "$route_def" "$out_gds"

echo ""
echo "GDS written: $out_gds"
ls -la "$out_gds"
