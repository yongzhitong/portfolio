module variable_echo (
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
    logic [12:0] rdadd, rdadd_clr, rdadd_run;
    logic [12:0] wradd;
    logic [7:0] byte_out_rx;
    logic [7:0] byte_out_tx;
    logic signed [15:0] word_out;
    logic signed [15:0] ram_out;
    logic [15:0] word;
    logic en = 1'b0;
    logic valid = 1'b0;
    logic en_clear;
    logic done_clear;
    

    decode #(
        .BAUD_RATE(115200),
        .CLOCK_FREQ(27_000_000)
    ) decoder (
        .sys_clk(sys_clk),
        .rst(~rst_n),
        .bit_in(bit_in),
        .byte_out(byte_out_rx),
        .valid(valid)
    );

    assign led[0] = ~loaded;
    assign led[1] = ~en_clear;

    byte_comb combine(
        .clk(sys_clk),
        .rst(~rst_n),
        .valid(valid),
        .data(byte_out_rx),
        .done(done_rx),
        .num(word_out)
    );

    counter3 #(
        .WIDTH(13)
    ) ram_clear_address(
        .clk(sys_clk),
        .rst(~rst_n),
        .en(en_clear),
        .max_count(14'd8192),
        .done(done_clear),
        .rdadd(rdadd_clr)
    );

    delay_loader loader(
        .clk(sys_clk),
        .done_rx(done_rx),
        .rst(~rst_n),
        .num(word_out),
        .en_loaded(en_loaded),
        .rdadd(rdadd),
        .ram_out(ram_out),
        .done_clear(done_clear),
        .en_clear(en_clear),
        .loaded(loaded),
        .wren(wren),
        .wradd(wradd),
        .data_in(word)
    );

    assign en_loaded = done_rx && loaded;

    counter2 #(
        .WIDTH(13)
    ) address_counter(
        .clk(sys_clk),
        .rst(~rst_n),
        .done_rx(en_loaded),
        .max_count(14'd8192),
        .count(rdadd_run)
    );

    assign rdadd = en_clear ? rdadd_clr : rdadd_run;

    Gowin_SDP the_ram(
        .dout(ram_out), //output [15:0] dout
        .clka(sys_clk), //input clka
        .cea(wren), //input cea
        .reseta(1'b0), //input reseta
        .clkb(sys_clk), //input clkb
        .ceb(en_loaded), //input ceb
        .resetb(~rst_n), //input resetb
        .ada(wradd), //input [12:0] ada
        .din(word), //input [15:0] din
        .adb(rdadd) //input [12:0] adb
    );


    always_ff @(posedge sys_clk) begin
        if(en_loaded) begin
            done_rd <= 1'b1;
        end else if(done_rd && !busy) begin
            done_rd <= 1'b0;
            en <= 1'b1;
            byte_out_tx <= word[7:0];
            byte_count <= 1'b1;
        end else if(done_tx && byte_count) begin
            en <= 1'b1;
            byte_out_tx <= word[15:8];
            byte_count <= 1'b0;
        end
        else 
            en <= 1'b0;
    end

    transmit #(
        .BAUD_RATE(115200),
        .CLOCK_FREQ(27_000_000)
    ) transmitter (
        .sys_clk(sys_clk),
        .rst(~rst_n),
        .en(en),
        .data(byte_out_tx),
        .tx(tx),
        .done(done_tx),
        .busy(busy)
    );

endmodule