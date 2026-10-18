
module uart_tx #(parameter integer CLKS_PER_BIT = 100) (
  input  wire       clk,
  input  wire       rst,
  input  wire [7:0] data,
  input  wire       start,
  output reg        txd  = 1'b1,
  output reg        busy = 1'b0
);
  reg [15:0] cnt  = 16'd0;
  reg [3:0]  bitn = 4'd0;
  reg [9:0]  sh   = 10'h3FF;
  always @(posedge clk) begin
    if (rst) begin txd <= 1'b1; busy <= 1'b0; cnt <= 16'd0; bitn <= 4'd0; end
    else if (!busy) begin
      if (start) begin sh <= {1'b1, data, 1'b0}; busy <= 1'b1; cnt <= 16'd0; bitn <= 4'd0; txd <= 1'b0; end
    end else begin
      if (cnt == CLKS_PER_BIT - 1) begin
        cnt <= 16'd0;
        if (bitn == 4'd9) begin busy <= 1'b0; txd <= 1'b1; end
        else begin bitn <= bitn + 4'd1; txd <= sh[bitn + 4'd1]; end
      end else cnt <= cnt + 16'd1;
    end
  end
endmodule
