# APB Synthesis with SKY130 PDK

RTL-to-GDS flow for an AMBA APB (master + 2 slaves) design, targeting the
open **SKY130** PDK. Orchestrated end-to-end with `make`, using `igny`
(Crucible) to provide every EDA tool as a reproducible, versioned binding —
no local tool installs, no `PATH` fights.

## Flow stages

Each stage is a numbered directory with its own `Makefile`, driven from the
top-level `Makefile`:

| Stage | Directory | Tool(s) | Purpose |
|---|---|---|---|
| 1 | `00_lint` | `verilator` | RTL lint |
| 2 | `01_rtl` | — | RTL sources (`apb_protocol.v`, `master.v`, `slave1.v`, `slave2.v`) |
| 3 | `02_sim` | `iverilog` / `verilator` | Functional simulation |
| 4 | `03_verification` | `cocotb`, `pyuvm` | Python-based (co)testbench verification |
| 5 | `04_synthesis` | `yosys` | Logic synthesis against the SKY130 lib |
| 6 | `05_dft` | — | Design-for-test |
| 7 | `06_floorplanning` | `openroad` | Floorplan |
| 8 | `07_placement` | `openroad` | Placement |
| 9 | `08_sta` | `openroad` | Static timing analysis |
| 10 | `09_place_and_route` | `openroad` | CTS + routing |
| 11 | `10_gds` | `klayout-stream` | GDS streamout |
| 12 | `11_physical_verification` | `magic`, `netgen` | DRC, extraction, LVS |

## Running the flow

All commands run through `igny` inside the `amba_apb` Crucible environment
bound to this workspace (`crucible.toml`).

```bash
igny run make            # full flow: lint → sim → verify → synth → floorplan → place → cts → route → sta → gds → physical
igny run make lint       # 00_lint only
igny run make sim        # 02_sim only
igny run make verify     # 03_verification only
igny run make synth      # 04_synthesis only
igny run make dft        # 05_dft only
igny run make floorplan  # 06_floorplanning only
igny run make place      # 07_placement only
igny run make cts        # 09_place_and_route cts
igny run make route      # 09_place_and_route route
igny run make sta        # 08_sta only
igny run make gds        # 10_gds only
igny run make physical   # 11_physical_verification only
igny run make clean      # remove generated artifacts across all stages
```

## Reproducing the toolchain

Tool versions are pinned in `crucible.lock`. On another machine:

```bash
igny workspace sync   # installs + binds every tool in crucible.lock
igny status            # confirm environment + tool count
```

## Known issues

- **`igny tool install pyuvm` fails** with
  `unsupported operand type(s) for /: 'PosixPath' and 'NoneType'`.
  Root cause: the bundled `pyuvm.toml` registry entry has no `executable`
  under `[tool.pip]` (pyuvm is a library, not a CLI). Tracked as
  [IB-58](https://ignytion-io.atlassian.net/browse/IB-58). Until fixed
  upstream, verification work depending on `pyuvm` is blocked on this
  workspace unless a local user-registry override is applied.
