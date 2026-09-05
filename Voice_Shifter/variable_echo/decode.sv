module decode #(
    parameter int BAUD_RATE  = 115200,
    parameter int CLOCK_FREQ = 50_000_000
) (
    input  logic       sys_clk,
    input  logic       rst,
    input  logic       bit_in,
    output logic [7:0] byte_out,
    output logic       valid
);

    localparam int CLK_PER_BIT   = CLOCK_FREQ / BAUD_RATE;
    localparam int CLK_PER_BIT15 = (3 * CLK_PER_BIT) / 2; // 1.5 bit times to first data sample

    typedef enum logic [1:0] {
        IDLE,
        START,
        DATA,
        STOP
    } state_t;

    state_t c_state, n_state;

    logic       en_1p5, en_1;
    logic       done_1p5, done_1;
    logic [3:0] bit_count;
    logic [7:0] shift_reg;

    counter #(
        .WIDTH(16)
    ) count1p5 (
        .clk      (sys_clk),
        .rst      (rst),
        .en       (en_1p5),
        .max_count(CLK_PER_BIT15[15:0]),
        .done     (done_1p5)
    );

    counter #(
        .WIDTH(16)
    ) count1 (
        .clk      (sys_clk),
        .rst      (rst),
        .en       (en_1),
        .max_count(CLK_PER_BIT[15:0]),
        .done     (done_1)
    );

    // State register
    always_ff @(posedge sys_clk or posedge rst) begin
        if (rst)
            c_state <= IDLE;
        else
            c_state <= n_state;
    end

    // Data path: sample on baud ticks
    always_ff @(posedge sys_clk or posedge rst) begin
        if (rst) begin
            bit_count <= '0;
            shift_reg <= '0;
            byte_out  <= '0;
            valid     <= 1'b0;
        end else begin
            valid <= 1'b0; // 1-cycle pulse when a byte is ready

            case (c_state)
                START: begin
                    if (done_1p5) begin
                        // Mid-bit sample of data bit 0 (after 1.5 bit times from start edge)
                        shift_reg[0] <= bit_in;
                        bit_count    <= 3'd1;
                    end
                end
                DATA: begin
                    if (done_1 && bit_count < 4'd8) begin
                        shift_reg[bit_count] <= bit_in;
                        bit_count <= bit_count + 4'd1;
                    end
                end
                STOP: begin
                        byte_out <= shift_reg;
                        valid    <= 1'b1;
                        bit_count <= 4'd0;
                    end
                default: ;
            endcase
        end
    end

    // Next-state + timer enables
    always_comb begin
        n_state = c_state;
        en_1p5  = 1'b0;
        en_1    = 1'b0;

        case (c_state)
            IDLE: begin
                if (!bit_in)          // falling edge into start bit
                    n_state = START;
            end
            START: begin
                en_1p5 = 1'b1;
                if (done_1p5)
                    n_state = DATA;
            end
            DATA: begin
                en_1 = 1'b1;
                en_1p5 = 1'b0;
                if (done_1 && bit_count == 4'd8)
                    n_state = STOP;
            end
            STOP: begin
                en_1 = 1'b0;
                n_state = IDLE;   // return idle whether stop bit OK or framing error
            end
            default: n_state = IDLE;
        endcase
    end

endmodule