module byte_comb(
    input logic clk,
    input logic rst,
    input logic valid,
    input logic [7:0] data,
    output logic done,
    output logic [15:0] num
);

    logic byte_count = 1'b0;

    always_ff @(posedge clk) begin
        if (rst) begin
            num        <= 16'h0000;
            byte_count <= 1'b0;
            done       <= 1'b0;
        end else begin
            done <= 1'b0; // 1-cycle pulse after the high byte
            if (valid) begin
                if (byte_count == 1'b0) begin
                    num[7:0]   <= data;
                    byte_count <= 1'b1;
                end else begin
                    num[15:8]  <= data;
                    byte_count <= 1'b0;
                    done       <= 1'b1;
                end
            end
        end
    end

endmodule