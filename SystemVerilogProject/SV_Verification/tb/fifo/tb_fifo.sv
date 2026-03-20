/*
[TB_INFO_START]
Name: tb_fifo
Target: fifo
Role: Testbench for validating fifo
Scenario:
  - Apply async reset and confirm default empty state
  - Phase-aware async traffic: fill burst, mixed stress, full pressure, drain burst, empty pressure
  - Randomized concurrent write/read requests across asynchronous clocks
  - Scoreboard compares accepted reads against reference queue model
CheckPoint:
  - Verify DUT reset and default outputs first
  - Compare key outputs against expected FIFO order behavior
  - Print summary and coverage for auto-judgement
[TB_INFO_END]
*/

`timescale 1ns / 1ps

module tb_fifo;
  import fifo_tb_pkg::*;

  localparam int AW = 4;
  localparam int DW = 8;
  localparam int RUN_COUNT = 420;

  fifo_if fifo_if_inst();
  fifo_environment env;

  fifo #(
    .AW(AW),
    .DW(DW)
  ) u_fifo (
    .iWrClk (fifo_if_inst.iWrClk),
    .iRdClk (fifo_if_inst.iRdClk),
    .iRstn  (fifo_if_inst.iRstn),
    .iWrEn  (fifo_if_inst.iWrEn),
    .iRdEn  (fifo_if_inst.iRdEn),
    .iWData (fifo_if_inst.iWData),
    .oRData (fifo_if_inst.oRData),
    .oFull  (fifo_if_inst.oFull),
    .oEmpty (fifo_if_inst.oEmpty)
  );

  // Asynchronous clocks with different periods.
  always #4 fifo_if_inst.iWrClk = ~fifo_if_inst.iWrClk;
  always #7 fifo_if_inst.iRdClk = ~fifo_if_inst.iRdClk;

  initial begin
    $display("[TB] Starting async FIFO verification (UVM-inspired custom environment)");

    fifo_if_inst.iWrClk = 1'b0;
    fifo_if_inst.iRdClk = 1'b0;
    fifo_if_inst.iRstn  = 1'b1;
    fifo_if_inst.iWrEn  = 1'b0;
    fifo_if_inst.iRdEn  = 1'b0;
    fifo_if_inst.iWData = '0;

    env = new(fifo_if_inst);
    env.run(RUN_COUNT);

    #20;
    $display("[TB] tb_fifo finished successfully");
    $finish;
  end
endmodule
