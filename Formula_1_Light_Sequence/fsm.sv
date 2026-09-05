module fsm (
	input  logic			clk,
	input  logic 			tick,
	input  logic			start_trigger,
	input  logic			stop_trigger,
	input  logic			time_out,
	output logic			en_lfsr,
	output logic			start_delay,
	output logic			en_reaction,
	output logic			mode,
	output logic [9:0] 	ledr
);
	// Ensure trigger is only detected on rising edge
	logic start_0, start_1, start_rise;
	logic stop_0, stop_1, stop_rise;
	
	always_ff @(posedge clk) begin
		start_0 <= start_trigger;
		start_1 <= start_0;
		stop_0  <= stop_trigger;
		stop_1  <= stop_0;
	end
	
	assign start_rise = start_0 & ~start_1;
	assign stop_rise  = stop_0 & ~stop_1;
	
	typedef enum logic [2:0] {IDLE, FILL, LOAD_DELAY, WAIT_RANDOM, REACTION} state_t;
	state_t state, next_state;
	
	logic [3:0] count;
	
	always_ff @(posedge clk) begin
		if (state == IDLE && start_rise) begin
			count   <= 4'd1;
			ledr    <= 10'b0;
			ledr[9] <= 1'b1;
		end
		else if (state == IDLE) begin
			count <= 4'd0;
			ledr  <= 10'b0;
		end
		else begin
			case (state)
				FILL: begin
					// Light subsequent LEDs from MSB to LSB
					if (tick && count < 4'd10) begin
						ledr [9-count] <= 1'b1;
						count				<= count + 1;
					end
				end
				
				WAIT_RANDOM: begin
					// Clear LEDs once timed out
					if (time_out) ledr  <= 10'b0;
				end
				
				REACTION: begin
					ledr <= 10'b0;
				end
			endcase
		end
		
		state <= next_state;
	end
	
	// Next State + Control Outputs
	always_comb begin
		next_state  = state;
		en_lfsr     = 1'b0;
		start_delay = 1'b0;
		en_reaction = 1'b0;
		mode        = 1'b1;
		
		case(state)
			IDLE: begin
				en_lfsr = 1'b1;
				mode    = 1'b1;
				if (start_rise) next_state = FILL;
			end
			
			FILL: begin
				en_lfsr = 1'b1;
				mode    = 1'b0;
				if (count == 4'd10) next_state = LOAD_DELAY;
			end
			
			LOAD_DELAY: begin
				start_delay = 1'b1;
				mode        = 1'b0;
				next_state  = WAIT_RANDOM;
			end
			
			WAIT_RANDOM: begin
				mode = 1'b0;
				if (time_out) next_state = REACTION;
			end
			
			REACTION: begin
				en_reaction = 1'b1;
				mode        = 1'b1;
				if (stop_rise) next_state = IDLE;
			end
		endcase
	end
endmodule
