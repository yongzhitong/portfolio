module KG_controller_tb;

    localparam int CLOCK_PERIOD = 2;
    localparam int TICK_PER_FRAME = 30;

    logic clk = 1'b0;
    logic rst = 1'b0;
    logic loaded = 1'b0;
    logic en_loaded;
    logic [12:0] a = 13'd128;
    logic [12:0] KA;
    logic [12:0] KB;
    logic [12:0] GA;
    logic [12:0] GB;

    KG_controller uut (
        .clk(clk),
        .rst(rst),
        .loaded(loaded),
        .en_loaded(en_loaded),
        .a(a),
        .KA(KA),
        .KB(KB),
        .GA(GA),
        .GB(GB)
    );

    int tick, frame;

    always #(CLOCK_PERIOD/2) clk = ~clk;

    always @(posedge clk) begin
        if (rst) begin
            tick <= 0;
            frame <= 0;
        end else if (tick == TICK_PER_FRAME - 1) begin
            if(frame == 0)
                loaded <= 1'b1;
            tick <= 0;
            frame <= frame + 1;
        end else begin
            tick <= tick + 1;
        end
    end

    assign en_loaded = (frame >= 1) && ((tick % TICK_PER_FRAME) == TICK_PER_FRAME - 1);
    
    initial begin
        $dumpfile("KG_controller_tb.vcd");
        $dumpvars(0, KG_controller_tb);
        $display("%6s %8s %7s %9s %6s %6s %6s %6s %6s",
                 "time", "state", "loaded", "en_loaded", "KA", "KB", "GA", "GB", "frame");
        $display("%6s %8s %7s %9s %6s %6s %6s %6s %6s",
                 "----", "--------", "------", "---------", "----", "----", "----", "----", "-----");

        rst = 1'b1;
        repeat (4) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        wait (frame == 2048);
        @(posedge clk);
        $display("done");
        $finish;
    end

    // Packed bytes so $strobe can print it (Icarus rejects string/$strobe).
    reg [8*8-1:0] state_str;
    always @(*) begin
        case (uut.c_state)
            uut.IDLE:    state_str = "IDLE";
            uut.RAMP_GA: state_str = "RAMP_GA";
            uut.ONE_GA:  state_str = "ONE_GA";
            uut.RAMP_GB: state_str = "RAMP_GB";
            uut.ONE_GB:  state_str = "ONE_GB";
            default:     state_str = "???";
        endcase
    end

    always @(posedge clk) begin
        if ( ( (frame % 128) == 0 || (frame % 128 ) == 1 || (frame % 128 ) == 2) &&
        (tick == 0 || tick == 1 || tick == 2))
            $strobe("%6t %8s %7b %9b %6d %6d %6d %6d %6d",
                    $time, state_str, loaded, en_loaded, KA, KB, GA, GB, frame);
    end
endmodule