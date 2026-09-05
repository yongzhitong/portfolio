module updown_counter_tb;

    localparam int CLK_PERIOD = 2;
    localparam int EN_PERIOD  = 5;    // en high 1 cycle, low 4
    localparam int RELOAD_EVERY = 100; 
    int tick;
    int frame;
    
    localparam int WIDTH = 8;
    logic clk = 1'b0;
    logic rst;
    logic en;
    logic change = 1'b1;
    logic [WIDTH-1:0] max_count = 8'd15;
    logic [WIDTH-1:0] count;
    logic reload_flag;

    updown_counter updown_counter_inst (
        .clk(clk),
        .rst(rst),
        .en(en),
        .change(change),
        .max_count(max_count),
        .reload_flag(reload_flag),
        .count(count)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    always_ff @(posedge clk) begin
        if (rst) begin
            tick <= 0;
            frame <= 0;
        end else if(tick == RELOAD_EVERY-1) begin
            tick <= 0;
            frame <= frame + 1;
            change <= ~change;
        end else begin
            tick <= tick + 1;
        end 
    end

    assign en = (!rst && ((tick % EN_PERIOD) == EN_PERIOD - 1));
    assign reload_flag = (tick == 0);

    initial begin
        $dumpfile("updown_counter_tb.vcd");
        $dumpvars(0, updown_counter_tb);
        $display("time\trst\ten\tflag\tchange\tcount\tframe\ttick");
        $display("----\t---\t--\t----\t------\t------\t-----\t-----\t----");

        rst = 1'b1;
        repeat (4) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        // frame 0 (count), frame 1 (1-tick reload), frame 2 (long flag)
        wait (frame == 4);
        @(posedge clk);
        $display("done.");
        $finish;
    end

    // $strobe prints AFTER nonblocking updates, so count is the new value.
    always @(posedge clk) begin
        if (rst || en || reload_flag )
            $strobe("%0t\t%b\t%b\t%b\t%b\t%0d\t%0d\t%0d",
                    $time, rst, en, reload_flag, change, count, frame, tick);

    end
endmodule