// Complete non-UVM SystemVerilog verification testbench
// Designed for a full SystemVerilog simulator such as Questa on EDA Playground.
// This file contains both the DUT and simulation-only testbench code.

`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// DUT: registered adder
// A valid input is accepted on a rising edge. The result appears one cycle later.
// -----------------------------------------------------------------------------
module registered_adder (
  input  logic       clk,
  input  logic       rst_n,
  input  logic       valid_i,
  input  logic [7:0] a_i,
  input  logic [7:0] b_i,
  output logic       valid_o,
  output logic [8:0] sum_o
);
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_o <= 1'b0;
      sum_o   <= '0;
    end
    else begin
      valid_o <= valid_i;
      if (valid_i)
        sum_o <= a_i + b_i;
    end
  end
endmodule

// -----------------------------------------------------------------------------
// Interface: one named bundle of DUT signals.
// The virtual interface lets class-based components access these signals.
// -----------------------------------------------------------------------------
interface adder_if (input logic clk);
  logic       rst_n;
  logic       valid_i;
  logic [7:0] a_i;
  logic [7:0] b_i;
  logic       valid_o;
  logic [8:0] sum_o;
endinterface

// -----------------------------------------------------------------------------
// Transaction: one meaningful operation rather than individual pin changes.
// -----------------------------------------------------------------------------
class add_txn;
  rand bit [7:0] a;
  rand bit [7:0] b;

  function void print(string who);
    $display("[%0t] %s: a=%0d (0x%02h), b=%0d (0x%02h), expected_sum=%0d",
             $time, who, a, a, b, b, a + b);
  endfunction
endclass

// -----------------------------------------------------------------------------
// Generator: creates transactions and sends their handles to the driver.
// It demonstrates both ordinary randomization and focused inline constraints.
// -----------------------------------------------------------------------------
class generator;
  mailbox #(add_txn) gen_to_drv;
  int unsigned       random_count;

  function new(mailbox #(add_txn) gen_to_drv, int unsigned random_count);
    this.gen_to_drv   = gen_to_drv;
    this.random_count = random_count;
  endfunction

  task run();
    add_txn tr;

    // General constrained-random traffic.
    repeat (random_count) begin
      tr = new();
      assert(tr.randomize())
        else $fatal(1, "Generator randomization failed");
      tr.print("GEN random");
      gen_to_drv.put(tr);
    end

    // Focused transactions help cover boundary-value bins deliberately.
    tr = new();
    assert(tr.randomize() with { a == 8'h00; b == 8'h00; })
      else $fatal(1, "Could not create zero boundary transaction");
    tr.print("GEN targeted");
    gen_to_drv.put(tr);

    tr = new();
    assert(tr.randomize() with { a == 8'hFF; b == 8'hFF; })
      else $fatal(1, "Could not create maximum boundary transaction");
    tr.print("GEN targeted");
    gen_to_drv.put(tr);
  endtask
endclass

// -----------------------------------------------------------------------------
// Driver: turns a high-level transaction into pin-level DUT activity.
// It drives on negative edges so the DUT can safely sample on positive edges.
// -----------------------------------------------------------------------------
class driver;
  virtual adder_if   vif;
  mailbox #(add_txn) gen_to_drv;

  function new(virtual adder_if vif, mailbox #(add_txn) gen_to_drv);
    this.vif        = vif;
    this.gen_to_drv = gen_to_drv;
  endfunction

  task run(int unsigned transaction_count);
    add_txn tr;

    repeat (transaction_count) begin
      gen_to_drv.get(tr);

      @(negedge vif.clk);
      vif.a_i     <= tr.a;
      vif.b_i     <= tr.b;
      vif.valid_i <= 1'b1;
      tr.print("DRV driving");

      // Keep this simple testbench to one accepted transaction per two cycles.
      @(negedge vif.clk);
      vif.valid_i <= 1'b0;
    end
  endtask
endclass

// -----------------------------------------------------------------------------
// Coverage collector: records the inputs ACTUALLY observed at the DUT interface.
// The monitor calls sample() after reconstructing an input transaction.
// -----------------------------------------------------------------------------
class coverage_collector;
  covergroup cg with function sample(bit [7:0] a, bit [7:0] b);
    a_cp: coverpoint a {
      bins zero  = {8'h00};
      bins max   = {8'hFF};
      bins other = default;
    }

    b_cp: coverpoint b {
      bins zero  = {8'h00};
      bins max   = {8'hFF};
      bins other = default;
    }

    a_x_b: cross a_cp, b_cp;
  endgroup

  function new();
    cg = new();
  endfunction

  function void report();
    $display("\n--- FUNCTIONAL COVERAGE ---");
    $display("a_cp coverage      = %0.2f%%", cg.a_cp.get_coverage());
    $display("b_cp coverage      = %0.2f%%", cg.b_cp.get_coverage());
    $display("a_x_b coverage     = %0.2f%%", cg.a_x_b.get_coverage());
    $display("Overall coverage   = %0.2f%%", cg.get_coverage());
  endfunction
endclass

// -----------------------------------------------------------------------------
// Monitor: observes DUT pins. It does NOT use what the generator intended.
// It sends expected results and actual DUT outputs to the scoreboard.
// -----------------------------------------------------------------------------
class monitor;
  virtual adder_if           vif;
  mailbox #(bit [8:0])      expected_mb;
  mailbox #(bit [8:0])      actual_mb;
  coverage_collector        cov;

  function new(
    virtual adder_if    vif,
    mailbox #(bit [8:0]) expected_mb,
    mailbox #(bit [8:0]) actual_mb,
    coverage_collector  cov
  );
    this.vif         = vif;
    this.expected_mb = expected_mb;
    this.actual_mb   = actual_mb;
    this.cov         = cov;
  endfunction

  task run();
    bit [8:0] expected_sum;

    forever begin
      @(posedge vif.clk);

      // valid_i and inputs were driven at the preceding negative edge.
      if (vif.valid_i) begin
        expected_sum = vif.a_i + vif.b_i;
        expected_mb.put(expected_sum);
        cov.cg.sample(vif.a_i, vif.b_i);
        $display("[%0t] MON input:  a=%0d b=%0d, expected=%0d",
                 $time, vif.a_i, vif.b_i, expected_sum);
      end

      // At this sampling point valid_o/sum_o represent the previous accepted input.
      if (vif.valid_o) begin
        actual_mb.put(vif.sum_o);
        $display("[%0t] MON output: sum=%0d", $time, vif.sum_o);
      end
    end
  endtask
endclass

// -----------------------------------------------------------------------------
// Scoreboard: compares observed output with the expected value in FIFO order.
// -----------------------------------------------------------------------------
class scoreboard;
  mailbox #(bit [8:0]) expected_mb;
  mailbox #(bit [8:0]) actual_mb;
  event                 done;
  int unsigned          pass_count;
  int unsigned          error_count;

  function new(
    mailbox #(bit [8:0]) expected_mb,
    mailbox #(bit [8:0]) actual_mb
  );
    this.expected_mb = expected_mb;
    this.actual_mb   = actual_mb;
  endfunction

  task run(int unsigned transaction_count);
    bit [8:0] expected;
    bit [8:0] actual;

    repeat (transaction_count) begin
      expected_mb.get(expected);
      actual_mb.get(actual);

      if (actual === expected) begin
        pass_count++;
        $display("[%0t] SCOREBOARD PASS: expected=%0d actual=%0d",
                 $time, expected, actual);
      end
      else begin
        error_count++;
        $error("[%0t] SCOREBOARD FAIL: expected=%0d actual=%0d",
               $time, expected, actual);
      end
    end

    $display("\n--- SCOREBOARD SUMMARY ---");
    $display("Passes = %0d", pass_count);
    $display("Errors = %0d", error_count);
    -> done;
  endtask
endclass

// -----------------------------------------------------------------------------
// Environment: creates and connects all verification components.
// This is the non-UVM ancestor of a uvm_env.
// -----------------------------------------------------------------------------
class environment;
  localparam int unsigned RANDOM_TRANSACTIONS = 12;
  localparam int unsigned TOTAL_TRANSACTIONS  = RANDOM_TRANSACTIONS + 2;

  virtual adder_if      vif;
  mailbox #(add_txn)    gen_to_drv;
  mailbox #(bit [8:0])  expected_mb;
  mailbox #(bit [8:0])  actual_mb;

  generator             gen;
  driver                drv;
  monitor               mon;
  scoreboard            sb;
  coverage_collector    cov;

  function new(virtual adder_if vif);
    this.vif = vif;

    gen_to_drv  = new();
    expected_mb = new();
    actual_mb   = new();

    cov = new();
    gen = new(gen_to_drv, RANDOM_TRANSACTIONS);
    drv = new(vif, gen_to_drv);
    mon = new(vif, expected_mb, actual_mb, cov);
    sb  = new(expected_mb, actual_mb);
  endfunction

  task run();
    fork
      gen.run();
      drv.run(TOTAL_TRANSACTIONS);
      mon.run();
      sb.run(TOTAL_TRANSACTIONS);
    join_none

    @sb.done;
    cov.report();

    if (sb.error_count == 0)
      $display("\nTEST PASSED");
    else
      $fatal(1, "TEST FAILED with %0d scoreboard errors", sb.error_count);
  endtask
endclass

// -----------------------------------------------------------------------------
// Top-level testbench: creates clock, reset, DUT, interface, and environment.
// -----------------------------------------------------------------------------
module tb;
  logic clk = 1'b0;
  environment env;

  always #5 clk = ~clk;

  adder_if vif(clk);

  registered_adder dut (
    .clk     (clk),
    .rst_n   (vif.rst_n),
    .valid_i (vif.valid_i),
    .a_i     (vif.a_i),
    .b_i     (vif.b_i),
    .valid_o (vif.valid_o),
    .sum_o   (vif.sum_o)
  );

  initial begin
    vif.rst_n   = 1'b0;
    vif.valid_i = 1'b0;
    vif.a_i     = '0;
    vif.b_i     = '0;

    repeat (2) @(posedge clk);
    vif.rst_n = 1'b1;
    $display("[%0t] Reset released", $time);

    env = new(vif);
    env.run();

    #1;
    $finish;
  end
endmodule
