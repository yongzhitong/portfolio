`timescale 1ns/1ps

module UART_RX_tb;

    // High oversampling so uart_rx samples cleanly
    localparam int CLOCK_FREQ     = 50_000_000;
    localparam int BAUD_RATE      = 112_500;
    localparam int CLOCKS_PER_BIT = CLOCK_FREQ / BAUD_RATE;
    localparam int CLK_HALF       = 5;   // 10 ns clock period
    localparam int BIT_TIME       = CLOCKS_PER_BIT * (2 * CLK_HALF);

    logic        sys_clk  = 1'b0;
    logic        rst      = 1'b1;
    logic        bit_in   = 1'b1;   // UART idle high
    logic [7:0]  byte_out;
    logic        valid;
    logic        done;
    logic [15:0] num;

    int pass_count = 0;
    int fail_count = 0;

    uart_rx #(
        .BAUD_RATE (BAUD_RATE),
        .CLOCK_FREQ(CLOCK_FREQ)
    ) u_rx (
        .sys_clk (sys_clk),
        .rst     (rst),
        .bit_in  (bit_in),
        .byte_out(byte_out),
        .valid   (valid)
    );

    byte_comb u_comb (
        .clk  (sys_clk),
        .rst  (rst),
        .valid(valid),
        .data (byte_out),
        .done (done),
        .num  (num)
    );

    always #(CLK_HALF) sys_clk = ~sys_clk;

    // Drive one 8N1 UART frame (LSB first)
    task automatic uart_send_byte(input logic [7:0] data);
        int i;
        begin
            bit_in = 1'b0;
            #(BIT_TIME);

            for (i = 0; i < 8; i++) begin
                bit_in = data[i];
                #(BIT_TIME);
            end

            bit_in = 1'b1;
            #(BIT_TIME);
        end
    endtask

    // byte_comb: first byte -> num[7:0], second byte -> num[15:8]
    task automatic uart_send_word(input logic [15:0] word);
        begin
            uart_send_byte(word[7:0]);
            #(BIT_TIME);
            uart_send_byte(word[15:8]);
            #(BIT_TIME);
        end
    endtask

    task automatic check_word(input logic [15:0] expected);
        begin
            @(posedge done);
            if (num === expected) begin
                $display("[%0t] PASS: 0x%04h  (%08b_%08b)",
                         $time, num, num[15:8], num[7:0]);
                pass_count++;
            end else begin
                $display("[%0t] FAIL: expected 0x%04h, got 0x%04h",
                         $time, expected, num);
                fail_count++;
            end
        end
    endtask

    initial begin
        $dumpfile("UART_RX.vcd");
        $dumpvars(0, UART_RX_tb);

        $display("2-byte RX TB  clocks/bit=%0d", CLOCKS_PER_BIT);

        rst = 1'b1;
        repeat (4) @(posedge sys_clk);
        rst = 1'b0;
        #(BIT_TIME);

        fork
            uart_send_word(16'hA55C);
            check_word(16'hA55C);
        join

        #(BIT_TIME * 2);

        fork
            uart_send_word(16'h1234);
            check_word(16'h1234);
        join

        #(BIT_TIME * 2);

        fork
            uart_send_word(16'h00FF);
            check_word(16'h00FF);
        join

        #(BIT_TIME * 2);

        fork
            uart_send_word(16'hFF00);
            check_word(16'hFF00);
        join

        $display("Done: %0d passed, %0d failed", pass_count, fail_count);
        $finish;
    end

endmodule
