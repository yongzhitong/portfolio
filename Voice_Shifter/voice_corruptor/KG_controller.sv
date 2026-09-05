module KG_controller (
    input logic clk,
    input logic rst,
    input logic loaded,
    input logic en_loaded,
    input logic [12:0] a,
    output logic [12:0] KA,
    output logic [12:0] KB,
    output logic [12:0] GA,
    output logic [12:0] GB
);

    logic en_2a_counter;
    logic done_2a;
    logic en_KA, en_KB, en_GA, en_GB;
    logic flag_KA, flag_KB, flag_GA, flag_GB;
    logic flag_KA_init, flag_KB_init;
    logic change_GA, change_GB;

    counter4 #(
        .WIDTH(13)
    ) twoa_counter (
        .clk(clk),
        .rst(rst),
        .en(en_2a_counter),
        .max_count(13'd2*a),
        .done(done_2a)
    );

    down_counter #(
        .WIDTH(13)
    ) KA_counter (
        .clk(clk),
        .rst(rst),
        .en(en_KA),
        .reload_flag1(flag_KA),
        .reload_flag2(flag_KA_init),
        .max_count(13'd3*a - 1'b1),
        .init(13'd3*a - 1'b1),
        .count(KA)
    );

    down_counter #(
        .WIDTH(13)
    ) KB_counter (
        .clk(clk),
        .rst(rst),
        .en(en_KB),
        .reload_flag1(flag_KB),
        .reload_flag2(flag_KB_init),
        .max_count(13'd3*a - 1'b1),
        .init(a - 1'b1),
        .count(KB)
    );

    updown_counter #(
        .WIDTH(13)
    ) GA_counter (
        .clk(clk),
        .rst(rst),
        .en(en_GA),
        .change(change_GA),
        .max_count(13'd2*a - 1'b1),
        .reload_flag(flag_GA),
        .count(GA)
    );

    updown_counter #(
        .WIDTH(13)
    ) GB_counter (
        .clk(clk),
        .rst(rst),
        .en(en_GB),
        .change(change_GB),
        .max_count(13'd2*a - 1'b1),
        .reload_flag(flag_GB),
        .count(GB)
    );

    typedef enum {IDLE, RAMP_GA, ONE_GA, RAMP_GB, ONE_GB} mystate;
    mystate c_state, n_state;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
        end else begin
            c_state <= n_state;
        end
    end

    always_comb begin
        case(c_state)
            IDLE: begin
                if(loaded)
                    n_state = RAMP_GA;
                else 
                    n_state= IDLE;
            end
            RAMP_GA: begin
                if(done_2a)
                    n_state = ONE_GA;
                else
                    n_state = RAMP_GA;
            end
            ONE_GA: begin
                if(done_2a)
                    n_state = RAMP_GB;
                else
                    n_state = ONE_GA;
            end
            RAMP_GB: begin
                if(done_2a)
                    n_state = ONE_GB;
                else
                    n_state = RAMP_GB;
            end
            ONE_GB: begin
                if(done_2a)
                    n_state = RAMP_GA;
                else
                    n_state = ONE_GB;
            end
            default: n_state = IDLE;
        endcase
    end

    always_comb begin
        case(c_state)
            IDLE: begin
                en_KA = 1'b0;
                en_KB = 1'b0;
                en_GA = 1'b0;
                en_GB = 1'b0;
                flag_KA = 1'b0;
                flag_KA_init = 1'b0;
                flag_KB = 1'b0;
                flag_KB_init = 1'b0;
                flag_GA = 1'b0;
                flag_GB = 1'b0;
                change_GA = 1'b0;
                change_GB = 1'b0;
                en_2a_counter = 1'b0;
            end
            RAMP_GA: begin
                en_KA = en_loaded;
                en_KB = en_loaded;
                en_GA = en_loaded;
                en_GB = en_loaded;
                flag_KA = 1'b1;
                flag_KA_init = 1'b1;
                flag_KB = 1'b0;
                flag_KB_init = 1'b1;
                flag_GA = 1'b1;
                flag_GB = 1'b1;
                change_GA = 1'b1;
                change_GB = 1'b0;
                en_2a_counter = en_loaded;
            end
            ONE_GA: begin
                en_KA = en_loaded;
                en_KB = en_loaded;
                en_GA = en_loaded;
                en_GB = en_loaded;
                flag_KA = 1'b0;
                flag_KA_init = 1'b0;
                flag_KB = 1'b0;
                flag_KB_init = 1'b0;
                flag_GA = 1'b0;
                flag_GB = 1'b0;
                change_GA = 1'b1;
                change_GB = 1'b0;
                en_2a_counter = en_loaded;
            end
            RAMP_GB: begin
                en_KA = en_loaded;
                en_KB = en_loaded;
                en_GA = en_loaded;
                en_GB = en_loaded;
                flag_KA = 1'b0;
                flag_KA_init = 1'b0;
                flag_KB = 1'b1;
                flag_KB_init = 1'b0;
                flag_GA = 1'b0;
                flag_GB = 1'b0;
                change_GA = 1'b0;
                change_GB = 1'b1;
                en_2a_counter = en_loaded;
            end
            ONE_GB: begin
                en_KA = en_loaded;
                en_KB = en_loaded;
                en_GA = en_loaded;
                en_GB = en_loaded;
                flag_KA = 1'b0;
                flag_KA_init = 1'b0;
                flag_KB = 1'b0;
                flag_KB_init = 1'b0;
                flag_GA = 1'b0;
                flag_GB = 1'b0;
                change_GA = 1'b0;
                change_GB = 1'b1;
                en_2a_counter = en_loaded;
            end
        endcase
    end

endmodule