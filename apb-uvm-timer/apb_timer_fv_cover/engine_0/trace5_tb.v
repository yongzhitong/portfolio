`ifndef VERILATOR
module testbench;
  reg [4095:0] vcdfile;
  reg clock;
`else
module testbench(input clock, output reg genclock);
  initial genclock = 1;
`endif
  reg genclock = 1;
  reg [31:0] cycle = 0;
  apb_timer_formal UUT (

  );
`ifndef VERILATOR
  initial begin
    if ($value$plusargs("vcd=%s", vcdfile)) begin
      $dumpfile(vcdfile);
      $dumpvars(0, testbench);
    end
    #5 clock = 0;
    while (genclock) begin
      #5 clock = 0;
      #5 clock = 1;
    end
  end
`endif
  initial begin
`ifndef VERILATOR
    #1;
`endif
    // UUT.$auto$async2sync.\cc:107:execute$478  = 1'b0;
    // UUT.$auto$async2sync.\cc:107:execute$484  = 1'b0;
    // UUT.$auto$async2sync.\cc:107:execute$490  = 1'b0;
    // UUT.$auto$async2sync.\cc:107:execute$496  = 1'b0;
    // UUT.$auto$async2sync.\cc:116:execute$440  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$446  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$452  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$464  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$470  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$476  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$482  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$488  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$494  = 1'b1;
    UUT._witness_.anyinit_procdff_389 = 8'b00000000;
    UUT._witness_.anyinit_procdff_390 = 8'b00000000;
    UUT._witness_.anyinit_procdff_391 = 8'b00000000;
    UUT._witness_.anyinit_procdff_392 = 8'b00000000;
    UUT._witness_.anyinit_procdff_393 = 1'b0;
    UUT._witness_.anyinit_procdff_394 = 4'b0000;
    UUT._witness_.anyinit_procdff_395 = 1'b0;
    UUT._witness_.anyinit_procdff_396 = 4'b0000;
    UUT._witness_.anyinit_procdff_400 = 8'b00000000;
    UUT.dut._witness_.anyinit_procdff_385 = 8'b00000000;
    UUT.dut._witness_.anyinit_procdff_388 = 8'b00000000;
    UUT.dut.timer_inst._witness_.anyinit_procdff_379 = 8'b00000000;
    UUT.dut.timer_inst._witness_.anyinit_procdff_382 = 1'b0;
    UUT.limit_change = 1'b0;
    UUT.limit_larger = 1'b0;
    UUT.limit_smaller = 1'b0;
    UUT.rst_count = 3'b000;

    // state 0
  end
  always @(posedge clock) begin
    // state 1
    if (cycle == 0) begin
    end

    // state 2
    if (cycle == 1) begin
    end

    // state 3
    if (cycle == 2) begin
    end

    // state 4
    if (cycle == 3) begin
    end

    // state 5
    if (cycle == 4) begin
    end

    // state 6
    if (cycle == 5) begin
    end

    // state 7
    if (cycle == 6) begin
    end

    genclock <= cycle < 7;
    cycle <= cycle + 1;
  end
endmodule
