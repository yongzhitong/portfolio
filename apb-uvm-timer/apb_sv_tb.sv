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

//transaction

class apb_txn;
    rand bit write;
    rand bit [3:0] addr;
    rand bit [7:0] data_in;

    function void print(string label, string module_name);
        $display("[%0t] %s: operation: %s write=%0b, addr=%0d, data_in=%0d", 
        $time, module_name, label, write, addr, data_in);
    endfunction

    constraint valid_addr {
        addr inside {4'h0, 4'h4, 4'h8, 4'hC};
    }
endclass

//generator
class generator;
    mailbox #(apb_txn) gen_to_drv;
    int unsigned random_count;

    function new(mailbox #(apb_txn) gen_to_drv, int unsigned random_count);
        this.gen_to_drv = gen_to_drv;
        this.random_count = random_count;
    endfunction

    task apb_address_tests();
        apb_txn tr;
        logic [3:0] prev_addr;
        repeat (random_count) begin
            tr = new();
            assert(tr.randomize() with {write == 1'b1; addr inside {4'h0, 4'h4};})
                else $fatal("Failed to randomize transaction");
            tr.print("Random write", "GEN");
            prev_addr = tr.addr;
            gen_to_drv.put(tr);

            tr = new();
            assert(tr.randomize() with {write == 1'b0; addr == prev_addr;})
                else $fatal("Failed to randomize transaction");
            tr.print("Random read", "GEN");
            gen_to_drv.put(tr);
        end
    endtask

    task activate_counter();
        apb_txn tr;
        //activate counter
        tr = new();
        assert(tr.randomize() with {write == 1'b1; addr == 4'h0; data_in == 8'h01;})
            else $fatal("Failed to create counter activation transaction");
        tr.print("Targeted counter activation", "GEN");
        gen_to_drv.put(tr);
    endtask

    task set_random_limit();
        apb_txn tr;
        //set limit
        tr = new();
        assert(tr.randomize() with {write == 1'b1; addr == 4'h4;})
            else $fatal("Failed to randomize transaction");
        tr.print("Random limit set", "GEN");
        gen_to_drv.put(tr);
    endtask

    task set_limit(int limit);
        apb_txn tr;
        //set limit
        tr = new();
        assert(tr.randomize() with {write == 1'b1; addr == 4'h4; data_in == limit;})
            else $fatal("Failed to randomize transaction");
        tr.print("Targeted limit set", "GEN");
        gen_to_drv.put(tr);
    endtask

    task read_count();
        apb_txn tr;
        //read count
        tr = new();
        assert(tr.randomize() with {write == 1'b0; addr == 4'h8;})
            else $fatal("Failed to create count read transaction");
        tr.print("Targeted count read", "GEN");
        gen_to_drv.put(tr);
    endtask

    task read_flag();
        apb_txn tr;
        //read flag
        tr = new();
        assert(tr.randomize() with {write == 1'b0; addr == 4'hC;})
            else $fatal("Failed to create flag read transaction");
        tr.print("Targeted flag read", "GEN");
        gen_to_drv.put(tr);
    endtask

    task deactivate_counter();
        apb_txn tr;
        //deactivate counter
        tr = new();
        assert(tr.randomize() with {write == 1'b1; addr == 4'h0; data_in == 8'h00;})
            else $fatal("Failed to create counter deactivation transaction");
        tr.print("Targeted counter deactivation", "GEN");
        gen_to_drv.put(tr);
    endtask

endclass

//coverage collector
class coverage_collector;
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

    function new();
        cg = new();
    endfunction

    function void report();
        $display("\n--- FUNCTIONAL COVERAGE ---");
        $display("write_cp coverage      = %0.2f%%", cg.write_cp.get_coverage());
        $display("data_cp coverage      = %0.2f%%", cg.data_cp.get_coverage());
        $display("addr_cp coverage      = %0.2f%%", cg.addr_cp.get_coverage());
        $display("write_x_addr coverage = %0.2f%%", cg.write_x_addr.get_coverage());
        $display("Overall coverage      = %0.2f%%", cg.get_coverage());
    endfunction

endclass

//driver
class driver;
    generator gen;
    virtual apb_master vif;
    bit [7:0] data_in;
    int unsigned RANDOM_TRANSACTIONS;

    function new(generator gen, virtual apb_master vif, int unsigned RANDOM_TRANSACTIONS);
        this.gen = gen;
        this.vif = vif;
        this.RANDOM_TRANSACTIONS = RANDOM_TRANSACTIONS;
    endfunction

    task process_transaction();
        apb_txn tr;
        vif.psel = 1'b1;
        gen.gen_to_drv.get(tr);
        data_in = tr.data_in;

        @(negedge vif.clk);
        vif.pwrite <= tr.write;
        vif.paddr <= tr.addr;
        vif.pwdata <= tr.data_in;

        @(negedge vif.clk);
        vif.penable <= 1'b1;

        @(negedge vif.clk);
        vif.penable <= 1'b0;
    endtask

    task apb_address_driving();
        vif.address_test_end = 1'b0;
        gen.apb_address_tests();
        vif.psel = 1'b1;
        repeat (this.RANDOM_TRANSACTIONS) begin
            process_transaction();
            process_transaction();
        end
        vif.address_test_end = 1'b1;
    endtask

    task activate_counter();
        gen.activate_counter();
        process_transaction();
       
    endtask

    task set_random_limit();
        gen.set_random_limit();
        process_transaction();
    endtask

    task set_limit(int limit);
        gen.set_limit(limit);
        process_transaction();
    endtask
    
    task read_count();
        gen.read_count();
        process_transaction();
    endtask

    task read_flag();
        gen.read_flag();
        process_transaction();
    endtask

    task deactivate_counter();
        gen.deactivate_counter();
        process_transaction();
    endtask

    task test_counter_cycle();
        bit [7:0] delay;
        vif.cycle_test_end = 1'b0;
        set_random_limit();
        delay = data_in;

        activate_counter();

        repeat (delay) @(posedge vif.clk);
        read_flag();

        @(posedge vif.clk);

        deactivate_counter();
        vif.cycle_test_end = 1'b1;

    endtask

    task test_counter_count(int test_count);
        vif.count_test_end = 1'b0;
        set_limit(8'd255);
        activate_counter();

        repeat (test_count - 1) @(posedge vif.clk);
        read_count();

        @(posedge vif.clk);

        deactivate_counter();
        vif.count_test_end = 1'b1;
    endtask

        //test if timer stops when disabled
    task test_counter_stop(int test_count);
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

//monitor
class monitor;
    virtual apb_master vif;
    mailbox #(bit [7:0]) expected_mb;
    mailbox #(bit [7:0]) actual_mb;
    mailbox #(bit [7:0]) flag_mb;
    mailbox #(bit[7:0]) count_mb;
    coverage_collector cov;

    function new(virtual apb_master vif, mailbox #(bit [7:0]) expected_mb, 
      mailbox #(bit [7:0]) actual_mb, mailbox #(bit [7:0]) flag_mb, 
        mailbox #(bit[7:0]) count_mb, coverage_collector cov);
        this.vif = vif;
        this.expected_mb = expected_mb;
        this.actual_mb = actual_mb;
        this.flag_mb = flag_mb;
        this.count_mb = count_mb;
        this.cov = cov;
    endfunction

    task apb_address_monitoring();
        do begin
            @(posedge vif.clk);
            if (vif.psel && vif.penable && vif.pwrite) begin
                expected_mb.put(vif.pwdata);
                cov.cg.sample(vif.pwrite, vif.paddr, vif.pwdata);
                $display("[%0t] MON input:  write=%0b, addr=%0d, data_in=%0d", 
                $time, vif.pwrite, vif.paddr, vif.pwdata);
            end
            if (vif.psel && vif.penable && !vif.pwrite) begin
                actual_mb.put(vif.prdata);
                cov.cg.sample(vif.pwrite, vif.paddr, vif.pwdata);
                $display("[%0t] MON output: prdata=%0d", $time, vif.prdata);
            end
        end while (!vif.address_test_end);
    endtask

    task counter_cycle_monitoring();
        do begin
            @(posedge vif.clk);
            if (vif.psel && vif.penable && !vif.pwrite) begin
                flag_mb.put(vif.prdata);
                cov.cg.sample(vif.pwrite, vif.paddr, vif.pwdata);
                $display("[%0t] MON: COUNTER CYCLE COMPLETED", $time);               
            end
        end while (!vif.cycle_test_end);
    endtask

    task counter_count_monitoring();
        do begin
            @(posedge vif.clk);
            if (vif.psel && vif.penable && !vif.pwrite) begin
                count_mb.put(vif.prdata);
                cov.cg.sample(vif.pwrite, vif.paddr, vif.pwdata);
                $display("[%0t] MON: COUNTER COUNT COMPLETED, count=%0d", $time, vif.prdata);
            end
        end while (!vif.count_test_end);
    endtask

    task counter_stop_monitoring();
        do begin
            @(posedge vif.clk);
            if (vif.psel && vif.penable && !vif.pwrite) begin
                count_mb.put(vif.prdata);
                cov.cg.sample(vif.pwrite, vif.paddr, vif.pwdata);
                $display("[%0t] MON: COUNTER STOP COMPLETED", $time);
            end
        end while (!vif.stop_test_end);
    endtask

endclass

//scoreboard

class scoreboard;
    mailbox #(bit [7:0]) expected_mb;
    mailbox #(bit [7:0]) actual_mb;
    mailbox #(bit [7:0]) flag_mb;
    mailbox #(bit[7:0]) count_mb;
    int unsigned pass_count;
    int unsigned error_count;
    int unsigned TRANSACTION_COUNT;

    function new(mailbox #(bit [7:0]) expected_mb, mailbox #(bit [7:0]) actual_mb,
     mailbox #(bit [7:0]) flag_mb, mailbox #(bit[7:0]) count_mb, int unsigned TRANSACTION_COUNT);
        this.expected_mb = expected_mb;
        this.actual_mb = actual_mb;
        this.flag_mb = flag_mb;
        this.count_mb = count_mb;
        this.TRANSACTION_COUNT = TRANSACTION_COUNT;
    endfunction

    task apb_address_scoring();
        bit [7:0] expected;
        bit [7:0] actual;

        repeat (this.TRANSACTION_COUNT) begin
            expected_mb.get(expected);
            actual_mb.get(actual);

            if (actual === expected) begin
                pass_count++;
                $display("[%0t] Test: apb_addresst_tests, 
                  SCOREBOARD PASS: expected=%0d actual=%0d",
                    $time, expected, actual);
            end
            else begin
                error_count++;
                $error("[%0t] Test: apb_addresst_tests, 
                  SCOREBOARD FAIL: expected=%0d actual=%0d",
                    $time, expected, actual);
            end
        end

    endtask

    task counter_cycle_scoring();
        bit [7:0] actual_flag;
        flag_mb.get(actual_flag);

        if (actual_flag === 8'd1) begin
            pass_count++;
            $display("[%0t] Test: test_counter_cycle, 
              SCOREBOARD PASS: expected_flag=1, actual_flag=%0d",
                $time, actual_flag);
        end
        else begin
            error_count++;
            $error("[%0t] Test: test_counter_cycle, 
              SCOREBOARD FAIL: expected_flag=1, actual_flag=%0d",
                $time, actual_flag);
        end
    endtask

    task counter_count_scoring(int test_count);
        bit [7:0] actual_count;
        count_mb.get(actual_count);

        if (actual_count === test_count) begin
            pass_count++;
            $display("[%0t] Test: test_counter_count, 
              SCOREBOARD PASS: expected_count=%0d, actual_count=%0d",
                $time, test_count, actual_count);
        end
        else begin
            error_count++;
            $error("[%0t] Test: test_counter_count, 
              SCOREBOARD FAIL: expected_count=%0d, actual_count=%0d",
                $time, test_count, actual_count);
        end
    endtask

    task counter_stop_scoring(int test_count);
        bit [7:0] actual_count;
        count_mb.get(actual_count);

        if (actual_count - 1 === test_count) begin
            pass_count++;
            $display("[%0t] Test: test_counter_stop, 
              SCOREBOARD PASS: expected_count(+1)=%0d, actual_count=%0d",
                $time, test_count + 1, actual_count);
        end
        else begin
            error_count++;
            $error("[%0t] Test: test_counter_stop, 
              SCOREBOARD FAIL: expected_count(+1)=%0d, actual_count=%0d",
                $time, test_count + 1, actual_count);
        end
    endtask

    task summary();
        $display("\n--- Test: apb_addresst_tests, SCOREBOARD SUMMARY ---");
        $display("Passes = %0d", pass_count);
        $display("Errors = %0d", error_count);
    endtask
endclass

//environment
class environment;
    localparam int unsigned RANDOM_TRANSACTIONS = 20;
    localparam int unsigned TOTAL_TRANSACTIONS = RANDOM_TRANSACTIONS + 3;

    virtual apb_master vif;
    mailbox #(apb_txn) gen_to_drv;
    mailbox #(bit [7:0]) expected_mb;
    mailbox #(bit [7:0]) actual_mb;
    mailbox #(bit [7:0]) flag_mb;
    mailbox #(bit[7:0]) count_mb;

    generator gen;
    driver drv;
    monitor mon;
    scoreboard sb;
    coverage_collector cov;

    function new(virtual apb_master vif);
        this.vif = vif;

        gen_to_drv = new();
        expected_mb = new();
        actual_mb = new();
        flag_mb = new();
        count_mb = new();

        gen = new(gen_to_drv, RANDOM_TRANSACTIONS);
        cov = new();
        drv = new(gen, vif, RANDOM_TRANSACTIONS);
        mon = new(vif, expected_mb, actual_mb, flag_mb, count_mb, cov);
        sb = new(expected_mb, actual_mb, flag_mb, count_mb, RANDOM_TRANSACTIONS);
    endfunction

    task run();

        fork
            drv.apb_address_driving();
            mon.apb_address_monitoring();
            sb.apb_address_scoring();
        join

        vif.rst = 1'b1;
        repeat (2) @(posedge vif.clk);
        vif.rst = 1'b0;

        fork
            drv.test_counter_cycle();
            mon.counter_cycle_monitoring();
            sb.counter_cycle_scoring();
        join

        vif.rst = 1'b1;
        repeat (2) @(posedge vif.clk);
        vif.rst = 1'b0;

        fork
            drv.test_counter_count(8'd10);
            mon.counter_count_monitoring();
            sb.counter_count_scoring(8'd10);
        join

        vif.rst = 1'b1;
        repeat (2) @(posedge vif.clk);
        vif.rst = 1'b0;

        fork
            drv.test_counter_stop(8'd10);
            mon.counter_stop_monitoring();
            sb.counter_stop_scoring(8'd10);
        join

        vif.rst = 1'b1;
        repeat (2) @(posedge vif.clk);
        vif.rst = 1'b0;

        sb.summary();
        cov.report();

        if(sb.error_count == 0) begin
            $display("\nTEST PASSED");
        end else begin
            $fatal(1, "TEST FAILED with %0d scoreboard errors", sb.error_count);
        end
    endtask

endclass

//toplevel
module apb_sv_tb;
    logic clk = 1'b0;
    environment env;

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
        vif.rst = 1'b1;
        vif.psel = 1'b0;
        vif.paddr = 4'h0;
        vif.penable = 1'b0;
        vif.pwrite = 1'b0;
        vif.pwdata = 8'h00;
        vif.address_test_end = 1'b0;
        vif.cycle_test_end = 1'b0;
        vif.count_test_end = 1'b0;
        vif.stop_test_end = 1'b0;

        repeat (2) @(posedge clk);
        vif.rst = 1'b0;
        $display("[%0t] Reset released", $time);

        env = new(vif);
        env.run();

        #1;
        $finish;
    end
endmodule