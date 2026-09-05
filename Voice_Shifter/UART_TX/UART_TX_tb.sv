`timescale 1ns/1ps

module UART_TX_tb;

    // Fast sim: 4 clocks per UART bit (easy GTKWave viewing)
    localparam int CLOCK_FREQ     = 4;
    localparam int BAUD_RATE      = 1;
    localparam int CLOCKS_PER_BIT = CLOCK_FREQ / BAUD_RATE;
    localparam int CLK_HALF       = 5;   // 10 ns period
    localparam int BIT_TIME       = CLOCKS_PER_BIT * (2 * CLK_HALF);

    logic       sys_clk = 1'b0;
    logic       rst     = 1'b1;
    logic       en      = 1'b0;
    logic [7:0] data    = 8'h00;
    logic       tx;
    logic       done;
    logic       busy;

    logic [7:0] rx_byte;
    int         pass_count = 0;
    int         fail_count = 0;

    uart_tx #(
        .BAUD_RATE (BAUD_RATE),
        .CLOCK_FREQ(CLOCK_FREQ)
    ) uut (
        .sys_clk(sys_clk),
        .rst    (rst),
        .en     (en),
        .data   (data),
        .tx     (tx),
        .done   (done),
        .busy   (busy)
    );

    always #(CLK_HALF) sys_clk = ~sys_clk;

    // Start a byte (en high for 1 clock while idle)
    task automatic start_tx(input logic [7:0] b);
        begin
            @(posedge sys_clk);
            wait (busy == 1'b0);
            @(negedge sys_clk);
            data = b;
            en   = 1'b1;
            @(negedge sys_clk);
            en   = 1'b0;
        end
    endtask

    // Sample tx on clock edges at bit centers; check 8N1 vs expected
    task automatic check_tx_byte(input logic [7:0] expected);
        int i;
        logic [7:0] got;
        begin
            // wait for start bit
            @(negedge tx);
            @(posedge sys_clk);

            // advance to middle of start bit
            repeat (CLOCKS_PER_BIT / 2 - 1) @(posedge sys_clk);
            if (tx !== 1'b0) begin
                $display("[%0t] FAIL 0x%02h: start bit sample=%b", $time, expected, tx);
                fail_count++;
                return;
            end

            // middle of each data bit (LSB first)
            for (i = 0; i < 8; i++) begin
                repeat (CLOCKS_PER_BIT) @(posedge sys_clk);
                got[i] = tx;
            end

            // middle of stop bit
            repeat (CLOCKS_PER_BIT) @(posedge sys_clk);
            if (tx !== 1'b1) begin
                $display("[%0t] FAIL 0x%02h: stop=%b got_data=%08b",
                         $time, expected, tx, got);
                fail_count++;
                return;
            end

            rx_byte = got;
            if (got === expected) begin
                $display("[%0t] PASS: 0x%02h  %08b", $time, got, got);
                pass_count++;
            end else begin
                $display("[%0t] FAIL: expected 0x%02h (%08b), got 0x%02h (%08b)",
                         $time, expected, expected, got, got);
                fail_count++;
            end

            wait (busy == 1'b0);
            repeat (2) @(posedge sys_clk);
        end
    endtask

    task automatic test_byte(input logic [7:0] b);
        begin
            fork
                start_tx(b);
                check_tx_byte(b);
            join
        end
    endtask

    initial begin
        $dumpfile("UART_TX.vcd");
        $dumpvars(0, UART_TX_tb);

        $display("UART_TX TB  clocks/bit=%0d  bit_time=%0d ns", CLOCKS_PER_BIT, BIT_TIME);

        rst = 1'b1;
        en  = 1'b0;
        repeat (4) @(posedge sys_clk);
        rst = 1'b0;
        repeat (4) @(posedge sys_clk);

        test_byte(8'h67);
        test_byte(8'hA5);
        test_byte(8'h00);
        test_byte(8'hFF);
        test_byte(8'h3C);

        $display("Done: %0d passed, %0d failed", pass_count, fail_count);
        $finish;
    end

endmodule
