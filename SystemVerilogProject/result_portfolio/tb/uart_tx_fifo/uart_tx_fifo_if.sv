/*
[TB_INFO_START]
Name: uart_tx_fifo_if
Target: uart_tx_fifo_bridge
Role: Interface for UART TX + FIFO verification
Scenario:
  - Provides FIFO push signals and loopback RX observation points
CheckPoint:
  - Keep TX-side enqueue control and RX sink observation grouped
[TB_INFO_END]
*/

`timescale 1ns / 1ps

interface uart_tx_fifo_if;
  logic       iClk;
  logic       iRst;
  logic       iTick16x;
  logic       iPush;
  logic [7:0] iPushData;
  logic       oTx;
  logic       oBusy;
  logic       oFull;
  logic       oEmpty;
  logic [7:0] oLaunchData;
  logic       oLaunchValid;
  logic [7:0] oSinkData;
  logic       oSinkValid;
  int unsigned tbScenarioId;

  modport dut (
    input  iClk, iRst, iTick16x, iPush, iPushData,
    output oTx, oBusy, oFull, oEmpty, oLaunchData, oLaunchValid
  );
endinterface
