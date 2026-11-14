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

    // state 8
    if (cycle == 7) begin
    end

    // state 9
    if (cycle == 8) begin
    end

    // state 10
    if (cycle == 9) begin
    end

    // state 11
    if (cycle == 10) begin
    end

    // state 12
    if (cycle == 11) begin
    end

    // state 13
    if (cycle == 12) begin
    end

    // state 14
    if (cycle == 13) begin
    end

    // state 15
    if (cycle == 14) begin
    end

    // state 16
    if (cycle == 15) begin
    end

    // state 17
    if (cycle == 16) begin
    end

    // state 18
    if (cycle == 17) begin
    end

    // state 19
    if (cycle == 18) begin
    end

    // state 20
    if (cycle == 19) begin
    end

    // state 21
    if (cycle == 20) begin
    end

    // state 22
    if (cycle == 21) begin
    end

    // state 23
    if (cycle == 22) begin
    end

    // state 24
    if (cycle == 23) begin
    end

    // state 25
    if (cycle == 24) begin
    end

    // state 26
    if (cycle == 25) begin
    end

    // state 27
    if (cycle == 26) begin
    end

    // state 28
    if (cycle == 27) begin
    end

    // state 29
    if (cycle == 28) begin
    end

    // state 30
    if (cycle == 29) begin
    end

    // state 31
    if (cycle == 30) begin
    end

    // state 32
    if (cycle == 31) begin
    end

    // state 33
    if (cycle == 32) begin
    end

    // state 34
    if (cycle == 33) begin
    end

    // state 35
    if (cycle == 34) begin
    end

    // state 36
    if (cycle == 35) begin
    end

    // state 37
    if (cycle == 36) begin
    end

    // state 38
    if (cycle == 37) begin
    end

    // state 39
    if (cycle == 38) begin
    end

    // state 40
    if (cycle == 39) begin
    end

    // state 41
    if (cycle == 40) begin
    end

    // state 42
    if (cycle == 41) begin
    end

    // state 43
    if (cycle == 42) begin
    end

    // state 44
    if (cycle == 43) begin
    end

    // state 45
    if (cycle == 44) begin
    end

    // state 46
    if (cycle == 45) begin
    end

    // state 47
    if (cycle == 46) begin
    end

    // state 48
    if (cycle == 47) begin
    end

    // state 49
    if (cycle == 48) begin
    end

    // state 50
    if (cycle == 49) begin
    end

    // state 51
    if (cycle == 50) begin
    end

    // state 52
    if (cycle == 51) begin
    end

    // state 53
    if (cycle == 52) begin
    end

    // state 54
    if (cycle == 53) begin
    end

    // state 55
    if (cycle == 54) begin
    end

    // state 56
    if (cycle == 55) begin
    end

    // state 57
    if (cycle == 56) begin
    end

    // state 58
    if (cycle == 57) begin
    end

    // state 59
    if (cycle == 58) begin
    end

    // state 60
    if (cycle == 59) begin
    end

    // state 61
    if (cycle == 60) begin
    end

    // state 62
    if (cycle == 61) begin
    end

    // state 63
    if (cycle == 62) begin
    end

    // state 64
    if (cycle == 63) begin
    end

    // state 65
    if (cycle == 64) begin
    end

    // state 66
    if (cycle == 65) begin
    end

    // state 67
    if (cycle == 66) begin
    end

    // state 68
    if (cycle == 67) begin
    end

    // state 69
    if (cycle == 68) begin
    end

    // state 70
    if (cycle == 69) begin
    end

    // state 71
    if (cycle == 70) begin
    end

    // state 72
    if (cycle == 71) begin
    end

    // state 73
    if (cycle == 72) begin
    end

    // state 74
    if (cycle == 73) begin
    end

    // state 75
    if (cycle == 74) begin
    end

    // state 76
    if (cycle == 75) begin
    end

    // state 77
    if (cycle == 76) begin
    end

    // state 78
    if (cycle == 77) begin
    end

    // state 79
    if (cycle == 78) begin
    end

    // state 80
    if (cycle == 79) begin
    end

    // state 81
    if (cycle == 80) begin
    end

    // state 82
    if (cycle == 81) begin
    end

    // state 83
    if (cycle == 82) begin
    end

    // state 84
    if (cycle == 83) begin
    end

    // state 85
    if (cycle == 84) begin
    end

    // state 86
    if (cycle == 85) begin
    end

    // state 87
    if (cycle == 86) begin
    end

    // state 88
    if (cycle == 87) begin
    end

    // state 89
    if (cycle == 88) begin
    end

    // state 90
    if (cycle == 89) begin
    end

    // state 91
    if (cycle == 90) begin
    end

    // state 92
    if (cycle == 91) begin
    end

    // state 93
    if (cycle == 92) begin
    end

    // state 94
    if (cycle == 93) begin
    end

    // state 95
    if (cycle == 94) begin
    end

    // state 96
    if (cycle == 95) begin
    end

    // state 97
    if (cycle == 96) begin
    end

    // state 98
    if (cycle == 97) begin
    end

    // state 99
    if (cycle == 98) begin
    end

    // state 100
    if (cycle == 99) begin
    end

    // state 101
    if (cycle == 100) begin
    end

    // state 102
    if (cycle == 101) begin
    end

    // state 103
    if (cycle == 102) begin
    end

    // state 104
    if (cycle == 103) begin
    end

    // state 105
    if (cycle == 104) begin
    end

    // state 106
    if (cycle == 105) begin
    end

    // state 107
    if (cycle == 106) begin
    end

    // state 108
    if (cycle == 107) begin
    end

    // state 109
    if (cycle == 108) begin
    end

    // state 110
    if (cycle == 109) begin
    end

    // state 111
    if (cycle == 110) begin
    end

    // state 112
    if (cycle == 111) begin
    end

    // state 113
    if (cycle == 112) begin
    end

    // state 114
    if (cycle == 113) begin
    end

    // state 115
    if (cycle == 114) begin
    end

    // state 116
    if (cycle == 115) begin
    end

    // state 117
    if (cycle == 116) begin
    end

    // state 118
    if (cycle == 117) begin
    end

    // state 119
    if (cycle == 118) begin
    end

    // state 120
    if (cycle == 119) begin
    end

    // state 121
    if (cycle == 120) begin
    end

    // state 122
    if (cycle == 121) begin
    end

    // state 123
    if (cycle == 122) begin
    end

    // state 124
    if (cycle == 123) begin
    end

    // state 125
    if (cycle == 124) begin
    end

    // state 126
    if (cycle == 125) begin
    end

    // state 127
    if (cycle == 126) begin
    end

    // state 128
    if (cycle == 127) begin
    end

    // state 129
    if (cycle == 128) begin
    end

    // state 130
    if (cycle == 129) begin
    end

    // state 131
    if (cycle == 130) begin
    end

    // state 132
    if (cycle == 131) begin
    end

    // state 133
    if (cycle == 132) begin
    end

    // state 134
    if (cycle == 133) begin
    end

    // state 135
    if (cycle == 134) begin
    end

    // state 136
    if (cycle == 135) begin
    end

    // state 137
    if (cycle == 136) begin
    end

    // state 138
    if (cycle == 137) begin
    end

    // state 139
    if (cycle == 138) begin
    end

    // state 140
    if (cycle == 139) begin
    end

    // state 141
    if (cycle == 140) begin
    end

    // state 142
    if (cycle == 141) begin
    end

    // state 143
    if (cycle == 142) begin
    end

    // state 144
    if (cycle == 143) begin
    end

    // state 145
    if (cycle == 144) begin
    end

    // state 146
    if (cycle == 145) begin
    end

    // state 147
    if (cycle == 146) begin
    end

    // state 148
    if (cycle == 147) begin
    end

    // state 149
    if (cycle == 148) begin
    end

    // state 150
    if (cycle == 149) begin
    end

    // state 151
    if (cycle == 150) begin
    end

    // state 152
    if (cycle == 151) begin
    end

    // state 153
    if (cycle == 152) begin
    end

    // state 154
    if (cycle == 153) begin
    end

    // state 155
    if (cycle == 154) begin
    end

    // state 156
    if (cycle == 155) begin
    end

    // state 157
    if (cycle == 156) begin
    end

    // state 158
    if (cycle == 157) begin
    end

    // state 159
    if (cycle == 158) begin
    end

    // state 160
    if (cycle == 159) begin
    end

    // state 161
    if (cycle == 160) begin
    end

    // state 162
    if (cycle == 161) begin
    end

    // state 163
    if (cycle == 162) begin
    end

    // state 164
    if (cycle == 163) begin
    end

    // state 165
    if (cycle == 164) begin
    end

    // state 166
    if (cycle == 165) begin
    end

    // state 167
    if (cycle == 166) begin
    end

    // state 168
    if (cycle == 167) begin
    end

    // state 169
    if (cycle == 168) begin
    end

    // state 170
    if (cycle == 169) begin
    end

    // state 171
    if (cycle == 170) begin
    end

    // state 172
    if (cycle == 171) begin
    end

    // state 173
    if (cycle == 172) begin
    end

    // state 174
    if (cycle == 173) begin
    end

    // state 175
    if (cycle == 174) begin
    end

    // state 176
    if (cycle == 175) begin
    end

    // state 177
    if (cycle == 176) begin
    end

    // state 178
    if (cycle == 177) begin
    end

    // state 179
    if (cycle == 178) begin
    end

    // state 180
    if (cycle == 179) begin
    end

    // state 181
    if (cycle == 180) begin
    end

    // state 182
    if (cycle == 181) begin
    end

    // state 183
    if (cycle == 182) begin
    end

    // state 184
    if (cycle == 183) begin
    end

    // state 185
    if (cycle == 184) begin
    end

    // state 186
    if (cycle == 185) begin
    end

    // state 187
    if (cycle == 186) begin
    end

    // state 188
    if (cycle == 187) begin
    end

    // state 189
    if (cycle == 188) begin
    end

    // state 190
    if (cycle == 189) begin
    end

    // state 191
    if (cycle == 190) begin
    end

    // state 192
    if (cycle == 191) begin
    end

    // state 193
    if (cycle == 192) begin
    end

    // state 194
    if (cycle == 193) begin
    end

    // state 195
    if (cycle == 194) begin
    end

    // state 196
    if (cycle == 195) begin
    end

    // state 197
    if (cycle == 196) begin
    end

    // state 198
    if (cycle == 197) begin
    end

    // state 199
    if (cycle == 198) begin
    end

    // state 200
    if (cycle == 199) begin
    end

    // state 201
    if (cycle == 200) begin
    end

    // state 202
    if (cycle == 201) begin
    end

    // state 203
    if (cycle == 202) begin
    end

    // state 204
    if (cycle == 203) begin
    end

    // state 205
    if (cycle == 204) begin
    end

    // state 206
    if (cycle == 205) begin
    end

    // state 207
    if (cycle == 206) begin
    end

    // state 208
    if (cycle == 207) begin
    end

    // state 209
    if (cycle == 208) begin
    end

    // state 210
    if (cycle == 209) begin
    end

    // state 211
    if (cycle == 210) begin
    end

    // state 212
    if (cycle == 211) begin
    end

    // state 213
    if (cycle == 212) begin
    end

    // state 214
    if (cycle == 213) begin
    end

    // state 215
    if (cycle == 214) begin
    end

    // state 216
    if (cycle == 215) begin
    end

    // state 217
    if (cycle == 216) begin
    end

    // state 218
    if (cycle == 217) begin
    end

    // state 219
    if (cycle == 218) begin
    end

    // state 220
    if (cycle == 219) begin
    end

    // state 221
    if (cycle == 220) begin
    end

    // state 222
    if (cycle == 221) begin
    end

    // state 223
    if (cycle == 222) begin
    end

    // state 224
    if (cycle == 223) begin
    end

    // state 225
    if (cycle == 224) begin
    end

    // state 226
    if (cycle == 225) begin
    end

    // state 227
    if (cycle == 226) begin
    end

    // state 228
    if (cycle == 227) begin
    end

    // state 229
    if (cycle == 228) begin
    end

    // state 230
    if (cycle == 229) begin
    end

    // state 231
    if (cycle == 230) begin
    end

    // state 232
    if (cycle == 231) begin
    end

    // state 233
    if (cycle == 232) begin
    end

    // state 234
    if (cycle == 233) begin
    end

    // state 235
    if (cycle == 234) begin
    end

    // state 236
    if (cycle == 235) begin
    end

    // state 237
    if (cycle == 236) begin
    end

    // state 238
    if (cycle == 237) begin
    end

    // state 239
    if (cycle == 238) begin
    end

    // state 240
    if (cycle == 239) begin
    end

    // state 241
    if (cycle == 240) begin
    end

    // state 242
    if (cycle == 241) begin
    end

    // state 243
    if (cycle == 242) begin
    end

    // state 244
    if (cycle == 243) begin
    end

    // state 245
    if (cycle == 244) begin
    end

    // state 246
    if (cycle == 245) begin
    end

    // state 247
    if (cycle == 246) begin
    end

    // state 248
    if (cycle == 247) begin
    end

    // state 249
    if (cycle == 248) begin
    end

    // state 250
    if (cycle == 249) begin
    end

    // state 251
    if (cycle == 250) begin
    end

    // state 252
    if (cycle == 251) begin
    end

    // state 253
    if (cycle == 252) begin
    end

    // state 254
    if (cycle == 253) begin
    end

    // state 255
    if (cycle == 254) begin
    end

    // state 256
    if (cycle == 255) begin
    end

    // state 257
    if (cycle == 256) begin
    end

    // state 258
    if (cycle == 257) begin
    end

    // state 259
    if (cycle == 258) begin
    end

    // state 260
    if (cycle == 259) begin
    end

    // state 261
    if (cycle == 260) begin
    end

    // state 262
    if (cycle == 261) begin
    end

    // state 263
    if (cycle == 262) begin
    end

    // state 264
    if (cycle == 263) begin
    end

    genclock <= cycle < 264;
    cycle <= cycle + 1;
  end
endmodule
