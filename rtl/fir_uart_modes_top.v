
module fir_uart_modes_top #(parameter integer CLKS_PER_BIT = 100) (
  input  wire       clk,
  input  wire       btn_rst,
  input  wire [1:0] sw_mode,
  input  wire       sw_bypass,
  input  wire       uart_rx_in,
  output wire       uart_tx_out,
  output wire [5:0] led
);
  reg [4:0] pu = 5'd20;
  reg rs1 = 1'b1, rs2 = 1'b1, rst_q = 1'b1, b1 = 1'b0, byp = 1'b0;
  reg [1:0] m1 = 2'b00, mode_q = 2'b00;
  always @(posedge clk) begin
    rs1 <= btn_rst; rs2 <= rs1;
    if (pu != 5'd0) pu <= pu - 5'd1;
    rst_q <= rs2 | (pu != 5'd0);
    b1 <= sw_bypass; byp <= b1;
    m1 <= sw_mode; mode_q <= m1;
  end

  wire [7:0] rx_data; wire rx_valid;
  uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_rx (.clk(clk), .rst(rst_q), .rxd(uart_rx_in), .data(rx_data), .valid(rx_valid));

  reg have_lo = 1'b0, s_valid = 1'b0;
  reg [7:0] lo = 8'd0;
  reg signed [15:0] s_data = 16'sd0;
  always @(posedge clk) begin
    s_valid <= 1'b0;
    if (rst_q) have_lo <= 1'b0;
    else if (rx_valid) begin
      if (!have_lo) begin lo <= rx_data; have_lo <= 1'b1; end
      else begin s_data <= {rx_data, lo}; s_valid <= 1'b1; have_lo <= 1'b0; end
    end
  end

  wire ov, bz;
  wire signed [39:0] dout;
  fir_filter_32tap_modes u_fir (.clk(clk), .rst(rst_q), .sample_valid(s_valid), .mode(mode_q), .data_in(s_data), .output_valid(ov), .data_out(dout), .busy(bz));

  wire signed [39:0] sc  = dout >>> 15;
  wire signed [15:0] sat = (sc >  40'sd32767) ? 16'sh7FFF :
                           (sc < -40'sd32768) ? 16'sh8000 : sc[15:0];
  wire        push_valid = byp ? s_valid : ov;
  wire [15:0] push_data  = byp ? s_data  : sat;

  reg [15:0] mem [0:63];
  reg [6:0] wp = 7'd0, rp = 7'd0;
  reg ovf = 1'b0;
  wire empty = (wp == rp);
  wire full  = (wp[5:0] == rp[5:0]) && (wp[6] != rp[6]);
  reg [7:0] tx_data = 8'd0; reg tx_start = 1'b0; reg [15:0] word = 16'd0;
  wire tx_busy;
  uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_tx (.clk(clk), .rst(rst_q), .data(tx_data), .start(tx_start), .txd(uart_tx_out), .busy(tx_busy));
  localparam [2:0] T_IDLE = 3'd0, T_LO = 3'd1, T_LOW = 3'd2, T_HI = 3'd3, T_HIW = 3'd4;
  reg [2:0] tst = T_IDLE;
  reg popped = 1'b0;
  always @(posedge clk) begin
    tx_start <= 1'b0; popped <= 1'b0;
    if (rst_q) begin wp <= 7'd0; rp <= 7'd0; ovf <= 1'b0; tst <= T_IDLE; end
    else begin
      if (push_valid) begin
        if (!full) begin mem[wp[5:0]] <= push_data; wp <= wp + 7'd1; end
        else ovf <= 1'b1;
      end
      case (tst)
        T_IDLE: if (!empty && !tx_busy) begin
                  word <= mem[rp[5:0]]; tx_data <= mem[rp[5:0]];   // low byte first (truncation to 8 bits)
                  tx_start <= 1'b1; rp <= rp + 7'd1; popped <= 1'b1; tst <= T_LO;
                end
        T_LO:   tst <= T_LOW;
        T_LOW:  if (!tx_busy) begin tx_data <= word[15:8]; tx_start <= 1'b1; tst <= T_HI; end
        T_HI:   tst <= T_HIW;
        T_HIW:  if (!tx_busy) tst <= T_IDLE;
        default: tst <= T_IDLE;
      endcase
    end
  end

  reg [21:0] rxs = 22'd0, txs = 22'd0;
  always @(posedge clk) begin
    if (rx_valid) rxs <= 22'h3FFFFF; else if (rxs != 22'd0) rxs <= rxs - 22'd1;
    if (popped)   txs <= 22'h3FFFFF; else if (txs != 22'd0) txs <= txs - 22'd1;
  end
  assign led = {ovf, byp, mode_q, (txs != 22'd0), (rxs != 22'd0)};
endmodule
