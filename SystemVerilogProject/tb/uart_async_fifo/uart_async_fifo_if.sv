/*
[TB_INFO_START]
Name: uart_async_fifo_if
Target: uart_rx_async_fifo_bridge
Role: Interface for UART RX + async FIFO verification
Scenario:
  - Provides write-domain serial RX and read-domain pop signals
CheckPoint:
  - Keep dual-clock UART/FIFO signals reusable across TB components
[TB_INFO_END]
*/

`timescale 1ns / 1ps

interface uart_async_fifo_if;
  logic       iWrClk;
  logic       iRdClk;
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
    input  iWrClk, iRdClk, iRst, iTick16x, iRx, iPop,
    output oPopData, oPopValid, oFull, oEmpty, oRxData, oRxValid
  );
endinterface
