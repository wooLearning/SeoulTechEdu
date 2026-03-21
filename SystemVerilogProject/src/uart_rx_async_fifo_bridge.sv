/*
[MODULE_INFO_START]
Name: uart_rx_async_fifo_bridge
Role: UART RX to asynchronous FIFO bridge
Summary:
  - Receives UART serial bytes on the write-clock domain
  - Pushes valid RX bytes into `async_fifo`
  - Allows a separate read-clock domain to pop data independently
  - Demonstrates protocol reception plus clock-domain decoupling
StateDescription:
  - N/A (module composition of uart_rx and async_fifo)
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module uart_rx_async_fifo_bridge #(
  parameter int AW = 4,
  parameter int DW = 8
) (
  input  logic          iWrClk,
  input  logic          iRdClk,
  input  logic          iRst,
  input  logic          iTick16x,
  input  logic          iRx,
  input  logic          iPop,
  output logic [DW-1:0] oPopData,
  output logic          oPopValid,
  output logic          oFull,
  output logic          oEmpty,
  output logic [DW-1:0] oRxData,
  output logic          oRxValid
) ;
  logic [DW-1:0] wRxData;
  logic          wRxValid;
  logic [DW-1:0] wFifoRData;
  logic          rPopAccepted;

  uart_rx u_uart_rx (
    .iClk    (iWrClk),
    .iRst    (iRst),
    .iTick16x(iTick16x),
    .iRx     (iRx),
    .oData   (wRxData),
    .oValid  (wRxValid)
  );

  async_fifo #(
    .AW(AW),
    .DW(DW)
  ) u_async_fifo (
    .iWrClk (iWrClk),
    .iRdClk (iRdClk),
    .iRst   (iRst),
    .iWrEn  (wRxValid && !oFull),
    .iRdEn  (iPop),
    .iWData (wRxData),
    .oRData (wFifoRData),
    .oFull  (oFull),
    .oEmpty (oEmpty)
  );

  always_ff @(posedge iRdClk or posedge iRst) begin
    if (iRst) begin
      rPopAccepted <= 1'b0;
    end
    else begin
      rPopAccepted <= iPop && !oEmpty;
    end
  end

  assign oRxData   = wRxData;
  assign oRxValid  = wRxValid;
  assign oPopData  = wFifoRData;
  assign oPopValid = rPopAccepted;
endmodule
