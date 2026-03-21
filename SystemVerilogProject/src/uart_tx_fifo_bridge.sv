/*
[MODULE_INFO_START]
Name: uart_tx_fifo_bridge
Role: FIFO-buffered UART transmitter
Summary:
  - Accepts byte pushes from system logic into an internal sync FIFO
  - Pops the next byte when UART TX becomes idle
  - Serializes queued bytes through `uart_tx`
  - Serves as a transmit-side integration target for UART + FIFO verification
StateDescription:
  - N/A (module composition with small handoff control)
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module uart_tx_fifo_bridge #(
  parameter int AW = 4,
  parameter int DW = 8
) (
  input  logic          iClk,
  input  logic          iRst,
  input  logic          iTick16x,
  input  logic          iPush,
  input  logic [DW-1:0] iPushData,
  output logic          oFull,
  output logic          oEmpty,
  output logic          oTx,
  output logic          oBusy,
  output logic [DW-1:0] oLaunchData,
  output logic          oLaunchValid
);
  logic [DW-1:0] wFifoRData;
  logic          rPopReq;
  logic          rReadIssued;
  logic          rLaunchPending;
  logic [DW-1:0] rTxData;
  logic          rTxValid;

  sync_fifo #(
    .AW(AW),
    .DW(DW)
  ) u_sync_fifo (
    .iClk  (iClk),
    .iRstn (!iRst),
    .iWrEn (iPush),
    .iRdEn (rPopReq),
    .iWData(iPushData),
    .oRData(wFifoRData),
    .oFull (oFull),
    .oEmpty(oEmpty)
  );

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      rPopReq      <= 1'b0;
      rReadIssued  <= 1'b0;
      rLaunchPending <= 1'b0;
      rTxData      <= '0;
      rTxValid     <= 1'b0;
    end
    else begin
      rPopReq    <= 1'b0;
      rTxValid   <= 1'b0;

      if (rLaunchPending) begin
        rTxData      <= wFifoRData;
        rTxValid     <= 1'b1;
        rLaunchPending <= 1'b0;
      end
      else if (rReadIssued) begin
        rReadIssued    <= 1'b0;
        rLaunchPending <= 1'b1;
      end
      else if (!oBusy && !oEmpty) begin
        rPopReq     <= 1'b1;
        rReadIssued <= 1'b1;
      end
    end
  end

  uart_tx u_uart_tx (
    .iClk    (iClk),
    .iRst    (iRst),
    .iTick16x(iTick16x),
    .iData   (rTxData),
    .iValid  (rTxValid),
    .oTx     (oTx),
    .oBusy   (oBusy)
  );

  assign oLaunchData  = rTxData;
  assign oLaunchValid = rTxValid;
endmodule
