module updown_counter #(
    parameter int WIDTH = 8
) (
    input logic clk,
    input logic rst,
    input logic en,
    input logic change,
    input logic [WIDTH-1:0] max_count,
    input logic reload_flag,
    output logic [WIDTH-1:0] count
);

    logic [WIDTH-1:0] counting;
    logic reload;

    pulse_gen reload_pulse (
        .clk(clk),
        .flag(reload_flag),
        .pulse(reload)
    );

    always_ff @(posedge clk or posedge rst) begin
        if(rst)
            counting <= 0;
        else if (change) begin
            if(reload)
                counting <= 0;
            else if(counting == max_count)
                counting <= max_count;
            else
                counting <= counting + en;
        end
        else begin
            if(reload)
                counting <= max_count;
            else if(counting == 0)
                counting <= 0;
            else
                counting <= counting - en;
        end
    end

    assign count = counting;
endmodule