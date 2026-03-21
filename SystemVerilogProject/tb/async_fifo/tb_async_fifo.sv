/*
[TB_INFO_START]
Name: tb_async_fifo
Target: async_fifo
Role: Testbench for validating async_fifo
Scenario:
  - Apply async reset and confirm default empty state
  - Phase-aware async traffic: fill burst, mixed stress, drain burst, full pressure, empty pressure
  - Scoreboard compares accepted reads against reference queue model
CheckPoint:
  - Verify DUT reset and default outputs first
  - Compare key outputs against expected FIFO order behavior
  - Print summary and coverage for auto-judgement
[TB_INFO_END]
*/

`timescale 1ns / 1ps

module tb_async_fifo;
  import async_fifo_tb_pkg::*;

  localparam int AW = 4;
  localparam int DW = 8;
  localparam int RUN_COUNT = 420;

  async_fifo_if async_fifo_if_inst();
  async_fifo_environment env;

  async_fifo #(
    .AW(AW),
    .DW(DW)
  ) u_async_fifo (
    .iWrClk (async_fifo_if_inst.iWrClk),
    .iRdClk (async_fifo_if_inst.iRdClk),
    .iRst   (async_fifo_if_inst.iRst),
    .iWrEn  (async_fifo_if_inst.iWrEn),
    .iRdEn  (async_fifo_if_inst.iRdEn),
    .iWData (async_fifo_if_inst.iWData),
    .oRData (async_fifo_if_inst.oRData),
    .oFull  (async_fifo_if_inst.oFull),
    .oEmpty (async_fifo_if_inst.oEmpty)
  );

  always #4 async_fifo_if_inst.iWrClk = ~async_fifo_if_inst.iWrClk;
  always #7 async_fifo_if_inst.iRdClk = ~async_fifo_if_inst.iRdClk;

  initial begin
    $display("[TB] Starting async_fifo verification (UVM-inspired custom environment)");

    async_fifo_if_inst.iWrClk = 1'b0;
    async_fifo_if_inst.iRdClk = 1'b0;
    async_fifo_if_inst.iRst   = 1'b0;
    async_fifo_if_inst.iWrEn  = 1'b0;
    async_fifo_if_inst.iRdEn  = 1'b0;
    async_fifo_if_inst.iWData = '0;

    env = new(async_fifo_if_inst);
    env.run(RUN_COUNT);

    #20;
    $display("[TB] tb_async_fifo finished successfully");
    $finish;
  end
endmodule
