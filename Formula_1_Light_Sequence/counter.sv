`timescale 1ns / 100ps
module counter #(
	parameter WIDTH=4
)(
	input logic clk,
	input logic rst,
	input logic en,
	output logic [WIDTH-1:0] count
);
	always_ff @ (posedge clk, posedge rst)	
		if (rst) count <= {WIDTH{1'b0}};
		else count <= count + {{WIDTH-1{1'b0}}, en};
endmodule
