/*
[TB_INFO_START]
Name: uart_rx_if
Target: uart_rx
Role: Interface for UART RX verification
Scenario:
  - Provides UART serial input and RX byte output signals
CheckPoint:
  - Keep UART timing and observable outputs grouped for driver/monitor reuse
[TB_INFO_END]
*/

`timescale 1ns / 1ps

interface uart_rx_if;
  logic       iClk;
  logic       iRst;
  logic       iTick16x;
  logic       iRx;
  logic [7:0] oData;
  logic       oValid;
  int unsigned tbScenarioId;

  modport dut (
    input  iClk, iRst, iTick16x, iRx,
    output oData, oValid
  );
endinterface
