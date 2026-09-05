module counter2 #(
    parameter int WIDTH = 13
) (
    input  logic             clk,
    input  logic             rst,
    input  logic             done_rx,
    input  logic [WIDTH:0] max_count,
    output logic [WIDTH-1:0] count
);
    logic en;

    always_ff @(posedge clk) begin
        if(done_rx)
            en <= 1'b1;
        else
            en <= 1'b0;
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            count <= '0;
        end else if (count == max_count - 1'b1) begin
            count <= '0;
        end else begin
            count <= count + en;
        end
    end

endmodule