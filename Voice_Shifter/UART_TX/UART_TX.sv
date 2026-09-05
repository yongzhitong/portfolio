module counter #(
    parameter int WIDTH = 16
) (
    input  logic             clk,
    input  logic             rst,
    input  logic             en,
    input  logic [WIDTH-1:0] max_count,
    output logic             done
);

    logic [WIDTH-1:0] count;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            count <= '0;
            done  <= 1'b0;
        end else if (!en) begin
            count <= '0;
            done  <= 1'b0;
        end else if (count == max_count - 1'b1) begin
            count <= '0;
            done  <= 1'b1;
        end else begin
            count <= count + 1'b1;
            done  <= 1'b0;
        end
    end

endmodule

//UART Transmitter
module uart_tx #(
    parameter int BAUD_RATE = 115200,
    parameter int CLOCK_FREQ = 50_000_000
) (
    input  logic       sys_clk,
    input  logic       rst,
    input  logic       en,
    input  logic [7:0] data,
    output logic       tx,
    output logic       done,
    output logic       busy
);

    localparam int CLK_PER_BIT = CLOCK_FREQ / BAUD_RATE;
    logic       en_1;
    logic       done_1;
    logic [2:0] bit_count = 3'd0;
    typedef enum logic [1:0] {
        IDLE,
        START,
        DATA,
        STOP
    } state_t;
    state_t c_state, n_state;

     counter #(
        .WIDTH(16)
    ) count1 (
        .clk      (sys_clk),
        .rst      (rst),
        .en       (en_1),
        .max_count(CLK_PER_BIT[15:0]),
        .done     (done_1)
    );

    always_ff @(posedge sys_clk or posedge rst) begin
        if (rst)
            c_state <= IDLE;
        else
            c_state <= n_state;
    end

    // Baud timer runs in START/DATA/STOP (combo avoids 1-cycle en lag)
    assign en_1 = (c_state == START) || (c_state == DATA) || (c_state == STOP);

    always_ff @(posedge sys_clk or posedge rst) begin
        if (rst) begin
            bit_count <= 3'd0;
        end else begin
            case (c_state)
                IDLE: bit_count <= 3'd0;
                DATA: begin
                    if (done_1 && bit_count < 3'd7)
                        bit_count <= bit_count + 1'b1;
                end
                STOP: begin
                    if (done_1)
                        bit_count <= 3'd0;
                end
                default: ;
            endcase
        end
    end

    // next state logic
    always_comb begin
        n_state = c_state; // default: hold state (avoids latch)
        case (c_state)
            IDLE: begin
                if (en) n_state = START;
                else    n_state = IDLE;
            end
            START: begin
                if (done_1) n_state = DATA;
                else        n_state = START;
            end
            DATA: begin
                if (done_1) begin
                    if (bit_count < 3'd7)
                        n_state = DATA;
                    else
                        n_state = STOP;
                end
            end
            STOP: begin
                if (done_1) n_state = IDLE;
                else        n_state = STOP;
            end
            default: n_state = IDLE;
        endcase
    end

    // output logic
    always_comb begin
        case (c_state)
            IDLE: begin
                tx   = 1'b1;
                busy = 1'b0;
                done = 1'b0;
            end
            START: begin
                tx   = 1'b0;
                busy = 1'b1;
                done = 1'b0;
            end
            DATA: begin
                tx   = data[bit_count];
                busy = 1'b1;
                done = 1'b0;
            end
            STOP: begin
                tx   = 1'b1;
                busy = 1'b1;
                done = done_1; // pulse when stop bit time completes
            end
            default: begin
                tx   = 1'b1;
                busy = 1'b0;
                done = 1'b0;
            end
        endcase
    end


endmodule