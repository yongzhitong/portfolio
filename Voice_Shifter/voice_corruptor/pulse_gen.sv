module pulse_gen (
    input logic clk,
    input logic flag,
    output logic pulse
);

    typedef enum {IDLE, PULSE, WAIT_LOW} mystate;
    mystate c_state, n_state;

    always_ff @(posedge clk) begin
        c_state <= n_state;
    end

    always_comb begin
        pulse   = 1'b0;
        n_state = c_state;
        case (c_state)
            IDLE: begin
                if (flag)
                    n_state = PULSE;
            end
            PULSE: begin
                pulse = 1'b1;
                n_state = WAIT_LOW;
            end
            WAIT_LOW: begin
                pulse = 1'b0;
                if(!flag)
                    n_state = IDLE;
                else
                    n_state = WAIT_LOW;
            end
        endcase
    end
endmodule