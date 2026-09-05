`timescale 1ns/1ns

module down_counter_tb;
    localparam int CLK_PERIOD = 2;
    localparam int EN_PERIOD  = 5;    // en high 1 cycle, low 4
    localparam int RELOAD_EVERY = 50; // 7 enables * 5 clocks
    localparam logic [8:0] INIT = 9'd7;
    localparam logic [8:0] MAX_COUNT = 9'd10;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic en;
    logic reload_flag1;
    logic reload_flag2;
    logic [8:0] count;
    logic [8:0] init, max_count;

    assign init = INIT;
    assign max_count = MAX_COUNT;

    down_counter #(.WIDTH(9)) uut (
        .clk   (clk),
        .rst   (rst),
        .en    (en),
        .reload_flag1(reload_flag1),
        .reload_flag2(reload_flag2),
        .init  (init),
        .max_count(max_count),
        .count (count)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    // Wide enough for any RELOAD_EVERY. [5:0] only goes to 63, so a
    // period of 70 never matches (RELOAD_EVERY-1) and frame never advances.
    int tick;
    int frame;

    always_ff @(posedge clk) begin
        if (rst) begin
            tick  <= 0;
            frame <= 0;
        end else if (tick == RELOAD_EVERY - 1) begin
            tick  <= 0;
            frame <= frame + 1;
        end else begin
            tick <= tick + 1;
        end
    end

    // en is 1 on ticks 4, 9, 14, 19, 24, 29, 34  →  seven 1-cycle pulses
    // in each 35-cycle frame, then 4 lows before the next.
    assign en = (!rst && (tick % EN_PERIOD == EN_PERIOD - 1));

    // reload_flag:
    //   frame 0: none (rst already loaded init)
    //   frame 1: 1-cycle pulse at tick==0
    //   frame 2: held high for 8 cycles  ← long-flag test
    //   frame 3+: 1-cycle pulse again
    // Both flags default 0. A held-high flag2 (the old default) never
    // releases pulse_gen, so the next 1-cycle flag2 is ignored.
    //   frame 0: no reload (rst already loaded init)
    //   frame 1: 1-cycle flag2 at tick 0  → reload to init
    //   frame 2: flag1 held 8 cycles      → one pulse, reload to max
    //   frame 3,4: 1-cycle flag1 at tick 0
    //   frame 5+: 1-cycle flag2 at tick 0
    always_comb begin
        reload_flag1 = 1'b0;
        reload_flag2 = 1'b0;
        if (!rst && frame != 0) begin
            if (frame == 2)
                reload_flag1 = (tick <= 7);
            else if (frame == 3 || frame == 4)
                reload_flag1 = (tick == 0);
            else if (frame == 1 || frame >= 5)
                reload_flag2 = (tick == 0);
        end
    end

    initial begin
        $dumpfile("down_counter_tb.vcd");
        $dumpvars(0, down_counter_tb);

        $display("time\trst\ten\tflag1\tflag2\treload1\treload2\tcount\tframe\ttick");
        $display("----\t---\t--\t-----\t-----\t-------\t-------\t-----\t-----\t----");

        rst = 1'b1;
        repeat (4) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        // frame 0 count, 1 init-reload, 2 long max-reload, 3-4 max, 5+ init
        wait (frame == 6);
        @(posedge clk);
        $display("done.");
        $finish;
    end

    // $strobe prints AFTER nonblocking updates, so count is the new value.
    always @(posedge clk) begin
        if (rst || en || reload_flag1 || reload_flag2)
            $strobe("%0t\t%b\t%b\t%b\t%b\t%b\t%b\t%0d\t%0d\t%0d",
                    $time, rst, en, reload_flag1, reload_flag2,
                    uut.reload1, uut.reload2, count, frame, tick);
    end
endmodule
