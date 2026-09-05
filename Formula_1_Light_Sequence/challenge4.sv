module challenge4 (
	input	 logic			MAX10_CLK1_50,
	input  logic [1:0]   KEY,
	output logic [9:0]	LEDR,
	output logic [6:0] 	HEX0,
	output logic [6:0]	HEX1,
	output logic [6:0]	HEX2,
	output logic [6:0]	HEX3,
	output logic [6:0]	HEX4
);
	// Internal Signals
	logic tick_ms;
	logic tick_halfs;
	logic time_out;
	logic en_lfsr;
	logic start_delay;
	logic en_reaction;
	logic mode;
	
	logic [9:0]  ledr;
	logic [13:0] prbs;
	logic [13:0] n;
	logic [13:0] reaction;
	logic [13:0] display_value;
	logic [3:0]  bcd0, bcd1, bcd2, bcd3, bcd4;
	
	// Derive clk signal
	clktick TICK_MS (
		.clk(MAX10_CLK1_50),
		.rst(1'b0),
		.en(1'b1),
		.N(16'd49999),
		.tick(tick_ms)
	);
	
	clktick TICK_HALFS (
		.clk(MAX10_CLK1_50),
		.rst(1'b0),
		.en(tick_ms),
		.N(9'd499),
		.tick(tick_halfs)
	);
	
	// Obtain next state
	fsm FSM (
		.clk(tick_ms),
		.tick(tick_halfs),
		.start_trigger(~KEY[1]),
		.stop_trigger(~KEY[0]),
		.time_out(time_out),
		.en_lfsr(en_lfsr),
		.start_delay(start_delay),
		.ledr(ledr),
		.en_reaction(en_reaction),
		.mode(mode)
	);
	
	// Trigger LFSR
	lfsr LFSR (
		.clk(tick_ms),
		.en(en_lfsr),
		.prbs(prbs)
	);
	
	// Offset delay and trigger delay
	assign n = prbs + 14'd250;
	
	delay DELAY (
		.N(n),
		.clk(tick_ms),
		.trigger(start_delay),
		.time_out(time_out)
	);
	
	// Count reaction time
	counter #(.WIDTH(14)) REACTION_CTR (
		.clk(tick_ms),
		.rst(1'b0),
		.en(en_reaction),
		.count(reaction)
	);
	
	// Select display value
	assign display_value = mode ? reaction : n;
	
	// Convert to BCD
	bin2bcd_16 BIN2BCD_16 (
		.x({2'b00, display_value}),
		.BCD0(bcd0),
		.BCD1(bcd1),
		.BCD2(bcd2),
		.BCD3(bcd3),
		.BCD4(bcd4)
	);
	
	// Display on 7-Seg
	hexto7seg H0(.out(HEX0), .in(bcd0));
	hexto7seg H1(.out(HEX1), .in(bcd1));
	hexto7seg H2(.out(HEX2), .in(bcd2));
	hexto7seg H3(.out(HEX3), .in(bcd3));
	hexto7seg H4(.out(HEX4), .in(bcd4));
	
	// Trigger LED array on FPGA
	assign LEDR = ledr;

endmodule
