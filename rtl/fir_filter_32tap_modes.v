module fir_filter_32tap_modes (
  input  wire               clk,
  input  wire               rst,
  input  wire               sample_valid,
  input  wire        [1:0]  mode,
  input  wire signed [15:0] data_in,
  output wire               output_valid,
  output reg  signed [39:0] data_out,
  output wire               busy
);
  assign busy = 1'b0;
  function signed [15:0] hm;
    input [1:0] m;
    input integer k;
    begin
      case (m)
        2'd0: case (k)
          0: hm = 16'sd30;
          1: hm = -16'sd36;
          2: hm = -16'sd82;
          3: hm = 16'sd0;
          4: hm = 16'sd183;
          5: hm = 16'sd165;
          6: hm = -16'sd233;
          7: hm = -16'sd522;
          8: hm = 16'sd0;
          9: hm = 16'sd951;
          10: hm = 16'sd787;
          11: hm = -16'sd1064;
          12: hm = -16'sd2395;
          13: hm = 16'sd0;
          14: hm = 16'sd6154;
          15: hm = 16'sd11628;
          default: hm = 16'sd0;
        endcase
        2'd1: case (k)
          0: hm = -16'sd15;
          1: hm = 16'sd104;
          2: hm = -16'sd146;
          3: hm = 16'sd38;
          4: hm = -16'sd56;
          5: hm = 16'sd476;
          6: hm = -16'sd674;
          7: hm = 16'sd160;
          8: hm = -16'sd217;
          9: hm = 16'sd1699;
          10: hm = -16'sd2275;
          11: hm = 16'sd528;
          12: hm = -16'sd734;
          13: hm = 16'sd6351;
          14: hm = -16'sd10996;
          15: hm = 16'sd5768;
          default: hm = 16'sd0;
        endcase
        2'd2: case (k)
          0: hm = -16'sd22;
          1: hm = -16'sd27;
          2: hm = -16'sd98;
          3: hm = 16'sd182;
          4: hm = 16'sd219;
          5: hm = -16'sd122;
          6: hm = 16'sd173;
          7: hm = -16'sd626;
          8: hm = -16'sd1050;
          9: hm = 16'sd1141;
          10: hm = 16'sd583;
          11: hm = 16'sd789;
          12: hm = 16'sd2874;
          13: hm = -16'sd5270;
          14: hm = -16'sd7383;
          15: hm = 16'sd8622;
          default: hm = 16'sd0;
        endcase
        2'd3: case (k)
          0: hm = -16'sd9;
          1: hm = 16'sd61;
          2: hm = 16'sd0;
          3: hm = -16'sd35;
          4: hm = -16'sd404;
          5: hm = 16'sd389;
          6: hm = -16'sd570;
          7: hm = 16'sd1177;
          8: hm = 16'sd305;
          9: hm = -16'sd145;
          10: hm = -16'sd1910;
          11: hm = 16'sd1012;
          12: hm = -16'sd5382;
          13: hm = 16'sd8985;
          14: hm = 16'sd935;
          15: hm = 16'sd11081;
          default: hm = 16'sd0;
        endcase
        default: hm = 16'sd0;
      endcase
    end
  endfunction

  reg [511:0] dl;
  reg signed [15:0] coef [0:15];
  reg signed [16:0] pre_r  [0:15];
  reg signed [32:0] prod_r [0:15];
  reg signed [39:0] s8 [0:7];
  reg signed [39:0] s4 [0:3];
  reg signed [39:0] s2 [0:1];
  reg [6:0] vld;
  assign output_valid = vld[6];
  integer k;
  always @(posedge clk) begin
    for (k = 0; k < 16; k = k + 1) coef[k] <= hm(mode, k);
    if (rst) begin
      dl <= 512'd0;
      for (k = 0; k < 16; k = k + 1) begin pre_r[k] <= 17'sd0; prod_r[k] <= 33'sd0; end
      for (k = 0; k < 8; k = k + 1)  s8[k] <= 40'sd0;
      for (k = 0; k < 4; k = k + 1)  s4[k] <= 40'sd0;
      s2[0] <= 40'sd0; s2[1] <= 40'sd0; data_out <= 40'sd0; vld <= 7'd0;
    end else begin
      if (sample_valid) dl <= {dl[495:0], data_in};
      for (k = 0; k < 16; k = k + 1) begin
        pre_r[k]  <= $signed(dl[16*k +: 16]) + $signed(dl[16*(31-k) +: 16]);
        prod_r[k] <= pre_r[k] * coef[k];
      end
      for (k = 0; k < 8; k = k + 1) s8[k] <= prod_r[2*k] + prod_r[2*k+1];
      for (k = 0; k < 4; k = k + 1) s4[k] <= s8[2*k] + s8[2*k+1];
      s2[0]    <= s4[0] + s4[1];
      s2[1]    <= s4[2] + s4[3];
      data_out <= s2[0] + s2[1];
      vld      <= {vld[5:0], sample_valid};
    end
  end
endmodule
