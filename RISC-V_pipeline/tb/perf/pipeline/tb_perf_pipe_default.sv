`timescale 1ns / 1ps

/*
[TB_INFO_START]
Name: tb_perf_pipe_default
Target: Top
Role: Performance benchmark testbench for the pipeline default ROM
Scenario:
  - Run the default regression program to completion
  - Count total cycles and retired instructions
  - Print CPI for performance comparison against the single-cycle core
CheckPoint:
  - Completion when x29 reaches 77
  - Retire count is taken from valid MEM/WB packets
[TB_INFO_END]
*/
module tb_perf_pipe_default;
  import instr_mem_paths_pkg::*;

  localparam int LP_CLK_PERIOD = 10;
  localparam int LP_RAM_DEPTH  = 256;
  localparam int LP_MAX_CYCLES = 400;
  localparam string LP_INSTR_MEM_FILE = LP_INSTR_MEM_DEFAULT;

  logic iClk;
  logic iRstn;
  logic [31:0] wDbgPc;
  logic        wDbgLoadUseStall;
  logic [1:0]  wDbgForwardA;
  logic [1:0]  wDbgForwardB;
  logic        wDbgExPcRedirectEn;
  integer idxMemInit;
  integer rCycleCnt;
  integer rRetireCnt;

  Top #(
    .P_INSTR_MEM_FILE(LP_INSTR_MEM_FILE)
  ) uTop (
    .iClk              (iClk),
    .iRstn             (iRstn),
    .oDbgPc            (wDbgPc),
    .oDbgLoadUseStall  (wDbgLoadUseStall),
    .oDbgForwardA      (wDbgForwardA),
    .oDbgForwardB      (wDbgForwardB),
    .oDbgExPcRedirectEn(wDbgExPcRedirectEn)
  );

  always #(LP_CLK_PERIOD / 2) iClk = ~iClk;

  initial begin : tb_main
    iClk      = 1'b0;
    iRstn     = 1'b0;
    rCycleCnt = 0;
    rRetireCnt = 0;

    for (idxMemInit = 0; idxMemInit < LP_RAM_DEPTH; idxMemInit = idxMemInit + 1) begin
      uTop.uMemStage.uDataRam.rMemRam[idxMemInit] = 32'd0;
    end

    repeat (2) @(posedge iClk);
    iRstn = 1'b1;

    begin : wait_for_completion
      repeat (LP_MAX_CYCLES) begin
        @(posedge iClk);
        #1;
        rCycleCnt = rCycleCnt + 1;

        if (uTop.rMemWbValid) begin
          rRetireCnt = rRetireCnt + 1;
        end

        if (uTop.uDecodeStage.uRegfile.rMemReg[29] == 32'd77) begin
          disable wait_for_completion;
        end
      end

      $fatal(1, "tb_perf_pipe_default timeout");
    end

    $display("PERF design=pipeline program=default cycles=%0d retired=%0d cpi=%0f",
      rCycleCnt, rRetireCnt, (rRetireCnt != 0) ? (1.0 * rCycleCnt / rRetireCnt) : 0.0);
    $finish;
  end

endmodule
