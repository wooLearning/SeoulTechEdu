`timescale 1ns / 1ps

/*
[TB_INFO_START]
Name: tb_top_spike
Target: Top
Role: Log-driven Spike trace scoreboard testbench for the RV32I pipeline top
Scenario:
  - Run the Spike-aligned instruction image from 0x8000_0000
  - Compare every retired instruction against the Spike architectural trace
  - Report detailed PASS/FAIL logs and final memory checks
CheckPoint:
  - Verify retire PC and instruction against the golden trace
  - Compare x0..x31 after every retired instruction
  - Check final data memory words used by the program
[TB_INFO_END]
*/
module tb_top_spike;
  import instr_mem_paths_pkg::*;
  import spike_trace_pkg::*;

  localparam int LP_CLK_PERIOD = 10;
  localparam int LP_RAM_DEPTH  = 256;
  localparam int LP_MAX_CYCLES = 1200;
  localparam int LP_WORD0_INDEX = LP_SPIKE_DATA_WORD0_ADDR[9:2];
  localparam int LP_WORD1_INDEX = LP_SPIKE_DATA_WORD1_ADDR[9:2];

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
  logic        wTraceRetireValid;
  logic        wTraceRetireIllegal;
  logic [31:0] wTraceRetirePc;
  logic [31:0] wTraceRetireInstr;
  logic        wTraceRetireRegWrite;
  logic [4:0]  wTraceRetireRdAddr;
  logic [31:0] wTraceRetireRdData;
  logic        wTraceRetireMemWrite;
  logic [31:0] wTraceRetireMemAddr;
  logic [31:0] wTraceRetireMemData;

  int rCycle;
  int rRetireIdx;
  int rErrCnt;
  int rIdx;

  Top #(
    .P_RESET_PC       (LP_SPIKE_RESET_PC),
    .P_INSTR_BASE_ADDR(LP_SPIKE_INSTR_BASE_ADDR),
    .P_INSTR_MEM_FILE (LP_INSTR_MEM_SPIKE_TOP)
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
    .oDbgExPcRedirectEn(wDbgExPcRedirectEn),
    .oTraceRetireValid (wTraceRetireValid),
    .oTraceRetireIllegal(wTraceRetireIllegal),
    .oTraceRetirePc    (wTraceRetirePc),
    .oTraceRetireInstr (wTraceRetireInstr),
    .oTraceRetireRegWrite(wTraceRetireRegWrite),
    .oTraceRetireRdAddr(wTraceRetireRdAddr),
    .oTraceRetireRdData(wTraceRetireRdData),
    .oTraceRetireMemWrite(wTraceRetireMemWrite),
    .oTraceRetireMemAddr(wTraceRetireMemAddr),
    .oTraceRetireMemData(wTraceRetireMemData)
  );

  always #(LP_CLK_PERIOD / 2) iClk = ~iClk;

  task automatic log_retire(input int iIdx);
    begin
      $display(
        "[TRACE][RETIRE %0d/%0d][C%0d] step=%0d class=%s pc=0x%08h inst=0x%08h regwr=%0b rd=x%0d data=0x%08h memwr=%0b mem_addr=0x%08h mem_data=0x%08h illegal=%0b",
        iIdx + 1,
        LP_SPIKE_TRACE_DEPTH,
        rCycle,
        LP_SPIKE_TRACE_STEP[iIdx],
        trace_opcode_name(wTraceRetireInstr),
        wTraceRetirePc,
        wTraceRetireInstr,
        wTraceRetireRegWrite,
        wTraceRetireRdAddr,
        wTraceRetireRdData,
        wTraceRetireMemWrite,
        wTraceRetireMemAddr,
        wTraceRetireMemData,
        wTraceRetireIllegal
      );
    end
  endtask

  task automatic compare_retire_row(input int iIdx);
    int rowErrCnt;
    int regIdx;
    logic [31:0] wActReg;
    begin
      rowErrCnt = 0;
      log_retire(iIdx);

      if (wTraceRetirePc !== LP_SPIKE_TRACE_PC[iIdx]) begin
        $display("[FAIL][ROW %0d] PC mismatch got=0x%08h exp=0x%08h",
          iIdx, wTraceRetirePc, LP_SPIKE_TRACE_PC[iIdx]);
        rowErrCnt = rowErrCnt + 1;
      end

      if (wTraceRetireInstr !== LP_SPIKE_TRACE_INST[iIdx]) begin
        $display("[FAIL][ROW %0d] INST mismatch got=0x%08h exp=0x%08h",
          iIdx, wTraceRetireInstr, LP_SPIKE_TRACE_INST[iIdx]);
        rowErrCnt = rowErrCnt + 1;
      end

      for (regIdx = 0; regIdx < 32; regIdx = regIdx + 1) begin
        wActReg = uTop.uDecodeStage.uRegfile.rMemReg[regIdx];
        if (regIdx == 0) begin
          wActReg = 32'd0;
        end

        if (wActReg !== LP_SPIKE_TRACE_GPR[iIdx][regIdx]) begin
          $display("[FAIL][ROW %0d] x%0d mismatch got=0x%08h exp=0x%08h",
            iIdx, regIdx, wActReg, LP_SPIKE_TRACE_GPR[iIdx][regIdx]);
          rowErrCnt = rowErrCnt + 1;
        end
      end

      if (rowErrCnt == 0) begin
        $display("[PASS][ROW %0d] retire matched Spike trace", iIdx);
      end else begin
        rErrCnt = rErrCnt + rowErrCnt;
      end
    end
  endtask

  task automatic check_final_memory;
    begin
      if (!LP_SPIKE_CHECK_FINAL_MEM) begin
        $display("[INFO] Final memory check disabled for this trace package");
        return;
      end

      if (uTop.uMemStage.uDataRam.rMemRam[LP_WORD0_INDEX] !== LP_SPIKE_DATA_WORD0_EXP) begin
        $display("[FAIL] Data memory word[%0d] mismatch got=0x%08h exp=0x%08h",
          LP_WORD0_INDEX,
          uTop.uMemStage.uDataRam.rMemRam[LP_WORD0_INDEX],
          LP_SPIKE_DATA_WORD0_EXP
        );
        rErrCnt = rErrCnt + 1;
      end else begin
        $display("[PASS] Data memory word[%0d] matched 0x%08h",
          LP_WORD0_INDEX,
          LP_SPIKE_DATA_WORD0_EXP
        );
      end

      if (uTop.uMemStage.uDataRam.rMemRam[LP_WORD1_INDEX] !== LP_SPIKE_DATA_WORD1_EXP) begin
        $display("[FAIL] Data memory word[%0d] mismatch got=0x%08h exp=0x%08h",
          LP_WORD1_INDEX,
          uTop.uMemStage.uDataRam.rMemRam[LP_WORD1_INDEX],
          LP_SPIKE_DATA_WORD1_EXP
        );
        rErrCnt = rErrCnt + 1;
      end else begin
        $display("[PASS] Data memory word[%0d] matched 0x%08h",
          LP_WORD1_INDEX,
          LP_SPIKE_DATA_WORD1_EXP
        );
      end
    end
  endtask

  initial begin : tb_main
    iClk = 1'b0;
    iRstn = 1'b0;
    rCycle = 0;
    rRetireIdx = 0;
    rErrCnt = 0;

    for (rIdx = 0; rIdx < LP_RAM_DEPTH; rIdx = rIdx + 1) begin
      uTop.uMemStage.uDataRam.rMemRam[rIdx] = 32'd0;
    end
    for (rIdx = 0; rIdx < LP_SPIKE_PRELOAD_MEM_COUNT; rIdx = rIdx + 1) begin
      uTop.uMemStage.uDataRam.rMemRam[LP_SPIKE_PRELOAD_MEM_ADDR[rIdx][9:2]] =
        LP_SPIKE_PRELOAD_MEM_DATA[rIdx];
    end

    $dumpfile("tb_top_spike.vcd");
    $dumpvars(0, tb_top_spike);

    repeat (4) @(posedge iClk);
    iRstn = 1'b1;
    #1;

    // Match the architectural state that Spike carries into the main program
    // after its short boot handoff sequence.
    for (rIdx = 1; rIdx < 32; rIdx = rIdx + 1) begin
      uTop.uDecodeStage.uRegfile.rMemReg[rIdx] = LP_SPIKE_PRELOAD_GPR[rIdx];
    end

    begin : wait_for_completion
      repeat (LP_MAX_CYCLES) begin
        @(posedge iClk);
        #1;
        rCycle = rCycle + 1;

        if (wTraceRetireValid) begin
          if (rRetireIdx >= LP_SPIKE_TRACE_DEPTH) begin
            $display("[FAIL] Observed extra retire beyond Spike trace depth at cycle %0d", rCycle);
            rErrCnt = rErrCnt + 1;
            disable wait_for_completion;
          end

          compare_retire_row(rRetireIdx);
          rRetireIdx = rRetireIdx + 1;

          if (rRetireIdx == LP_SPIKE_TRACE_DEPTH) begin
            disable wait_for_completion;
          end
        end
      end

      if (rRetireIdx != LP_SPIKE_TRACE_DEPTH) begin
        $display("[FAIL] Timeout waiting for Spike trace completion");
        rErrCnt = rErrCnt + 1;
      end
    end

    if (rRetireIdx == LP_SPIKE_TRACE_DEPTH) begin
      check_final_memory();
    end

    if (rRetireIdx != LP_SPIKE_TRACE_DEPTH) begin
      $display("[FAIL] Retire count mismatch got=%0d exp=%0d",
        rRetireIdx, LP_SPIKE_TRACE_DEPTH);
    end else begin
      $display("[PASS] Retire count matched Spike trace depth (%0d)", LP_SPIKE_TRACE_DEPTH);
    end

    if (rErrCnt != 0 || rRetireIdx != LP_SPIKE_TRACE_DEPTH) begin
      $display("tb_top_spike FAILED with %0d error(s)", rErrCnt);
      $fatal(1, "tb_top_spike failed");
    end else begin
      $display("tb_top_spike PASSED");
      $finish;
    end
  end

endmodule
