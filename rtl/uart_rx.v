
module uart_rx #(parameter integer CLKS_PER_BIT = 100) (
  input  wire       clk,
  input  wire       rst,
  input  wire       rxd,
  output reg  [7:0] data  = 8'd0,
  output reg        valid = 1'b0
);
  localparam [1:0] IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;
  reg [1:0]  st  = IDLE;
  reg [15:0] cnt = 16'd0;
  reg [2:0]  idx = 3'd0;
  reg [7:0]  sh  = 8'd0;
  reg r1 = 1'b1, r2 = 1'b1;
  always @(posedge clk) begin
    r1 <= rxd; r2 <= r1; valid <= 1'b0;
    if (rst) begin st <= IDLE; cnt <= 16'd0; idx <= 3'd0; end
    else case (st)
      IDLE:  if (!r2) begin st <= START; cnt <= 16'd0; end
      START: if (cnt == CLKS_PER_BIT/2 - 1) begin
               cnt <= 16'd0; idx <= 3'd0;
               if (!r2) st <= DATA; else st <= IDLE;
             end else cnt <= cnt + 16'd1;
      DATA:  if (cnt == CLKS_PER_BIT - 1) begin
               cnt <= 16'd0; sh <= {r2, sh[7:1]};
               if (idx == 3'd7) st <= STOP; else idx <= idx + 3'd1;
             end else cnt <= cnt + 16'd1;
      STOP:  if (cnt == CLKS_PER_BIT - 1) begin
               cnt <= 16'd0; st <= IDLE;
               if (r2) begin data <= sh; valid <= 1'b1; end
             end else cnt <= cnt + 16'd1;
      default: st <= IDLE;
    endcase
  end
endmodule
