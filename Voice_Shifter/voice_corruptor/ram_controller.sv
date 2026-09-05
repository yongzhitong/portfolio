module ram_controller (
    input logic clk,
    input logic rst,
    input logic done_rx,
    input logic en_loaded,
    input logic [15:0] num,
    output logic [15:0] data_in,
    output logic [12:0] wraddA,
    output logic [12:0] wraddB,
    output logic [12:0] rdaddA,
    output logic [12:0] rdaddB,
    output logic wren,
    output logic loaded,
    output logic en_clear,
    output logic [12:0] GA,
    output logic [12:0] GB,
    output logic [12:0] a
);

logic [12:0] wradd_clrA, wradd_runA;
logic [12:0] wradd_clrB, wradd_runB;
logic [12:0] a_int = 13'd0;
logic done_clearA, done_clearB;
logic done_clear;
logic [1:0] delay_fsm_state;
logic [12:0] KA, KB, GA_int, GB_int;
logic loaded_int;

always_ff @(posedge clk) begin
    if(delay_fsm_state == 1'b1)
        a_int <= num;
end

counter2 #(
    .WIDTH(13)
) wradd_counter_A (
    .clk(clk),
    .rst(rst),
    .done_rx(en_loaded),
    .init(13'd3 * a_int),
    .max_count(13'd8191),
    .loaded(loaded_int),
    .count(wradd_runA)
);

counter2 #(
    .WIDTH(13)
) wradd_counter_B (
    .clk(clk),
    .rst(rst),
    .done_rx(en_loaded),
    .init(a_int),
    .max_count(13'd8191),
    .loaded(loaded_int),
    .count(wradd_runB)
);

counter3 #(
    .WIDTH(13)
) clearer_A (
    .clk(clk),
    .rst(rst),
    .en(en_clear),
    .max_count(13'd8191),
    .done(done_clearA),
    .add(wradd_clrA)
);

counter3 #(
    .WIDTH(13)
) clearer_B (
    .clk(clk),
    .rst(rst),
    .en(en_clear),
    .max_count(13'd8191),
    .done(done_clearB),
    .add(wradd_clrB)
);

assign done_clear = done_clearA || done_clearB;

delay_loader delay_fsm (
    .clk(clk),
    .done_rx(done_rx),
    .rst(rst),
    .done_clear(done_clear),
    .en_clear(en_clear),
    .loaded(loaded_int),
    .current_state(delay_fsm_state)
);

assign loaded = loaded_int;
assign wraddA = en_clear ? wradd_clrA : wradd_runA;
assign wraddB = en_clear ? wradd_clrB : wradd_runB;
assign a = a_int;

KG_controller KnG (
    .clk(clk),
    .rst(rst),
    .loaded(loaded_int),
    .en_loaded(en_loaded),
    .a(a_int),
    .KA(KA),
    .KB(KB),
    .GA(GA_int),
    .GB(GB_int)
);

assign GA = GA_int;
assign GB = GB_int;

always_comb begin
    case(delay_fsm_state)
        2'd0: begin
            wren = 1'b0;
            rdaddA = 13'd0;
            rdaddB = 13'd0;
            data_in = 16'd0;
        end
        2'd1: begin
            wren = 1'b0;
            rdaddA = 13'd0;
            rdaddB = 13'd0;
            data_in = 16'd0;
        end
        2'd2: begin
            wren = en_loaded;
            // 13-bit wrap = mod 8192. Do not use signed subtract.
            rdaddA = wraddA - KA;
            rdaddB = wraddB - KB;
            data_in = num;
        end
        2'd3: begin
            wren = 1'b1;
            rdaddA = 13'd0;
            rdaddB = 13'd0;
            data_in = 16'd0;
        end
    endcase
end

endmodule