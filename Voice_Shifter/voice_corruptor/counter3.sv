module counter3 #(
    parameter int WIDTH = 16
) (
    input  logic             clk,
    input  logic             rst,
    input  logic             en,
    input  logic [WIDTH-1:0] max_count,
    output logic             done,
    output logic [WIDTH-1:0] add
);

    logic [WIDTH-1:0] count;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            count <= '0;
            done  <= 1'b0;
        end else if (!en) begin
            count <= '0;
            done  <= 1'b0;
        end else if (count == max_count) begin
            count <= '0;
            done  <= 1'b1;
        end else begin
            count <= count + 1'b1;
            done  <= 1'b0;
        end
    end

    assign add = count;

endmodule