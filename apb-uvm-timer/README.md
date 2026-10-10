# APB Timer — RTL & Verification

SystemVerilog APB-controlled 8-bit timer with a layered class-based testbench and a full UVM environment. The project covers RTL design of a free-running counter and APB register map, then verifies register access and timer behaviour with constrained-random and directed tests.

**RTL:** [`apb_timer_design.sv`](./apb_timer_design.sv) · **SV TB:** [`apb_sv_tb.sv`](./apb_sv_tb.sv) · **UVM TB:** [`apb_uvm_tb.sv`](./apb_uvm_tb.sv)

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

## Results

| Metric | Result |
|--------|--------|
| Functional coverage | **93.75%** |
| Constrained-random stimulus | **100+** transactions / tests across address and timer scenarios |
| Directed counter checks | Count / wrap / stop verified; count checks valid for expected count **> 2** |

Coverage includes write vs read, address bins (CTRL / LIMIT / COUNT / FLAG), data extremes (`0x00` / `0xFF`), and the write×address cross.

---

## Files

| File | Description |
|------|-------------|
| [`apb_timer_design.sv`](./apb_timer_design.sv) | `timer` + `apb_slave` RTL |
| [`apb_sv_tb.sv`](./apb_sv_tb.sv) | Class-based SystemVerilog testbench |
| [`apb_uvm_tb.sv`](./apb_uvm_tb.sv) | UVM package + testbench top |
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
