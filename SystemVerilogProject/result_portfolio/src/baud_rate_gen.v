/*
[MODULE_INFO_START]
Name: baud_rate_gen
Role: Baud-rate tick generator for UART verification and integration
Summary:
  - Divides the system clock to generate a 16x baud tick pulse
  - Keeps the tick high for one system clock cycle
  - Used by uart_rx, uart_tx, and UART integration testbenches
StateDescription:
  - N/A (counter-based timing generator)
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module baud_rate_gen #(
  parameter integer CLK_FREQ  = 100_000_000,
  parameter integer BAUD_RATE = 9_600
) (
  input  wire iClk,
  input  wire iRst,
  output reg  oTick16x
);
  localparam integer LP_DIVISOR = CLK_FREQ / (BAUD_RATE * 16);
  localparam integer LP_CNT_W   = (LP_DIVISOR <= 2) ? 1 : $clog2(LP_DIVISOR);

  reg [LP_CNT_W-1:0] rCnt;

  always @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      rCnt     <= {LP_CNT_W{1'b0}};
      oTick16x <= 1'b0;
    end
    else begin
      oTick16x <= 1'b0;
      if (rCnt == LP_DIVISOR - 1) begin
        rCnt     <= {LP_CNT_W{1'b0}};
        oTick16x <= 1'b1;
      end
      else begin
        rCnt <= rCnt + 1'b1;
      end
    end
  end
endmodule
