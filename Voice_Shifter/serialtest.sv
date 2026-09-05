// Tang Nano 9K LEDs are ACTIVE-LOW:
//   drive 0 -> LED ON
//   drive 1 -> LED OFF
module serialtest (
    input  logic serial,
    output logic led0,
    output logic led1
);

    // Force LED1 ON (constant 0)
    assign led1 = 1'b0;

    // Mirror UART RX onto LED0 (lit when serial is 0)
    assign led0 = serial;

endmodule
