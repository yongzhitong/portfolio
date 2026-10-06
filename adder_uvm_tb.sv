`timescale 1ns/1ps

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
    end else begin
      valid_o <= valid_i;
      if (valid_i)
        sum_o <= a_i + b_i;
    end
  end
endmodule

interface adder_if (input logic clk);
  logic       rst_n;
  logic       valid_i;
  logic [7:0] a_i;
  logic [7:0] b_i;
  logic       valid_o;
  logic [8:0] sum_o;

  // The monitor samples in the preponed region, before DUT nonblocking
  // assignments update valid_o and sum_o at this clock edge.
  clocking mon_cb @(posedge clk);
    default input #1step;
    input rst_n, valid_i, a_i, b_i, valid_o, sum_o;
  endclocking
endinterface

package adder_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `uvm_analysis_imp_decl(_expected)
  `uvm_analysis_imp_decl(_actual)

  // SystemVerilog testbench role -> UVM class in this file:
  //   transaction          -> add_item
  //   generator            -> add_sequence
  //   (no SV equivalent)   -> add_sequencer   sits between generator and driver
  //   driver               -> add_driver
  //   monitor              -> add_monitor
  //   (no SV equivalent)   -> add_agent       groups sequencer + driver + monitor
  //   scoreboard           -> add_scoreboard
  //   coverage collector   -> add_coverage
  //   environment          -> add_env
  //   test                 -> adder_test

  // TRANSACTION — the packet that carries a and b.
  class add_item extends uvm_sequence_item;
    rand bit [7:0] a;
    rand bit [7:0] b;

    `uvm_object_utils_begin(add_item)
      `uvm_field_int(a, UVM_ALL_ON)
      `uvm_field_int(b, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "add_item");
      super.new(name);
    endfunction
  endclass

  // GENERATOR — creates transactions and hands them to the sequencer.
  // It does not drive DUT pins.
  class add_sequence extends uvm_sequence #(add_item);
    `uvm_object_utils(add_sequence)
    localparam int unsigned RANDOM_TRANSACTIONS = 12;

    function new(string name = "add_sequence");
      super.new(name);
    endfunction

    task body();
      add_item req;

      repeat (RANDOM_TRANSACTIONS) begin
        req = add_item::type_id::create("random_req");
        start_item(req);
        assert(req.randomize()) else `uvm_fatal("RAND", "Randomization failed")
        finish_item(req);
      end

      req = add_item::type_id::create("zero_req");
      start_item(req);
      assert(req.randomize() with { a == 8'h00; b == 8'h00; })
        else `uvm_fatal("RAND", "Zero transaction randomization failed")
      finish_item(req);

      req = add_item::type_id::create("max_req");
      start_item(req);
      assert(req.randomize() with { a == 8'hFF; b == 8'hFF; })
        else `uvm_fatal("RAND", "Maximum transaction randomization failed")
      finish_item(req);
    endtask
  endclass

  // SEQUENCER — mailbox between the generator and the driver.
  // The generator runs on this; the driver pulls items from it.
  class add_sequencer extends uvm_sequencer #(add_item);
    `uvm_component_utils(add_sequencer)
    function new(string name = "add_sequencer", uvm_component parent = null);
      super.new(name, parent);
    endfunction
  endclass

  // DRIVER — pulls a transaction and drives a_i, b_i, and valid_i.
  class add_driver extends uvm_driver #(add_item);
    `uvm_component_utils(add_driver)
    virtual adder_if vif;

    function new(string name = "add_driver", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual adder_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "Driver could not get virtual interface")
    endfunction

    task run_phase(uvm_phase phase);
      add_item req;
      vif.valid_i <= 1'b0;
      wait (vif.rst_n === 1'b1);

      forever begin
        seq_item_port.get_next_item(req);
        @(negedge vif.clk);
        vif.a_i     <= req.a;
        vif.b_i     <= req.b;
        vif.valid_i <= 1'b1;
        `uvm_info("DRV", $sformatf("Driving a=%0d b=%0d", req.a, req.b), UVM_MEDIUM)

        // The DUT accepts this request here.  Deasserting valid immediately
        // afterward prevents the final request from being accepted repeatedly.
        @(posedge vif.clk);
        vif.valid_i <= 1'b0;
        seq_item_port.item_done();
      end
    endtask
  endclass

  // MONITOR — watches the pins and broadcasts what it sees.
  // It never drives the DUT. Scoreboard and coverage subscribe to it.
  class add_monitor extends uvm_component;
    `uvm_component_utils(add_monitor)
    virtual adder_if vif;

    uvm_analysis_port #(add_item)   input_ap;
    uvm_analysis_port #(bit [8:0])  expected_ap;
    uvm_analysis_port #(bit [8:0])  actual_ap;

    function new(string name = "add_monitor", uvm_component parent = null);
      super.new(name, parent);
      input_ap    = new("input_ap", this);
      expected_ap = new("expected_ap", this);
      actual_ap   = new("actual_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual adder_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "Monitor could not get virtual interface")
    endfunction

    task run_phase(uvm_phase phase);
      add_item observed;
      bit [8:0] expected_sum;
      wait (vif.rst_n === 1'b1);

      forever begin
        @(vif.mon_cb);
        if (vif.mon_cb.valid_i) begin
          observed = add_item::type_id::create("observed_input");
          observed.a = vif.mon_cb.a_i;
          observed.b = vif.mon_cb.b_i;
          expected_sum = observed.a + observed.b;
          input_ap.write(observed);
          expected_ap.write(expected_sum);
          `uvm_info("MON", $sformatf("Input: a=%0d b=%0d expected=%0d",
                    observed.a, observed.b, expected_sum), UVM_MEDIUM)
        end

        if (vif.mon_cb.valid_o) begin
          actual_ap.write(vif.mon_cb.sum_o);
          `uvm_info("MON", $sformatf("Output: sum=%0d", vif.mon_cb.sum_o), UVM_MEDIUM)
        end
      end
    endtask
  endclass

  // AGENT — one interface's sequencer, driver, and monitor, built together.
  class add_agent extends uvm_agent;
    `uvm_component_utils(add_agent)
    add_sequencer seqr;
    add_driver    drv;
    add_monitor   mon;

    function new(string name = "add_agent", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      seqr = add_sequencer::type_id::create("seqr", this);
      drv  = add_driver::type_id::create("drv", this);
      mon  = add_monitor::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction
  endclass

  // SCOREBOARD — compares the expected sum with the DUT sum.
  class add_scoreboard extends uvm_component;
    `uvm_component_utils(add_scoreboard)
    uvm_tlm_analysis_fifo #(bit [8:0]) expected_fifo;
    uvm_tlm_analysis_fifo #(bit [8:0]) actual_fifo;
    uvm_event done;
    int unsigned pass_count;
    int unsigned error_count;
    int unsigned expected_count = 14;

    function new(string name = "add_scoreboard", uvm_component parent = null);
      super.new(name, parent);
      done = new("done");
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      expected_fifo = new("expected_fifo", this);
      actual_fifo   = new("actual_fifo", this);
      void'(uvm_config_db#(int unsigned)::get(this, "", "expected_count", expected_count));
    endfunction

    task run_phase(uvm_phase phase);
      bit [8:0] expected, actual;
      repeat (expected_count) begin
        expected_fifo.get(expected);
        actual_fifo.get(actual);
        if (actual === expected) begin
          pass_count++;
          `uvm_info("SB", $sformatf("PASS: expected=%0d actual=%0d", expected, actual), UVM_LOW)
        end else begin
          error_count++;
          `uvm_error("SB", $sformatf("FAIL: expected=%0d actual=%0d", expected, actual))
        end
      end
      done.trigger();
    endtask

    function void report_phase(uvm_phase phase);
      `uvm_info("SB", $sformatf("Summary: passes=%0d errors=%0d", pass_count, error_count), UVM_NONE)
    endfunction
  endclass

  // COVERAGE COLLECTOR — samples functional coverage on observed a and b.
  class add_coverage extends uvm_subscriber #(add_item);
    `uvm_component_utils(add_coverage)

    covergroup cg with function sample(bit [7:0] a, bit [7:0] b);
      a_cp: coverpoint a { bins zero = {8'h00}; bins max = {8'hFF}; bins other = default; }
      b_cp: coverpoint b { bins zero = {8'h00}; bins max = {8'hFF}; bins other = default; }
      a_x_b: cross a_cp, b_cp;
    endgroup

    function new(string name = "add_coverage", uvm_component parent = null);
      super.new(name, parent);
      cg = new();
    endfunction

    function void write(add_item t);
      cg.sample(t.a, t.b);
    endfunction

    function void report_phase(uvm_phase phase);
      `uvm_info("COV", $sformatf("Overall functional coverage = %0.2f%%", cg.get_coverage()), UVM_NONE)
    endfunction
  endclass

  // ENVIRONMENT — builds the agent, scoreboard, and coverage, then connects them.
  class add_env extends uvm_env;
    `uvm_component_utils(add_env)
    add_agent      agent;
    add_scoreboard sb;
    add_coverage   cov;

    function new(string name = "add_env", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      agent = add_agent::type_id::create("agent", this);
      sb    = add_scoreboard::type_id::create("sb", this);
      cov   = add_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      agent.mon.expected_ap.connect(sb.expected_fifo.analysis_export);
      agent.mon.actual_ap.connect(sb.actual_fifo.analysis_export);
      agent.mon.input_ap.connect(cov.analysis_export);
    endfunction
  endclass

  // TEST — applies reset, starts the generator, waits for the scoreboard.
  class adder_test extends uvm_test;
    `uvm_component_utils(adder_test)
    virtual adder_if vif;
    add_env env;

    function new(string name = "adder_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual adder_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "Test could not get virtual interface")
      uvm_config_db#(int unsigned)::set(this, "env.sb", "expected_count", 14);
      env = add_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
      add_sequence seq;
      phase.raise_objection(this);

      vif.rst_n   <= 1'b0;
      vif.valid_i <= 1'b0;
      vif.a_i     <= '0;
      vif.b_i     <= '0;
      repeat (2) @(posedge vif.clk);
      vif.rst_n <= 1'b1;
      `uvm_info("TEST", "Reset released", UVM_LOW)

      seq = add_sequence::type_id::create("seq");
      seq.start(env.agent.seqr);
      env.sb.done.wait_trigger();

      if (env.sb.error_count != 0)
        `uvm_error("TEST", $sformatf("Test completed with %0d errors", env.sb.error_count))
      else
        `uvm_info("TEST", "TEST PASSED", UVM_NONE)
      phase.drop_objection(this);
    endtask
  endclass
endpackage

// TOP-LEVEL HARNESS — clock, interface, DUT, and the call that starts UVM.
module tb;
  import uvm_pkg::*;
  import adder_uvm_pkg::*;

  logic clk = 1'b0;
  always #5 clk = ~clk;

  adder_if vif(clk);

  registered_adder dut (
    .clk(clk), .rst_n(vif.rst_n), .valid_i(vif.valid_i),
    .a_i(vif.a_i), .b_i(vif.b_i), .valid_o(vif.valid_o), .sum_o(vif.sum_o)
  );

  initial begin
    uvm_config_db#(virtual adder_if)::set(null, "*", "vif", vif);
    run_test("adder_test");
  end
endmodule
