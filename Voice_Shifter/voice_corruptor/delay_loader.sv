module delay_loader (
    input logic clk,
    input logic done_rx,
    input logic rst,
    input logic done_clear,
    output logic en_clear,
    output logic loaded,
    output logic [1:0] current_state
);

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
                en_clear = 1'b0;
                current_state = 2'd0;
            end
            SEL: begin
                loaded = 1'b0;
                en_clear = 1'b0;
                current_state = 2'd1;
            end
            STAY: begin
                loaded = 1'b1;
                en_clear = 1'b0;
                current_state = 2'd2;
            end
            CLEAR: begin
                loaded = 1'b0;
                en_clear = 1'b1;
                current_state = 2'd3;
            end
            default: begin
                loaded = 1'b0;
                en_clear = 1'b0;
                current_state = 2'd0;
            end
        endcase
    end


endmodule