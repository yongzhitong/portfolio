//interface

interface apb_master (input logic clk);
    logic rst;
    logic psel;
    logic penable;
    logic pwrite;
    logic [3:0] paddr;
    logic [7:0] pwdata;
    logic [7:0] prdata;
    logic address_test_end;
    logic cycle_test_end;
    logic count_test_end;
    logic stop_test_end;
endinterface

package apb_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    //transaction
    class apb_txn extends uvm_sequence_item;
        bit write;
        rand bit [3:0] addr;
        rand bit [7:0] data_in;
        bit [7:0] data_out;


        //uvm registering + turning all fields to transaction objects
        `uvm_object_utils_begin(apb_txn)
            `uvm_field_int(write, UVM_ALL_ON)
            `uvm_field_int(addr, UVM_ALL_ON)
            `uvm_field_int(data_in, UVM_ALL_ON)
            `uvm_field_int(data_out, UVM_ALL_ON)
        `uvm_object_utils_end

        //uvm inherited constructore
        function new(string name = "apb_txn");
            super.new(name);
        endfunction

        constraint valid_addr {
            addr inside {4'h0, 4'h4, 4'h8, 4'hC};
        }

    endclass

    //generator (sequence)
    class apb_base_sequence extends uvm_sequence #(apb_txn);
        `uvm_object_utils(apb_base_sequence)
        localparam int unsigned RANDOM_TRANSACTIONS = 20;
        bit[3:0] prev_addr;
        bit[7:0] delay_data;
        virtual apb_master vif;

        //constructor
        function new(string name = "apb_base_sequence");
            super.new(name);
        endfunction

        //helpers
        task generate_transaction(string name, bit write, 
          input bit [3:0] addrs[], input logic [7:0] fixed_data = 'x);
            apb_txn tr;
            tr = apb_txn::type_id::create(name);
            start_item(tr);
            tr.write = write;
            if (fixed_data === 'x) begin
                assert(tr.randomize() with {addr inside {addrs};})
                  else $fatal("Failed to randomize transaction");
            end else begin
                assert(tr.randomize() with {addr inside {addrs}; data_in == fixed_data;})
                  else $fatal("Failed to randomize transaction");
            end
            prev_addr = tr.addr;
            delay_data = tr.data_in;
            $display("[%0t] GEN: %s transaction: addr=%0d, data_in=%0d", 
              $time, name, tr.addr, tr.data_in);
            finish_item(tr);
        endtask

        task activate_counter();
            generate_transaction("activate_counter_txn", 1'b1, '{4'h0}, 8'h01);
        endtask

        task set_random_limit();
            generate_transaction("set_random_limit_txn", 1'b1, '{4'h4}, 'x);
        endtask

        task set_limit(int limit);
            generate_transaction("set_limit_txn", 1'b1, '{4'h4}, limit);
        endtask

        task read_count();
            generate_transaction("read_count_txn", 1'b0, '{4'h8}, 'x);
        endtask

        task read_flag();
            generate_transaction("read_flag_txn", 1'b0, '{4'hC}, 'x);
        endtask

        task deactivate_counter();
            generate_transaction("deactivate_counter_txn", 1'b1, '{4'h0}, 8'h00);
        endtask
    endclass

    //sequence test 1
    class apb_address_sequence extends apb_base_sequence;
        `uvm_object_utils(apb_address_sequence)

        function new(string name = "apb_address_sequence");
            super.new(name);
        endfunction

         task body();
            vif.address_test_end = 1'b0;
            repeat (RANDOM_TRANSACTIONS) begin
                generate_transaction("random_write_txn", 1'b1, '{4'h0, 4'h4}, 'x);
                generate_transaction("reading_random_write_txn", 1'b0, '{prev_addr}, 'x);
            end
            vif.address_test_end = 1'b1;
        endtask
    endclass 

    //sequence test 2
    class counter_cycle_sequence extends apb_base_sequence;
        `uvm_object_utils(counter_cycle_sequence)

        function new(string name = "counter_cycle_sequence");
            super.new(name);
        endfunction

        task body();
            bit [7:0] delay;
            vif.cycle_test_end = 1'b0;
            set_random_limit();
            delay = delay_data;
            activate_counter();

            repeat (delay) @(posedge vif.clk);
            read_flag();

            @(posedge vif.clk);

            deactivate_counter();
            vif.cycle_test_end = 1'b1;
        endtask
    endclass

    //sequence test 3
    class counter_count_sequence extends apb_base_sequence;
        `uvm_object_utils(counter_count_sequence)
        int test_count = 8'd10;

        function new(string name = "counter_count_sequence");
            super.new(name);
        endfunction

        task body();
            vif.count_test_end = 1'b0;
            set_limit(8'd255);
            activate_counter();

            repeat (test_count - 1) @(posedge vif.clk);
            read_count();
            
            @(posedge vif.clk);

            deactivate_counter();
            vif.count_test_end = 1'b1;
        endtask
    endclass

    //sequence test 4
    class counter_stop_sequence extends apb_base_sequence;
        `uvm_object_utils(counter_stop_sequence)
        int test_count = 8'd10;

        function new(string name = "counter_stop_sequence");
            super.new(name);
        endfunction

        task body();
            vif.stop_test_end = 1'b0;
            set_limit(8'd255);
            activate_counter();

            repeat (test_count - 1) @(posedge vif.clk);
            deactivate_counter();

            repeat (5) @(posedge vif.clk);
            read_count();
            
            @(posedge vif.clk);
            vif.stop_test_end = 1'b1;
        endtask
    endclass

    //sequencer
    class apb_sequencer extends uvm_sequencer #(apb_txn);
        `uvm_component_utils(apb_sequencer)
        function new(string name = "apb_sequencer", uvm_component parent = null);
            super.new(name, parent);
        endfunction
    endclass

    //driver
    class apb_driver extends uvm_driver #(apb_txn);
        `uvm_component_utils(apb_driver);
        virtual apb_master vif;

        function new(string name = "apb_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual apb_master)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF", "Driver could not get virtual interface")
        endfunction

        task run_phase(uvm_phase phase);
            apb_txn tr;
            vif.psel = 1'b1;
            wait (vif.rst == 1'b0);
            
            forever begin
                seq_item_port.get_next_item(tr);
                @(negedge vif.clk);
                vif.pwrite <= tr.write;
                vif.paddr <= tr.addr;
                vif.pwdata <= tr.data_in;
                
                @(negedge vif.clk);
                vif.penable <= 1'b1;

                @(negedge vif.clk);
                vif.penable <= 1'b0;
                seq_item_port.item_done();
            end
        endtask
    endclass

    //coverage collector
    class apb_coverage_collector extends uvm_subscriber #(apb_txn);
        `uvm_component_utils(apb_coverage_collector)
        covergroup cg with function sample(bit write, bit [3:0] addr, bit [7:0] data_in);
            write_cp: coverpoint write {
                bins write = {1'b1};
                bins read = {1'b0};
            }

            data_cp: coverpoint data_in {
                bins zero = {8'h00};
                bins max = {8'hFF};
                bins other = default;
            }

            addr_cp: coverpoint addr {
                bins ctrl = {4'h0};
                bins limit = {4'h4};
                bins count = {4'h8};
                bins flag = {4'hC};
                bins other = default;
            }

            write_x_addr: cross write_cp, addr_cp;
        endgroup

        function new(string name = "apb_coverage_collector", uvm_component parent = null);
            super.new(name, parent);
            cg = new();
        endfunction

        function void write(apb_txn t);
          cg.sample(t.write, t.addr, t.data_in);
        endfunction

        function void report_phase(uvm_phase phase);
            `uvm_info("COV", "\n--- FUNCTIONAL COVERAGE ---", UVM_NONE);
            `uvm_info("COV", $sformatf("write_cp coverage      = %0.2f%%", cg.write_cp.get_coverage()), UVM_NONE);
            `uvm_info("COV", $sformatf("data_cp coverage      = %0.2f%%", cg.data_cp.get_coverage()), UVM_NONE);
            `uvm_info("COV", $sformatf("addr_cp coverage      = %0.2f%%", cg.addr_cp.get_coverage()), UVM_NONE);
            `uvm_info("COV", $sformatf("write_x_addr coverage = %0.2f%%", cg.write_x_addr.get_coverage()), UVM_NONE);
            `uvm_info("COV", $sformatf("Overall coverage      = %0.2f%%", cg.get_coverage()), UVM_NONE);
        endfunction
    endclass

    //monitor
    class apb_monitor extends uvm_component;
        `uvm_component_utils(apb_monitor)
        virtual apb_master vif;
        
        uvm_analysis_port #(apb_txn) input_ap;
        uvm_analysis_port #(bit [7:0]) expected_ap;
        uvm_analysis_port #(bit [7:0]) actual_ap;

        function new(string name = "apb_monitor", uvm_component parent = null);
            super.new(name, parent);
            input_ap = new("input_ap", this);
            expected_ap = new("expected_ap", this);
            actual_ap = new("actual_ap", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual apb_master)::get(this,"","vif",vif))
                `uvm_fatal("NOVIF", "Monitor could not get virtual interface")
        endfunction

        task run_phase(uvm_phase phase);
            apb_txn tr_observed;
            wait (vif.rst == 1'b0);

            forever begin
                @(posedge vif.clk);
                //sample at the enable
                if (vif.psel && vif.penable) begin
                    tr_observed = apb_txn::type_id::create("tr_observed");
                    //always monitor the write/read mode and address
                    tr_observed.write = vif.pwrite;
                    tr_observed.addr = vif.paddr;

                    if (tr_observed.write) begin
                        //if write, sample input data which is the expected data
                        tr_observed.data_in = vif.pwdata;
                        expected_ap.write(tr_observed.data_in);
                        `uvm_info("MON", $sformatf("Write (expected): write=%0b addr=%0d data_in=%0d",
                          tr_observed.write, tr_observed.addr, tr_observed.data_in), UVM_MEDIUM)
                    end else begin
                        //if read, sample output data which is the actual data
                        tr_observed.data_out = vif.prdata;
                        actual_ap.write(tr_observed.data_out);
                        `uvm_info("MON", $sformatf("Read (actual): write=%0b addr=%0d data_out=%0d",
                          tr_observed.write, tr_observed.addr, tr_observed.data_out), UVM_MEDIUM)
                    end
                    input_ap.write(tr_observed);
                end
            end
        endtask
    endclass

    //agent
    class apb_agent extends uvm_agent;
        `uvm_component_utils(apb_agent)
        apb_sequencer seqr;
        apb_driver drv;
        apb_monitor mon;

        function new(string name = "apb_agent", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            seqr = apb_sequencer::type_id::create("seqr", this);
            drv = apb_driver::type_id::create("drv", this);
            mon = apb_monitor::type_id::create("mon", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            //connect the driver inherited member: seq_item_port to the sequencer
            //inherited member: seq_item_export
            drv.seq_item_port.connect(seqr.seq_item_export);
        endfunction
    endclass

    //scoreboard
    class apb_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(apb_scoreboard)
        uvm_tlm_analysis_fifo #(bit [7:0]) expected_fifo;
        uvm_tlm_analysis_fifo #(bit [7:0]) actual_fifo;
        uvm_event done;
        int unsigned pass_count;
        int unsigned error_count;
        int unsigned expected_count = 23;
        int unsigned random_transactions = 20;
        int unsigned count_test_count = 8'd10;
        int unsigned stop_test_count = 8'd10;
        virtual apb_master vif;

        function new(string name = "apb_scoreboard", uvm_component parent = null);
            super.new(name, parent);
            done = new("done");
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            expected_fifo = new("expected_fifo", this);
            actual_fifo = new("actual_fifo", this);
            void'(uvm_config_db#(int unsigned)::get(this, "", "expected_count", expected_count));
            void'(uvm_config_db#(int unsigned)::get(this, "", "random_transactions", random_transactions));
            void'(uvm_config_db#(int unsigned)::get(this, "", "count_test_count", count_test_count));
            void'(uvm_config_db#(int unsigned)::get(this, "", "stop_test_count", stop_test_count));
            void'(uvm_config_db#(virtual apb_master)::get(this, "", "vif", vif));
        endfunction

        task run_phase(uvm_phase phase);
            bit [7:0] expected, actual;

            wait(vif.address_test_end);
            repeat (random_transactions) begin
                expected_fifo.get(expected);
                actual_fifo.get(actual);
                if (actual === expected) begin
                    pass_count++;
                    `uvm_info("SB", $sformatf("apb_address_sequence: PASS: expected=%0d,actual=%0d", expected, actual), UVM_LOW)
                end else begin
                    error_count++;
                    `uvm_error("SB", $sformatf("apb_address_sequence: FAIL: expected=%0d, actual=%0d", expected, actual))
                end
            end

            wait(vif.cycle_test_end);
            actual_fifo.get(actual);
            if (actual) begin
                pass_count++;
              `uvm_info("SB", $sformatf("counter_cycle_sequence: PASS: expected=1, actual=%0d", actual), UVM_LOW)
            end else begin
                error_count++;
                `uvm_error("SB", $sformatf("counter_cycle_sequence: FAIL: expected=1, actual=%0d", actual))
            end

            wait(vif.count_test_end);
            actual_fifo.get(actual);
            if (actual === count_test_count) begin
                pass_count++;
              `uvm_info("SB", $sformatf("counter_count_sequence: PASS: expected=%0d, actual=%0d", count_test_count, actual), UVM_LOW)
            end else begin
                error_count++;
              `uvm_error("SB", $sformatf("counter_count_sequence: FAIL: expected=%0d, actual=%0d", count_test_count, actual))
            end

            wait(vif.stop_test_end);
            actual_fifo.get(actual);
            if (actual - 1 === stop_test_count) begin
                pass_count++;
              `uvm_info("SB", $sformatf("counter_stop_sequence: PASS: expected=%0d, actual=%0d", stop_test_count, actual), UVM_LOW)
            end else begin
                error_count++;
              `uvm_error("SB", $sformatf("counter_stop_sequence: FAIL: expected=%0d, actual=%0d", stop_test_count, actual))
            end
			`uvm_info("SB", "Triggering done", UVM_LOW)
            done.trigger();
        endtask
    endclass

    //environment
    class apb_env extends uvm_env;
        `uvm_component_utils(apb_env)
        apb_agent agent;
        apb_scoreboard sb;
        apb_coverage_collector cov;

        function new(string name = "apb_env", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            agent = apb_agent::type_id::create("agent", this);
            sb = apb_scoreboard::type_id::create("sb", this);
            cov = apb_coverage_collector::type_id::create("cov", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            agent.mon.expected_ap.connect(sb.expected_fifo.analysis_export);
            agent.mon.actual_ap.connect(sb.actual_fifo.analysis_export);
            agent.mon.input_ap.connect(cov.analysis_export);
        endfunction
    endclass

    //test
    class apb_test extends uvm_test;
        `uvm_component_utils(apb_test)
        virtual apb_master vif;
        apb_env env;

        function new(string name = "apb_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual apb_master)::get(this,"","vif",vif))
                `uvm_fatal("NOVIF", "Test could not get virtual interface")
            uvm_config_db#(int unsigned)::set(this, "env.sb", "expected_count", 23);
            uvm_config_db#(int unsigned)::set(this, "env.sb", "random_transactions", 20);
            uvm_config_db#(int unsigned)::set(this, "env.sb", "count_test_count", 8'd10);
            uvm_config_db#(int unsigned)::set(this, "env.sb", "stop_test_count", 8'd10);
            env = apb_env::type_id::create("env", this);
        endfunction

        task run_phase(uvm_phase phase);
            apb_address_sequence addr_seq;
            counter_cycle_sequence cycle_seq;
            counter_count_sequence count_seq;
            counter_stop_sequence stop_seq;
            phase.raise_objection(this);

            vif.rst <= 1'b1;
            vif.psel <= 1'b1;
            vif.paddr <= 4'h0;
            vif.penable <= 1'b0;
            vif.pwrite <= 1'b0;
            vif.pwdata <= 8'h00;
            vif.address_test_end <= 1'b0;
            vif.cycle_test_end <= 1'b0;
            vif.count_test_end <= 1'b0;
            vif.stop_test_end <= 1'b0;

            repeat (2) @(posedge vif.clk);
            vif.rst <= 1'b0;
            `uvm_info("TEST", "Reset released", UVM_LOW)

            addr_seq = apb_address_sequence::type_id::create("addr_seq");
            cycle_seq = counter_cycle_sequence::type_id::create("cycle_seq");
            count_seq = counter_count_sequence::type_id::create("count_seq");
            stop_seq = counter_stop_sequence::type_id::create("stop_seq");
            addr_seq.vif = vif;
            cycle_seq.vif = vif;
            count_seq.vif = vif;
            stop_seq.vif = vif;
			
          	fork
              begin
                addr_seq.start(env.agent.seqr);
                vif.rst <= 1'b1;
                repeat (2) @(posedge vif.clk);
                vif.rst <= 1'b0;

                cycle_seq.start(env.agent.seqr);
                vif.rst <= 1'b1;
                repeat (2) @(posedge vif.clk);
                vif.rst <= 1'b0;

                count_seq.start(env.agent.seqr);
                vif.rst <= 1'b1;
                repeat (2) @(posedge vif.clk);
                vif.rst <= 1'b0;

                stop_seq.start(env.agent.seqr);
                vif.rst <= 1'b1;
                repeat (2) @(posedge vif.clk);
                vif.rst <= 1'b0;
              end
            
           	  begin
            	env.sb.done.wait_trigger();
              end
            join

            if (env.sb.error_count != 0)
                `uvm_error("TEST", $sformatf("Test completed with %0d errors", env.sb.error_count))
            else
                `uvm_info("TEST", "Test completed successfully", UVM_LOW)
            phase.drop_objection(this);
        endtask
    endclass
endpackage

//toplevel
module apb_uvm_tb;
    import uvm_pkg::*;
    import apb_uvm_pkg::*;

    logic clk = 1'b0;
    always #5 clk = ~clk;
  

    apb_master vif(clk);

    apb_slave dut(
        .clk(clk),
        .rst(vif.rst),
        .paddr(vif.paddr),
        .psel(vif.psel),
        .penable(vif.penable),
        .pwrite(vif.pwrite),
        .pwdata(vif.pwdata),
        .prdata(vif.prdata)
    );

    initial begin
        uvm_config_db#(virtual apb_master)::set(null, "*", "vif", vif);
        run_test("apb_test");
    end
endmodule


