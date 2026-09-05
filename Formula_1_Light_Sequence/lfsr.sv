// lfsr that implements the sequence
// 1 + x + x^6 + x^10 + x^14
// to iterate through 2^14 - 1 values
module lfsr #(
	parameter logic [13:0] SEED = 14'd1
) (
    input  logic        clk,
    input  logic        en,    
    output logic [13:0] prbs
);

    logic [13:0] state_q = SEED;
	 assign prbs = state_q;

    wire feedback = state_q[13] ^ state_q[9] ^ state_q[5] ^ state_q[0];
    
    always_ff @(posedge clk) begin
        if (en) state_q <= {state_q[12:0], feedback}; 
    end
endmodule
