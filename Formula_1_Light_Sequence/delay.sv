// Delay
// Waits for N second before defining time out
module delay (
	input logic trigger,
	input logic [13:0] N,
	input logic clk,
	output logic time_out
);

	logic [13:0] count;
	logic active;
	
	always_ff @(posedge clk) begin
		time_out <= 0;
		
		if (trigger) begin
			count  <= N;
			active <= 1;
		end
		else if (active) begin
			if (count == 0) begin
				time_out <= 1'b1;
				active   <= 0;
			end
			else count <= count - 1;
		end
	end
endmodule
	