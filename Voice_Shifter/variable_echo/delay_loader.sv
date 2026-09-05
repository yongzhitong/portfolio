module delay_loader (
    input logic clk,
    input logic done_rx,
    input logic rst,
    input logic [15:0] num,
    input logic en_loaded,
    input logic [12:0] rdadd,
    input logic done_clear,
    input logic signed [15:0] ram_out,
    output logic en_clear,
    output logic loaded,
    output logic wren,
    output logic [12:0] wradd,
    output logic signed [15:0] data_in
);

    logic [15:0] delay;

    typedef enum {IDLE, SEL, STAY, CLEAR} mystate;
    mystate c_state, n_state;

    //delay loading and next states

    always_ff @(posedge clk, posedge rst) begin
        if(rst) begin
            c_state <= CLEAR;
        end else begin
            c_state <= n_state;
        end
    end

    always_ff @(posedge clk) begin
        if(c_state == SEL) begin
            delay <= num[12:0];
        end
    end

    //next state logic
   
    always_comb begin
        case(c_state)
            IDLE:
                if(done_rx)
                    n_state = SEL;
                else
                    n_state = IDLE;
            SEL: n_state = STAY;
            STAY: n_state = STAY;
            CLEAR: 
                if(done_clear)
                    n_state = IDLE;
                else
                    n_state = CLEAR;
        endcase
    end

    //output logic

    always_comb begin
        case(c_state)
            IDLE: begin
                loaded = 1'b0;
                wren = 1'b0;
                en_clear = 1'b0;
                wradd = 13'b0;
                data_in = 16'b0;
            end
            SEL: begin
                loaded = 1'b0;
                wren = 1'b0;
                en_clear = 1'b0;
                wradd = 13'b0;
                data_in = 16'b0;
            end
            STAY: begin
                loaded = 1'b1;
                wren = en_loaded;
                en_clear = 1'b0;
                wradd = rdadd + delay;
                data_in = num - (ram_out >>> 1);
            end
            CLEAR: begin
                loaded = 1'b0;
                wren = 1'b1;
                en_clear = 1'b1;
                wradd = rdadd;
                data_in = 16'b0;
            end
            default: begin
                loaded = 1'b0;
                wren = 1'b0;
                en_clear = 1'b0;
                wradd = 13'b0;
                data_in = 16'b0;
            end
        endcase
    end


endmodule