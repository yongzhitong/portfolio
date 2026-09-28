module pipeline_div_tb;
    localparam int CLK_PERIOD = 2;
    localparam int WIDTH = 14;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic en = 1'b0;
    logic [WIDTH-1:0] dividend = 14'd1 << 13;
    logic [WIDTH-1:0] divisor  = 14'd255;
    logic [WIDTH-1:0] quotient;
    logic done;

    pipeline_div #(.WIDTH(WIDTH)) uut (
        .clk(clk),
        .rst(rst),
        .en(en),
        .dividend(dividend),
        .divisor(divisor),
        .quotient(quotient),
        .done(done)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    // Must be at module level — cannot nest always inside initial
    always @(posedge clk) begin
        $display("%0t\t%b\t%b\t%d\t%d\t%d\t%b", $time, rst, en, dividend, divisor, quotient, done);
    end

    initial begin
        $dumpfile("pipeline_div_tb.vcd");
        $dumpvars(0, pipeline_div_tb);

        $display("time\trst\ten\tdividend\tdivisor\tquotient\tdone");
        $display("----\t---\t---\t--------\t--------\t--------\t--------");

        rst = 1'b1;
        repeat (4) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        en = 1'b0;
        repeat (4) @(posedge clk);
        @(negedge clk);
        en = 1'b1;

        repeat (50) @(posedge clk);
        $display("done.");
        $finish;
    end
endmodule
