/*
[TB_INFO_START]
Name: fifo_if
Target: fifo
Role: Interface for connecting tb_fifo and fifo DUT
Scenario:
  - Provides async FIFO write/read clock-domain signals
CheckPoint:
  - Keep DUT connection signals grouped and reusable
[TB_INFO_END]
*/

`timescale 1ns / 1ps
interface fifo_if;
  logic       iWrClk;
  logic       iRdClk;
  logic       iRstn;
  logic       iWrEn;
  logic       iRdEn;
  logic [7:0] iWData;
  logic [7:0] oRData;
  logic       oFull;
  logic       oEmpty;
  int unsigned tbScenarioId;

  // Drive write-domain requests on the inactive phase.
  clocking wr_drv_cb @(negedge iWrClk);
    default input #1step output #0;
    output iWrEn, iWData;
  endclocking

  // Capture write-domain request/flag state one timestep before the active edge.
  clocking wr_pre_cb @(posedge iWrClk);
    default input #1step output #0;
    input tbScenarioId, iWrEn, iRdEn, iWData, oFull, oEmpty;
  endclocking

  // Sample write-domain results after the posedge update but before the next driver step.
  clocking wr_mon_cb @(negedge iWrClk);
    default input #1step output #0;
    input tbScenarioId, iWrEn, iRdEn, iWData, oRData, oFull, oEmpty;
  endclocking

  // Drive read-domain requests on the inactive phase.
  clocking rd_drv_cb @(negedge iRdClk);
    default input #1step output #0;
    output iRdEn;
  endclocking

  // Capture read-domain request/flag state one timestep before the active edge.
  clocking rd_pre_cb @(posedge iRdClk);
    default input #1step output #0;
    input tbScenarioId, iWrEn, iRdEn, iWData, oFull, oEmpty;
  endclocking

  // Sample read-domain results after the posedge update but before the next driver step.
  clocking rd_mon_cb @(negedge iRdClk);
    default input #1step output #0;
    input tbScenarioId, iWrEn, iRdEn, iWData, oRData, oFull, oEmpty;
  endclocking

  // Lightweight protocol assertions keep flag behavior readable in logs.
  property p_flags_not_both_high_wr;
    @(posedge iWrClk) disable iff (!iRstn) !(oFull && oEmpty);
  endproperty

  property p_flags_not_both_high_rd;
    @(posedge iRdClk) disable iff (!iRstn) !(oFull && oEmpty);
  endproperty

  property p_reset_drives_empty_wr;
    @(posedge iWrClk) !iRstn |=> (oEmpty && !oFull);
  endproperty

  property p_reset_drives_empty_rd;
    @(posedge iRdClk) !iRstn |=> (oEmpty && !oFull);
  endproperty

  a_flags_not_both_high_wr: assert property (p_flags_not_both_high_wr)
    else $error("[ASSERT][fifo_if] write-domain flags cannot be high together");

  a_flags_not_both_high_rd: assert property (p_flags_not_both_high_rd)
    else $error("[ASSERT][fifo_if] read-domain flags cannot be high together");

  a_reset_drives_empty_wr: assert property (p_reset_drives_empty_wr)
    else $error("[ASSERT][fifo_if] reset should drive empty/high and full/low on write clock");

  a_reset_drives_empty_rd: assert property (p_reset_drives_empty_rd)
    else $error("[ASSERT][fifo_if] reset should drive empty/high and full/low on read clock");

  modport dut (
    input  iWrClk, iRdClk, iRstn, iWrEn, iRdEn, iWData,
    output oRData, oFull, oEmpty
  );
endinterface
