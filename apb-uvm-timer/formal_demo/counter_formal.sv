module counter_formal;

    logic       clk;
    logic       rst;
    logic       en;
    logic [3:0] count;
    logic       past_valid;

    counter dut (
        .clk   (clk),
        .rst   (rst),
        .en    (en),
        .count (count)
    );

    // Initial conditions
    initial begin
        assume(rst);
        assume(!past_valid);
    end

    // Track whether a previous clock cycle exists
    always @(posedge clk) begin
        past_valid <= 1'b1;

        // Reset must be released after its initial cycle
        if (past_valid)
            assume(!rst);
    end

    // After a reset cycle, the counter must be zero
    always @(posedge clk) begin
        if (past_valid && $past(rst))
            assert(count == 4'd0);
    end

    // If enable was low in the previous cycle, count must hold
    always @(posedge clk) begin
        if (past_valid && !$past(rst) && !$past(en))
            assert(count == $past(count));
    end

    always @(posedge clk) begin
        if (past_valid && !$past(rst) && $past(en) && $past(count) != 4'd15)
            assert(count == $past(count) + 1);
    end

    // Find a reachable increment
    always @(posedge clk) begin
        if (!rst && en)
            cover(count == 4'd5);
    end

endmodule