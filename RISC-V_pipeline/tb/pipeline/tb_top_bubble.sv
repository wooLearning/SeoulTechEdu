`timescale 1ns / 1ps

/*
[TB_INFO_START]
Name: tb_top_bubble
Target: Top
Role: Directed testbench for validating the bubble-sort pipeline ROM
Scenario:
  - Initialize five unsorted values in data memory
  - Run the bubble-sort program to completion
  - Confirm final sorted memory contents and key architectural state
CheckPoint:
  - Fail fast if the instruction image is not loaded or the program never commits
  - Verify sorted memory words and completion registers explicitly
  - Produce a VCD so branch-heavy pipeline flow can be inspected directly
[TB_INFO_END]
*/
module tb_top_bubble;
  import instr_mem_paths_pkg::*;

  localparam int LP_CLK_PERIOD = 10;
  localparam int LP_RAM_DEPTH  = 256;
  localparam int LP_MAX_CYCLES = 260;
  localparam logic [31:0] LP_NOP = 32'h00000013;
  localparam string LP_INSTR_MEM_FILE = LP_INSTR_MEM_BUBBLE;

  logic iClk;
  logic iRstn;
  logic [31:0] wDbgPc;
  logic        wDbgIfActive;
  logic        wDbgIdActive;
  logic        wDbgExActive;
  logic        wDbgWbActive;
  logic        wDbgWbCommit;
  logic        wDbgLoadUseStall;
  logic [1:0]  wDbgForwardA;
  logic [1:0]  wDbgForwardB;
  logic        wDbgExPcRedirectEn;
  logic        wSawWbCommit;
  integer rErrCnt;
  integer rCycle;
  integer idxMemInit;

  Top #(
    .P_USE_BUBBLE_ROM(1'b1),
    .P_INSTR_MEM_FILE(LP_INSTR_MEM_FILE)
  ) uTop (
    .iClk              (iClk),
    .iRstn             (iRstn),
    .oDbgPc            (wDbgPc),
    .oDbgIfActive      (wDbgIfActive),
    .oDbgIdActive      (wDbgIdActive),
    .oDbgExActive      (wDbgExActive),
    .oDbgWbActive      (wDbgWbActive),
    .oDbgWbCommit      (wDbgWbCommit),
    .oDbgLoadUseStall  (wDbgLoadUseStall),
    .oDbgForwardA      (wDbgForwardA),
    .oDbgForwardB      (wDbgForwardB),
    .oDbgExPcRedirectEn(wDbgExPcRedirectEn)
  );

  always #(LP_CLK_PERIOD / 2) iClk = ~iClk;

  task automatic check_mem(
    input int          idx,
    input logic [31:0] exp,
    input string       name
  );
    begin
      if (uTop.uMemStage.uDataRam.rMemRam[idx] !== exp) begin
        $display("[FAIL] %s : got=%0d (0x%08h) exp=%0d (0x%08h)",
          name,
          $signed(uTop.uMemStage.uDataRam.rMemRam[idx]),
          uTop.uMemStage.uDataRam.rMemRam[idx],
          $signed(exp),
          exp
        );
        rErrCnt = rErrCnt + 1;
      end else begin
        $display("[PASS] %s : got=%0d (0x%08h) exp=%0d (0x%08h)",
          name,
          $signed(uTop.uMemStage.uDataRam.rMemRam[idx]),
          uTop.uMemStage.uDataRam.rMemRam[idx],
          $signed(exp),
          exp
        );
      end
    end
  endtask

  task automatic check_seen(
    input logic  iSeen,
    input string iPassName,
    input string iFailName
  );
    begin
      if (!iSeen) begin
        $display("[FAIL] %s", iFailName);
        rErrCnt = rErrCnt + 1;
      end else begin
        $display("[PASS] %s", iPassName);
      end
    end
  endtask

  task automatic log_pipeline_event(input string iTag);
    begin
      $display("[TRACE][C%0d][%s] PC=%0d (0x%08h) IF/ID/EX/WB=%0b%0b%0b%0b stall=%0b redirect=%0b fwdA=%0d fwdB=%0d ifid=0x%08h",
        rCycle,
        iTag,
        wDbgPc,
        wDbgPc,
        wDbgIfActive,
        wDbgIdActive,
        wDbgExActive,
        wDbgWbActive,
        wDbgLoadUseStall,
        wDbgExPcRedirectEn,
        wDbgForwardA,
        wDbgForwardB,
        uTop.rIfIdInstr
      );
    end
  endtask

  task automatic log_commit_event;
    begin
      $display("[TRACE][C%0d][COMMIT] PC=%0d (0x%08h) rd=x%0d data=%0d (0x%08h)",
        rCycle,
        wDbgPc,
        wDbgPc,
        uTop.wMemWb2Regfile_RdAddr,
        $signed(uTop.wMemWb2Regfile_WrData),
        uTop.wMemWb2Regfile_WrData
      );
    end
  endtask

  initial begin : tb_main
    iClk    = 1'b0;
    iRstn   = 1'b0;
    wSawWbCommit = 1'b0;
    rErrCnt = 0;
    rCycle  = 0;

    for (idxMemInit = 0; idxMemInit < LP_RAM_DEPTH; idxMemInit = idxMemInit + 1) begin
      uTop.uMemStage.uDataRam.rMemRam[idxMemInit] = 32'd0;
    end

    uTop.uMemStage.uDataRam.rMemRam[16] = 32'd9;
    uTop.uMemStage.uDataRam.rMemRam[17] = 32'd3;
    uTop.uMemStage.uDataRam.rMemRam[18] = 32'd7;
    uTop.uMemStage.uDataRam.rMemRam[19] = 32'd1;
    uTop.uMemStage.uDataRam.rMemRam[20] = 32'd5;

    $dumpfile("tb_top_bubble.vcd");
    $dumpvars(0, tb_top_bubble);

    repeat (2) @(posedge iClk);
    iRstn = 1'b1;

    repeat (3) @(posedge iClk);
    #1;
    if ((uTop.rIfIdInstr === LP_NOP) && (wDbgPc >= 32'd8)) begin
      $fatal(1,
        "tb_top_bubble ROM sanity failed: IF/ID instr stayed nop at PC=%0d",
        wDbgPc
      );
    end

    begin : wait_for_completion
      repeat (LP_MAX_CYCLES) begin
        @(posedge iClk);
        #1;
        rCycle = rCycle + 1;

        if (wDbgWbCommit) begin
          wSawWbCommit = 1'b1;
          log_commit_event();
        end

        if (wDbgLoadUseStall) begin
          log_pipeline_event("STALL");
        end

        if (wDbgExPcRedirectEn) begin
          log_pipeline_event("REDIRECT");
        end

        if ((rCycle % 16) == 0) begin
          log_pipeline_event("PROGRESS");
        end

        if (uTop.uDecodeStage.uRegfile.rMemReg[31] == 32'd1) begin
          disable wait_for_completion;
        end
      end

      $display("[FAIL] Timeout waiting for bubble-sort completion");
      rErrCnt = rErrCnt + 1;
    end

    check_seen(wSawWbCommit, "write-back commit was observed", "write-back commit was never observed");
    check_mem(16, 32'd1, "sorted word[16]");
    check_mem(17, 32'd3, "sorted word[17]");
    check_mem(18, 32'd5, "sorted word[18]");
    check_mem(19, 32'd7, "sorted word[19]");
    check_mem(20, 32'd9, "sorted word[20]");

    if (uTop.uDecodeStage.uRegfile.rMemReg[31] !== 32'd1) begin
      $display("[FAIL] completion flag x31 : got=%0d (0x%08h) exp=%0d (0x%08h)",
        uTop.uDecodeStage.uRegfile.rMemReg[31],
        uTop.uDecodeStage.uRegfile.rMemReg[31],
        32'd1,
        32'd1
      );
      rErrCnt = rErrCnt + 1;
    end else begin
      $display("[PASS] completion flag x31 : got=%0d (0x%08h) exp=%0d (0x%08h)",
        uTop.uDecodeStage.uRegfile.rMemReg[31],
        uTop.uDecodeStage.uRegfile.rMemReg[31],
        32'd1,
        32'd1
      );
    end

    if (uTop.uDecodeStage.uRegfile.rMemReg[2] !== 32'd0) begin
      $display("[FAIL] outer loop counter x2 final : got=%0d (0x%08h) exp=%0d (0x%08h)",
        uTop.uDecodeStage.uRegfile.rMemReg[2],
        uTop.uDecodeStage.uRegfile.rMemReg[2],
        32'd0,
        32'd0
      );
      rErrCnt = rErrCnt + 1;
    end else begin
      $display("[PASS] outer loop counter x2 final : got=%0d (0x%08h) exp=%0d (0x%08h)",
        uTop.uDecodeStage.uRegfile.rMemReg[2],
        uTop.uDecodeStage.uRegfile.rMemReg[2],
        32'd0,
        32'd0
      );
    end

    if (rErrCnt != 0) begin
      $display("tb_top_bubble FAILED with %0d error(s)", rErrCnt);
      $fatal(1, "tb_top_bubble failed");
      disable tb_main;
    end

    $display("tb_top_bubble PASSED");
    $finish;
  end

endmodule
