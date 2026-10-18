`timescale 1ns/1ps
module tb_fir_uart_modes_top;
  localparam integer CPB = 16;           // fast baud for simulation
  reg clk = 1'b0, btn_rst = 1'b1, sw_bypass = 1'b0, uart_rx_in = 1'b1;
  reg [1:0] sw_mode = 2'd0;
  wire uart_tx_out; wire [5:0] led;
  always #5 clk = ~clk;
  fir_uart_modes_top #(.CLKS_PER_BIT(CPB)) dut (.clk(clk), .btn_rst(btn_rst), .sw_mode(sw_mode), .sw_bypass(sw_bypass),
                 .uart_rx_in(uart_rx_in), .uart_tx_out(uart_tx_out), .led(led));
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

  reg [7:0] rx_mem [0:8191]; integer rx_n = 0;
  reg signed [31:0] exp_s [0:4095]; integer exp_n = 0;
  reg signed [63:0] hist [0:31];
  integer errors = 0, total = 0, seed = 32'hBEEF1234, bi;
  reg [7:0] rb;
  initial forever begin
    @(negedge uart_tx_out);
    repeat (CPB + CPB/2) @(posedge clk);
    for (bi = 0; bi < 8; bi = bi + 1) begin rb[bi] = uart_tx_out; if (bi < 7) repeat (CPB) @(posedge clk); end
    repeat (CPB) @(posedge clk);
    rx_mem[rx_n] = rb; rx_n = rx_n + 1;
  end
  task send_byte;
    input [7:0] b;
    integer j;
    begin
      uart_rx_in = 1'b0; repeat (CPB) @(posedge clk);
      for (j = 0; j < 8; j = j + 1) begin uart_rx_in = b[j]; repeat (CPB) @(posedge clk); end
      uart_rx_in = 1'b1; repeat (CPB) @(posedge clk);
    end
  endtask
  task send_sample;
    input integer x;
    reg signed [63:0] yy, ss;
    reg [15:0] xv;
    integer q;
    begin
      xv = x[15:0];
      if (sw_bypass) exp_s[exp_n] = x;
      else begin
        for (q = 31; q > 0; q = q - 1) hist[q] = hist[q-1];
        hist[0] = x; yy = 64'sd0;
        for (q = 0; q < 32; q = q + 1) yy = yy + $signed(((q < 16) ? hm(sw_mode, q) : hm(sw_mode, 31-q))) * hist[q];
        ss = yy >>> 15;
        if (ss > 32767) ss = 32767;
        if (ss < -32768) ss = -32768;
        exp_s[exp_n] = ss;
      end
      exp_n = exp_n + 1;
      send_byte(xv[7:0]); send_byte(xv[15:8]);
    end
  endtask
  task rnd16;
    output integer v;
    integer t;
    begin t = $random(seed); v = {{16{t[15]}}, t[15:0]}; end
  endtask
  task check;
    input integer tag;
    integer bad, ii;
    reg signed [15:0] got;
    begin
      bad = 0;
      repeat (4000) @(posedge clk);
      if (rx_n != 2*exp_n) begin
        $display("test %0d: byte count mismatch rx=%0d expected=%0d", tag, rx_n, 2*exp_n); errors = errors + 1;
      end
      for (ii = 0; ii < exp_n && 2*ii+1 < rx_n; ii = ii + 1) begin
        got = {rx_mem[2*ii+1], rx_mem[2*ii]}; total = total + 1;
        if ($signed(got) != exp_s[ii]) begin
          bad = bad + 1; errors = errors + 1;
          if (bad < 8) $display("test %0d: sample %0d got %0d expected %0d", tag, ii, got, exp_s[ii]);
        end
      end
      $display("MODE %0d: %0d samples compared, %0d bad", tag, exp_n, bad);
      rx_n = 0; exp_n = 0;
    end
  endtask
  task do_reset;
    integer j;
    begin
      btn_rst = 1'b1; repeat (30) @(posedge clk); btn_rst = 1'b0;
      for (j = 0; j < 32; j = j + 1) hist[j] = 64'sd0;
      repeat (100) @(posedge clk);
    end
  endtask
  integer n, m, v;
  initial begin
    for (n = 0; n < 32; n = n + 1) hist[n] = 64'sd0;
    repeat (40) @(posedge clk);
    for (m = 0; m < 4; m = m + 1) begin
      sw_mode = m; sw_bypass = 1'b0; do_reset;
      send_sample(16384); for (n = 0; n < 40; n = n + 1) send_sample(0);
      for (n = 0; n < 20; n = n + 1) send_sample((n % 2) ? -32768 : 32767);
      for (n = 0; n < 60; n = n + 1) begin rnd16(v); send_sample(v); end
      check(m);   // MODE m: 0 LPF, 1 HPF, 2 BPF, 3 BSF
    end
    sw_mode = 2'd1; sw_bypass = 1'b1; do_reset;
    for (n = 0; n < 30; n = n + 1) begin rnd16(v); send_sample(v); end
    check(99);    // BYPASS
    $display("TOTAL compared = %0d, errors = %0d", total, errors);
    if (errors == 0 && total > 0) $display("MODES TEST: PASS"); else $display("MODES TEST: FAIL");
    $finish;
  end
  initial begin #100000000; $display("MODES TEST: FAIL (timeout)"); $finish; end
endmodule
