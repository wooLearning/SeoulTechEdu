/*
[TB_INFO_START]
Name: tb_sync_fifo
Target: sync_fifo
Role: Testbench for validating sync_fifo
Scenario:
  - Apply/reset and check default empty flag
  - Phase-aware stimulus: fill burst, simultaneous stress, flag pressure, drain burst, balanced stream
  - Randomized write/read requests including simultaneous operations
  - Scoreboard compares read data order and full/empty flags
CheckPoint:
  - Verify DUT reset and default outputs first
  - Compare outputs against reference queue model
  - Print summary and coverage for auto-judgement
[TB_INFO_END]
*/

`timescale 1ns / 1ps

module tb_sync_fifo;
  import sync_fifo_tb_pkg::*;

  localparam int AW = 4;
  localparam int DW = 8;
  localparam int DEPTH = (1 << AW);
  localparam int RUN_COUNT = 320;

  sync_fifo_if sync_fifo_if_inst();
  sync_fifo_environment env;

  sync_fifo #(
    .AW(AW),
    .DW(DW)
  ) u_sync_fifo (
    .iClk  (sync_fifo_if_inst.iClk),
    .iRstn (sync_fifo_if_inst.iRstn),
    .iWrEn (sync_fifo_if_inst.iWrEn),
    .iRdEn (sync_fifo_if_inst.iRdEn),
    .iWData(sync_fifo_if_inst.iWData),
    .oRData(sync_fifo_if_inst.oRData),
    .oFull (sync_fifo_if_inst.oFull),
    .oEmpty(sync_fifo_if_inst.oEmpty)
  );

  always #5 sync_fifo_if_inst.iClk = ~sync_fifo_if_inst.iClk;

  initial begin
    $display("[TB] Starting sync FIFO verification (UVM-inspired custom environment)");

    sync_fifo_if_inst.iClk   = 1'b0;
    sync_fifo_if_inst.iRstn  = 1'b1;
    sync_fifo_if_inst.iWrEn  = 1'b0;
    sync_fifo_if_inst.iRdEn  = 1'b0;
    sync_fifo_if_inst.iWData = '0;

    env = new(sync_fifo_if_inst, DEPTH);
    env.run(RUN_COUNT);

    #20;
    $display("[TB] tb_sync_fifo finished successfully");
    $finish;
  end
endmodule
