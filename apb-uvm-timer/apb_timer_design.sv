module timer (
    input logic clk,
    input logic rst,
    input logic enable,
    input logic [7:0] limit,
    output logic [7:0] count,
    output logic flag
);

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            count <= 8'd0;
            flag <= 1'b0;
        end else if (!enable) begin
            flag <= 1'b0;
        end else if (count == limit) begin
            count <= 8'd0;
            flag <= 1'b1;
        end else begin
            count <= count + 8'd1;
            flag <= 1'b0;
        end
    end

endmodule

module apb_slave (
    input logic clk,
    input logic rst,
    input logic [3:0] paddr,
    input logic psel,
    input logic penable,
    input logic pwrite,
    input logic [7:0] pwdata,
    output logic [7:0] prdata
);

    localparam logic [3:0] CTRL_ADDR = 4'h0;
    localparam logic [3:0] LIMIT_ADDR = 4'h4;
    localparam logic [3:0] COUNT_ADDR = 4'h8;
    localparam logic [3:0] FLAG_ADDR = 4'hC;

    logic [7:0] ctrl_reg;
    logic [7:0] limit_reg;
    logic [7:0] count_reg;
    logic flag_reg;

    timer timer_inst (
        .clk(clk),
        .rst(rst),
        .enable(ctrl_reg[0]),
        .limit(limit_reg),
        .count(count_reg),
        .flag(flag_reg)
    );

    //write logic

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            ctrl_reg <= 8'h0;
            limit_reg <= 8'h0;
        end else if (psel && penable && pwrite) begin
            case (paddr)
                CTRL_ADDR: begin
                    ctrl_reg <= pwdata;
                    limit_reg <= limit_reg;
                end
                LIMIT_ADDR: begin
                    ctrl_reg <= ctrl_reg;
                    limit_reg <= pwdata;
                end
                default: begin
                    ctrl_reg <= ctrl_reg;
                    limit_reg <= limit_reg;
                end
            endcase
        end else begin
            ctrl_reg <= ctrl_reg;
            limit_reg <= limit_reg;
        end
    end

    //read logic

    always_comb begin
        if (psel && penable && !pwrite) begin
            case (paddr)
                CTRL_ADDR: prdata = ctrl_reg;
                LIMIT_ADDR: prdata = limit_reg;
                COUNT_ADDR: prdata = count_reg;
                FLAG_ADDR: prdata = flag_reg;
                default: prdata = 8'h0;
            endcase
        end else begin
            prdata = 8'h0;
        end
    end

endmodule