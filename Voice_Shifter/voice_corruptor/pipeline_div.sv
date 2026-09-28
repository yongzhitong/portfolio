module pipeline_div #(
    parameter WIDTH = 32
)(
    input logic clk,
    input logic rst,
    input logic [WIDTH-1:0] dividend,
    input logic [WIDTH-1:0] divisor,
    input logic en,
    output logic [WIDTH-1:0] quotient,
    output logic done
);

    logic [4:0] bit_end = WIDTH;
    logic [WIDTH-1:0] div_reg;
    logic [WIDTH-1:0] q_reg = {WIDTH{1'b0}};
    logic [WIDTH-1:0] r_reg = {WIDTH{1'b0}};

    always_comb begin
        if(bit_end == WIDTH)
            div_reg = {{(WIDTH-1){1'b0}}, dividend[WIDTH - 1]};
        else
            div_reg = {r_reg[WIDTH-2:0], dividend[bit_end - 1]};
    end

    always_ff @(posedge clk or posedge rst) begin
        if(rst == 1'b1||!en) 
            bit_end <= WIDTH;
        else if (bit_end > 0)
            bit_end <= bit_end - 1;
        else
            bit_end <= bit_end;
    end 

    always_ff @(posedge clk or posedge rst) begin
        if(rst == 1'b1||!en) begin
            q_reg <= {WIDTH{1'b0}};
            r_reg <= {WIDTH{1'b0}};
        end else if (bit_end == 0) begin
            q_reg <= q_reg;
            r_reg <= r_reg;
        end else if(div_reg >= divisor) begin
            q_reg <= {q_reg[WIDTH-2:0], 1'b1};
            r_reg <= div_reg - divisor;
        end else begin
            q_reg <= {q_reg[WIDTH-2:0], 1'b0};
            r_reg <= div_reg;
        end
    end

    assign quotient = q_reg;
    assign done = (bit_end == 0);

endmodule
