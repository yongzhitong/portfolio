# APB Timer — RTL, UVM & Formal Verification

SystemVerilog APB-controlled 8-bit timer verified through a layered class-based testbench, a full UVM environment, and formal property checking. The project combines constrained-random simulation and functional coverage with induction proofs and cover reachability analysis.

**RTL:** [`apb_timer_design.sv`](./apb_timer_design.sv) · **SV TB:** [`apb_sv_tb.sv`](./apb_sv_tb.sv) · **UVM TB:** [`apb_uvm_tb.sv`](./apb_uvm_tb.sv) · **Formal harness:** [`apb_timer_formal.sv`](./apb_timer_formal.sv) · **[Prove](./apb_timer_fv_prove.sby)** / **[Cover](./apb_timer_fv_cover.sby)**

---

## Design overview

```text
APB Master (TB)          APB Slave                    Timer
─────────────────        ─────────────────────        ──────────────
paddr / psel /           ctrl_reg  [0x0]  ──enable──► count++
penable / pwrite /       limit_reg [0x4]  ──limit───► wrap + flag
pwdata / prdata  ◄─────  count_reg [0x8]  ◄──count──
                         flag_reg  [0xC]  ◄──flag───
```

The DUT is split into two modules:

1. **`timer`** — counting / wrap / flag logic  
2. **`apb_slave`** — APB decode, register file, and glue to the timer  

---

## RTL — timer counter

[`timer`](./apb_timer_design.sv) is an 8-bit up-counter with programmable limit and a one-cycle wrap flag.

| Signal   | Role                                      |
|----------|-------------------------------------------|
| `enable` | From `ctrl_reg[0]`; freezes counting when low |
| `limit`  | Wrap value from `limit_reg`               |
| `count`  | Current count (readable over APB)         |
| `flag`   | Pulses high for one cycle when `count == limit` |

Behaviour:

- On reset: `count = 0`, `flag = 0`
- While disabled: `flag` cleared; count holds
- While enabled: `count` increments each clock
- When `count == limit`: `count` clears to 0 and `flag` asserts for that cycle

---

## RTL — APB address map

[`apb_slave`](./apb_timer_design.sv) implements a simple APB3-style slave (setup then access via `psel` / `penable`). Word-aligned 4-bit addresses select four registers:

| Address | Register   | Access | Description                          |
|---------|------------|--------|--------------------------------------|
| `0x0`   | CTRL       | R/W    | Bit 0 enables the timer              |
| `0x4`   | LIMIT      | R/W    | Wrap limit for the counter           |
| `0x8`   | COUNT      | R      | Live count from the timer            |
| `0xC`   | FLAG       | R      | Wrap flag from the timer             |

**Writes** (`psel && penable && pwrite`): data from `pwdata` is latched into CTRL or LIMIT. COUNT and FLAG are not software-writable.

**Reads** (`psel && penable && !pwrite`): `prdata` muxes the selected register. Unmapped addresses return `0`.

The timer instance is hard-wired as:

```text
enable = ctrl_reg[0]
limit  = limit_reg
count  → count_reg
flag   → flag_reg
```

---

## SystemVerilog testbench (`apb_sv_tb.sv`)

Class-based, mailbox-driven environment (no UVM). Same roles as a typical UVM agent, built by hand:

| Component | Role |
|-----------|------|
| `apb_txn` | Randomisable transaction (`write`, `addr`, `data_in`) with valid-address constraint |
| `generator` | Builds random write/read pairs and directed timer sequences |
| `driver` | Drives APB setup/access cycles on the virtual interface |
| `monitor` | Samples writes/reads; feeds scoreboard mailboxes and coverage |
| `scoreboard` | Checks readback vs written data; checks flag / count / stop behaviour |
| `coverage_collector` | Coverpoints on write/read, address, data, and write×addr cross |
| `environment` | Wires components and runs the test plan |

### Test plan

1. **APB address tests** — constrained-random writes to CTRL/LIMIT, immediate readback of the same address (register R/W check).  
2. **Counter cycle** — random LIMIT, enable, wait `limit` clocks, read FLAG (expect wrap).  
3. **Counter count** — fixed LIMIT = 255, enable, wait *N* clocks, read COUNT (expect *N*). Verified for count values **> 2**.  
4. **Counter stop** — enable, count for *N* clocks, disable, wait extra cycles, read COUNT (expect count frozen near *N*).  
5. **Full wrap after live LIMIT update** — begin with LIMIT = 255, write a new LIMIT below the current COUNT, verify `0xFF → 0x00`, then verify the counter reaches the new LIMIT and wraps with FLAG asserted.

Each phase is separated by a short reset so state does not bleed between scenarios.

---

## UVM testbench (`apb_uvm_tb.sv`)

The same scenarios are reimplemented with a standard UVM stack inside `apb_uvm_pkg`:

```text
apb_test
  └── apb_env
        ├── apb_agent
        │     ├── apb_sequencer
        │     ├── apb_driver
        │     └── apb_monitor ──analysis ports──► scoreboard / coverage
        ├── apb_scoreboard
        └── apb_coverage_collector
```

| SV TB concept | UVM equivalent |
|---------------|----------------|
| `apb_txn` | `apb_txn` (`uvm_sequence_item`) |
| `generator` tasks | Sequences (`apb_address_sequence`, `counter_*_sequence`) |
| `driver` | `apb_driver` (`uvm_driver`) |
| `monitor` + mailboxes | `apb_monitor` + analysis ports / TLM FIFOs |
| `scoreboard` | `apb_scoreboard` |
| `coverage_collector` | `apb_coverage_collector` (`uvm_subscriber`) |
| `environment` | `apb_env` |
| top-level stimulus | `apb_test` (`run_test`) |

Sequences reuse helpers (activate / set limit / read count / read flag / deactivate). The driver performs the same two-phase APB handshake. The scoreboard waits on per-test end flags from the interface, then compares expected vs actual results. Functional coverage is sampled on every observed transaction via the monitor analysis port.

---

## Formal verification (`apb_timer_formal.sv`)

The formal flow uses SymbiYosys with Yosys SMTBMC and the Boolector solver. The harness constrains reset sequencing, legal APB addresses, and writable-register accesses, then checks the design with immediate `assume`, `assert`, and `cover` statements.

| Property group | Checks |
|----------------|--------|
| APB outputs | `prdata` is zero during writes and outside valid read accesses |
| Register access | CTRL and LIMIT writes update the correct register; all four addresses return the selected register |
| Counter safety | Disabled count holds; enabled count increments; reaching LIMIT wraps the count and raises FLAG |
| Reachability | Enable, flag assertion/readback, write-then-read, counter hold, live LIMIT changes, and full 8-bit wrap |

Two independent tasks keep proof and reachability results distinct:

- [`apb_timer_fv_prove.sby`](./apb_timer_fv_prove.sby) runs a depth-30 base case and induction step. Both passed, giving a successful proof by k-induction.
- [`apb_timer_fv_cover.sby`](./apb_timer_fv_cover.sby) runs cover reachability to depth 270. All 11 covers were reached, including the complete `0xFF → 0x00` counter wrap at step 261.

The long full-wrap cover demonstrates end-to-end reachability from reset, while induction checks the counter and APB safety properties without requiring a 256-cycle simulation trace.

---

## Results

| Metric | Result |
|--------|--------|
| Functional coverage | **93.75%** |
| Constrained-random stimulus | **100+** transactions / tests across address and timer scenarios |
| Directed counter checks | Count / wrap / stop verified; count checks valid for expected count **> 2** |
| Formal proof | **PASS** — base case and induction, depth 30 |
| Formal cover | **PASS** — all 11 covers reached, depth 270 |
| Full 8-bit wrap witness | Reached at formal step **261** |
| Full-wrap UVM simulation | **0 errors / warnings** — 5305 ns simulated in 16 seconds |
| Directed simulation vs deep cover | Approximately **165× faster** for this specific scenario |

Coverage includes write vs read, address bins (CTRL / LIMIT / COUNT / FLAG), data extremes (`0x00` / `0xFF`), and the write×address cross.

The timing comparison is not a comparison of equivalent guarantees: the UVM test efficiently checks one directed sequence, whereas the formal run explores legal behaviours and establishes broader reachability and safety results.

---

## Files

| File | Description |
|------|-------------|
| [`apb_timer_design.sv`](./apb_timer_design.sv) | `timer` + `apb_slave` RTL |
| [`apb_timer_design2.sv`](./apb_timer_design2.sv) | RTL variant exposing internal registers to the formal harness |
| [`apb_sv_tb.sv`](./apb_sv_tb.sv) | Class-based SystemVerilog testbench |
| [`apb_uvm_tb.sv`](./apb_uvm_tb.sv) | UVM package + testbench top |
| [`apb_timer_formal.sv`](./apb_timer_formal.sv) | Formal assumptions, assertions, and cover statements |
| [`apb_timer_fv_prove.sby`](./apb_timer_fv_prove.sby) | SymbiYosys k-induction configuration |
| [`apb_timer_fv_cover.sby`](./apb_timer_fv_cover.sby) | SymbiYosys cover-reachability configuration |
| [`adder_sv_tb.sv`](./adder_sv_tb.sv) / [`adder_uvm_tb.sv`](./adder_uvm_tb.sv) | Earlier adder bring-up TBs (SV → UVM learning path) |

---

## How to run

Use a SystemVerilog simulator with UVM support (e.g. Questa, Xcelium, VCS, or EDA Playground).

**Class-based SV TB** (compile design + TB):

```text
apb_timer_design.sv  apb_sv_tb.sv
```

**UVM TB** (compile design + TB, then run test `apb_test`):

```text
apb_timer_design.sv  apb_uvm_tb.sv
+UVM_TESTNAME=apb_test
```

Exact compile/elab/simulate flags depend on the tool; ensure `uvm_pkg` is on the include path for the UVM flow.

**Formal proof and cover** (requires SymbiYosys, Yosys SMTBMC, and Boolector):

```text
sby -f apb_timer_fv_prove.sby
sby -f apb_timer_fv_cover.sby
```
