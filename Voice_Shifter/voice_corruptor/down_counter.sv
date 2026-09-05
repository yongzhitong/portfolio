module down_counter #(
    parameter int WIDTH = 9
)(
    input logic clk,
    input logic rst,
    input logic en,
    input logic reload_flag1,
    input logic reload_flag2,
    input logic [WIDTH-1:0] max_count,
    input logic [WIDTH-1:0] init,
    output logic [WIDTH-1:0] count
);

    logic [WIDTH-1:0] counting;
    logic decrement;
    logic down;
    logic reload1, reload2;

    pulse_gen down_pulse (
        .clk(clk),
        .flag(en),
        .pulse(down)
    );

    pulse_gen reload1_pulse (
        .clk(clk),
        .flag(reload_flag1),
        .pulse(reload1)
    );

    pulse_gen reload2_pulse (
        .clk(clk),
        .flag(reload_flag2),
        .pulse(reload2)
    );

    always_ff @(posedge clk or posedge rst) begin
        if (rst || reload2 || reload1)
            decrement <= 1'b0;
        else if (down)
            decrement <= ~decrement;
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst || reload2) begin
            counting <= init;
        end else if (reload1) begin
            counting <= max_count;
        end else if (counting == 0)
            counting <= 0;
        else if (en)
            counting <= counting - decrement;
    end


    assign count = counting;

endmodule