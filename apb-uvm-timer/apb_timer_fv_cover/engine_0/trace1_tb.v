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
    // UUT.$auto$async2sync.\cc:107:execute$326  = 1'b0;
    // UUT.$auto$async2sync.\cc:107:execute$350  = 1'b0;
    // UUT.$auto$async2sync.\cc:107:execute$356  = 1'b0;
    // UUT.$auto$async2sync.\cc:116:execute$330  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$336  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$342  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$348  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$354  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$360  = 1'b1;
    UUT._witness_.anyinit_procdff_302 = 8'b00000000;
    UUT._witness_.anyinit_procdff_303 = 8'b00000000;
    UUT._witness_.anyinit_procdff_304 = 8'b00000000;
    UUT._witness_.anyinit_procdff_305 = 1'b0;
    UUT._witness_.anyinit_procdff_306 = 4'b0000;
    UUT._witness_.anyinit_procdff_307 = 1'b0;
    UUT._witness_.anyinit_procdff_308 = 4'b0000;
    UUT.dut._witness_.anyinit_procdff_298 = 8'b00000000;
    UUT.dut._witness_.anyinit_procdff_301 = 8'b00000000;
    UUT.dut.timer_inst._witness_.anyinit_procdff_292 = 8'b00000000;
    UUT.dut.timer_inst._witness_.anyinit_procdff_295 = 1'b0;
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

    genclock <= cycle < 4;
    cycle <= cycle + 1;
  end
endmodule
