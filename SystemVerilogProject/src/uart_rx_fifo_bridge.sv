/*
[MODULE_INFO_START]
Name: uart_rx_fifo_bridge
Role: UART RX to FIFO bridge
Summary:
  - Receives UART serial bytes through `uart_rx`
  - Pushes valid RX bytes into the existing `sync_fifo`
  - Exposes FIFO pop/data/flag interface to downstream logic or testbench
  - Serves as an integration target for UART + FIFO verification
StateDescription:
  - N/A (module composition of uart_rx and sync_fifo)
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module uart_rx_fifo_bridge #(
  parameter int AW = 4,
  parameter int DW = 8
) (
  input  logic          iClk,
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
);
  logic [DW-1:0] wRxData;
  logic          wRxValid;
  logic [DW-1:0] wFifoRData;
  logic          rPopAccepted;

  uart_rx u_uart_rx (
    .iClk    (iClk),
    .iRst    (iRst),
    .iTick16x(iTick16x),
    .iRx     (iRx),
    .oData   (wRxData),
    .oValid  (wRxValid)
  );

  sync_fifo #(
    .AW(AW),
    .DW(DW)
  ) u_sync_fifo (
    .iClk  (iClk),
    .iRstn (!iRst),
    .iWrEn (wRxValid && !oFull),
    .iRdEn (iPop),
    .iWData(wRxData),
    .oRData(wFifoRData),
    .oFull (oFull),
    .oEmpty(oEmpty)
  );

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      rPopAccepted <= 1'b0;
    end
    else begin
      // Align pop-valid with the registered sync_fifo read-data update.
      rPopAccepted <= iPop && !oEmpty;
    end
  end

  assign oRxData   = wRxData;
  assign oRxValid  = wRxValid;
  assign oPopData  = wFifoRData;
  assign oPopValid = rPopAccepted;
endmodule
