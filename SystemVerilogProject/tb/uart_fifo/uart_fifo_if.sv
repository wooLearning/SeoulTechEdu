/*
[TB_INFO_START]
Name: uart_fifo_if
Target: uart_rx_fifo_bridge
Role: Interface for UART RX + FIFO bridge verification
Scenario:
  - Provides serial RX input and FIFO pop/output signals
CheckPoint:
  - Keep UART timing and FIFO boundary flags grouped for verification components
[TB_INFO_END]
*/

`timescale 1ns / 1ps

interface uart_fifo_if;
  logic       iClk;
  logic       iRst;
  logic       iTick16x;
  logic       iRx;
  logic       iPop;
  logic [7:0] oPopData;
  logic       oPopValid;
  logic       oFull;
  logic       oEmpty;
  logic [7:0] oRxData;
  logic       oRxValid;
  int unsigned tbScenarioId;

  modport dut (
    input  iClk, iRst, iTick16x, iRx, iPop,
    output oPopData, oPopValid, oFull, oEmpty, oRxData, oRxValid
  );
endinterface
