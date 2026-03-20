/*
[TB_INFO_START]
Name: sync_fifo_if
Target: sync_fifo
Role: Interface for connecting tb_sync_fifo and sync_fifo DUT
Scenario:
  - Provides grouped FIFO request/response signals
CheckPoint:
  - Keep DUT connection signals reusable and readable
[TB_INFO_END]
*/

`timescale 1ns / 1ps
interface sync_fifo_if;
  logic       iClk;
  logic       iRstn;
  logic       iWrEn;
  logic       iRdEn;
  logic [7:0] iWData;
  logic [7:0] oRData;
  logic       oFull;
  logic       oEmpty;
  int unsigned tbScenarioId;

  // Drive requests on the inactive phase so the DUT sees stable inputs at posedge.
  clocking drv_cb @(negedge iClk);
    default input #1step output #0;
    output tbScenarioId, iWrEn, iRdEn, iWData;
  endclocking

  // Sample the completed cycle after the active-edge update but before the next drive phase.
  clocking mon_cb @(negedge iClk);
    default input #1step output #0;
    input tbScenarioId, iWrEn, iRdEn, iWData, oRData, oFull, oEmpty;
  endclocking

  property p_flags_not_both_high;
    @(posedge iClk) disable iff (!iRstn) !(oFull && oEmpty);
  endproperty

  property p_reset_drives_empty;
    @(posedge iClk) !iRstn |=> (oEmpty && !oFull);
  endproperty

  a_flags_not_both_high: assert property (p_flags_not_both_high)
    else $error("[ASSERT][sync_fifo_if] full and empty cannot be high together");

  a_reset_drives_empty: assert property (p_reset_drives_empty)
    else $error("[ASSERT][sync_fifo_if] reset should drive empty/high and full/low");

  modport dut (
    input  iClk, iRstn, iWrEn, iRdEn, iWData,
    output oRData, oFull, oEmpty
  );
endinterface
