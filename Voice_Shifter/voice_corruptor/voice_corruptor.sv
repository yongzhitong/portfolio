module voice_corruptor (
    input logic rst_n,
    input logic sys_clk,
    input logic bit_in,
    output logic [5:0] led,
    output logic tx
);
    logic byte_count = 1'b0;
    logic done_tx = 1'b0;
    logic done_rx = 1'b0;
    logic done_rd = 1'b0;
    logic busy = 1'b0;
    logic loaded = 1'b0;
    logic en_loaded;
    logic wren;
    logic [12:0] rdaddA, rdaddB;
    logic [12:0] wraddA, wraddB;
    logic [12:0] GA, GB;
    logic [12:0] a;
    logic [7:0] byte_out_rx;
    logic [7:0] byte_out_tx;
    logic [15:0] word_out;
    logic signed [15:0] ram_in;
    logic signed [15:0] ram_outA, ram_outB;
    logic en_tx = 1'b0;
    logic valid_rx = 1'b0;
    logic en_clear;
    

    decode #(
        .BAUD_RATE(115200),
        .CLOCK_FREQ(27_000_000)
    ) decoder (
        .sys_clk(sys_clk),
        .rst(~rst_n),
        .bit_in(bit_in),
        .byte_out(byte_out_rx),
        .valid(valid_rx)
    );

    assign led[0] = ~loaded;
    assign led[1] = ~en_clear;

    byte_comb combine(
        .clk(sys_clk),
        .rst(~rst_n),
        .valid(valid_rx),
        .data(byte_out_rx),
        .done(done_rx),
        .num(word_out)
    );

    ram_controller the_ram_controller (
        .clk(sys_clk),
        .rst(~rst_n),
        .done_rx(done_rx),
        .en_loaded(en_loaded),
        .num(word_out),
        .data_in(ram_in),
        .wraddA(wraddA),
        .wraddB(wraddB),
        .rdaddA(rdaddA),
        .rdaddB(rdaddB),
        .wren(wren),
        .loaded(loaded),
        .GA(GA),
        .GB(GB),
        .a(a),
        .en_clear(en_clear)
    );

    assign en_loaded = loaded && done_rx;   

    Gowin_SDP ram_channelA(
        .dout(ram_outA), //output [15:0] dout
        .clka(sys_clk), //input clka
        .cea(wren), //input cea
        .reseta(1'b0), //input reseta
        .clkb(sys_clk), //input clkb
        .ceb(en_loaded), //input ceb
        .resetb(1'b0), //input resetb
        .ada(wraddA), //input [12:0] ada
        .din(ram_in), //input [15:0] din
        .adb(rdaddA) //input [12:0] adb
    );

    Gowin_SDP ram_channelB(
        .dout(ram_outB), //output [15:0] dout
        .clka(sys_clk), //input clka
        .cea(wren), //input cea
        .reseta(1'b0), //input reseta
        .clkb(sys_clk), //input clkb
        .ceb(en_loaded), //input ceb
        .resetb(1'b0), //input resetb
        .ada(wraddB), //input [12:0] ada
        .din(ram_in), //input [15:0] din
        .adb(rdaddB) //input [12:0] adb
    );

    logic signed [13:0] ga_s, gb_s, denominator;
    logic signed [29:0] productA, productB;
    logic signed [30:0] mix_sum;
    logic signed [15:0] word;

    assign ga_s = $signed({1'b0, GA});
    assign gb_s = $signed({1'b0, GB});

    assign denominator =
        ($signed({1'b0, a}) <<< 1) - 14'sd1;

    assign productA = ga_s * ram_outA;
    assign productB = gb_s * ram_outB;

    assign mix_sum =
        $signed({productA[29], productA}) +
        $signed({productB[29], productB});

    assign word = (denominator == 0) ? 16'sd0 : mix_sum / denominator;

    always_ff @(posedge sys_clk) begin
        if(en_loaded) begin
            done_rd <= 1'b1;
        end else if(done_rd && !busy) begin
            done_rd <= 1'b0;
            en_tx <= 1'b1;
            byte_out_tx <= word[7:0];
            byte_count <= 1'b1;
        end else if(done_tx && byte_count) begin
            en_tx <= 1'b1;
            byte_out_tx <= word[15:8];
            byte_count <= 1'b0;
        end
        else 
            en_tx <= 1'b0;
    end

    transmit #(
        .BAUD_RATE(115200),
        .CLOCK_FREQ(27_000_000)
    ) transmitter (
        .sys_clk(sys_clk),
        .rst(~rst_n),
        .en(en_tx),
        .data(byte_out_tx),
        .tx(tx),
        .done(done_tx),
        .busy(busy)
    );

endmodule