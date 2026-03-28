`timescale 1ns / 1ps

/*
[TB_INFO_START]
Name: tb_perf_pipe_hazard
Target: Top
Role: Testbench for validating and benchmarking the pipeline hazard ROM
Scenario:
  - Run the mixed data/control hazard ROM to completion
  - Count total cycles and retired instructions
  - Print CPI for comparison with the other ROM variants
CheckPoint:
  - Completion when x31 reaches 1
  - Retire count is taken from valid MEM/WB packets
  - Add explicit expected-value checks for auto-judgement
[TB_INFO_END]
*/
module tb_perf_pipe_hazard;
  import instr_mem_paths_pkg::*;

  localparam int LP_CLK_PERIOD = 10;
  localparam int LP_RAM_DEPTH  = 256;
  localparam int LP_MAX_CYCLES = 320;
  localparam string LP_INSTR_MEM_FILE = LP_INSTR_MEM_HAZARD;

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
    .P_USE_HAZARD_ROM(1'b1),
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
    iClk       = 1'b0;
    iRstn      = 1'b0;
    rCycleCnt  = 0;
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

        if (uTop.uDecodeStage.uRegfile.rMemReg[31] == 32'd1) begin
          disable wait_for_completion;
        end
      end

      $fatal(1, "tb_perf_pipe_hazard timeout");
    end

    if (uTop.uDecodeStage.uRegfile.rMemReg[13] != 32'd13) begin
      $fatal(1, "tb_perf_pipe_hazard x13 mismatch: %h", uTop.uDecodeStage.uRegfile.rMemReg[13]);
    end

    if (uTop.uDecodeStage.uRegfile.rMemReg[16] != 32'd16) begin
      $fatal(1, "tb_perf_pipe_hazard x16 mismatch: %h", uTop.uDecodeStage.uRegfile.rMemReg[16]);
    end

    if (uTop.uDecodeStage.uRegfile.rMemReg[25] != 32'd25) begin
      $fatal(1, "tb_perf_pipe_hazard x25 mismatch: %h", uTop.uDecodeStage.uRegfile.rMemReg[25]);
    end

    $display("PERF design=pipeline program=hazard cycles=%0d retired=%0d cpi=%0f",
      rCycleCnt, rRetireCnt, (rRetireCnt != 0) ? (1.0 * rCycleCnt / rRetireCnt) : 0.0);
    $finish;
  end

endmodule
