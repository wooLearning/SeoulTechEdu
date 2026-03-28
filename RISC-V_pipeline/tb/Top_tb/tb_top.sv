`timescale 1ns / 1ps

/*
[TB_INFO_START]
Name: TbTop
Target: Top
Role: Class-based passive Top_tb environment for Spike trace verification
Scenario:
  - Run the Spike-aligned instruction image from 0x8000_0000
  - Observe retire events through a passive monitor and class-based scoreboard
  - Print scoreboard and coverage summaries with explicit PASS/FAIL behavior
CheckPoint:
  - Compare every retired instruction against the Spike golden trace
  - Validate final data memory values
  - Report functional coverage at the end of the run
[TB_INFO_END]
*/
module TbTop;
    import Top_tb_pkg::*;
    import instr_mem_paths_pkg::*;
    import spike_trace_pkg::*;

    localparam int unsigned LP_CLK_PERIOD  = 10;
    localparam int unsigned LP_SIM_TIMEOUT = 200_000;
    localparam int unsigned LP_RAM_DEPTH   = 256;
    localparam int unsigned LP_WORD0_INDEX = LP_SPIKE_DATA_WORD0_ADDR[9:2];
    localparam int unsigned LP_WORD1_INDEX = LP_SPIKE_DATA_WORD1_ADDR[9:2];

    logic iClk;
    logic iRstn;
    integer idxMemInit;

    Top_if uIf (
        .iClk(iClk),
        .iRstn(iRstn)
    );

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

    Top #(
        .P_RESET_PC       (LP_SPIKE_RESET_PC),
        .P_INSTR_BASE_ADDR(LP_SPIKE_INSTR_BASE_ADDR),
        .P_INSTR_MEM_FILE (LP_INSTR_MEM_SPIKE_TOP)
    ) uDut (
        .iClk               (iClk),
        .iRstn              (iRstn),
        .oDbgPc             (wDbgPc),
        .oDbgIfActive       (wDbgIfActive),
        .oDbgIdActive       (wDbgIdActive),
        .oDbgExActive       (wDbgExActive),
        .oDbgWbActive       (wDbgWbActive),
        .oDbgWbCommit       (wDbgWbCommit),
        .oDbgLoadUseStall   (wDbgLoadUseStall),
        .oDbgForwardA       (wDbgForwardA),
        .oDbgForwardB       (wDbgForwardB),
        .oDbgExPcRedirectEn (wDbgExPcRedirectEn),
        .oTraceRetireValid  (uIf.tb_trace_retire_valid),
        .oTraceRetireIllegal(uIf.tb_trace_retire_illegal),
        .oTraceRetirePc     (uIf.tb_trace_retire_pc),
        .oTraceRetireInstr  (uIf.tb_trace_retire_inst),
        .oTraceRetireRegWrite(uIf.tb_trace_retire_reg_write),
        .oTraceRetireRdAddr (uIf.tb_trace_retire_rd_addr),
        .oTraceRetireRdData (uIf.tb_trace_retire_rd_data),
        .oTraceRetireMemWrite(uIf.tb_trace_retire_mem_write),
        .oTraceRetireMemAddr(uIf.tb_trace_retire_mem_addr),
        .oTraceRetireMemData(uIf.tb_trace_retire_mem_data)
    );

    assign uIf.tb_dbg_stall = wDbgLoadUseStall;
    assign uIf.tb_dbg_redirect = wDbgExPcRedirectEn;
    assign uIf.tb_dbg_forward_a = wDbgForwardA;
    assign uIf.tb_dbg_forward_b = wDbgForwardB;
    assign uIf.tb_mem_word0 = uDut.uMemStage.uDataRam.rMemRam[LP_WORD0_INDEX];
    assign uIf.tb_mem_word1 = uDut.uMemStage.uDataRam.rMemRam[LP_WORD1_INDEX];

    genvar genIdx;
    generate
        for (genIdx = 0; genIdx < 32; genIdx = genIdx + 1) begin : g_gpr_tap
            if (genIdx == 0) begin : g_x0
                assign uIf.tb_gpr[genIdx] = 32'd0;
            end else begin : g_gpr
                assign uIf.tb_gpr[genIdx] = uDut.uDecodeStage.uRegfile.rMemReg[genIdx];
            end
        end
    endgenerate

    initial begin
        iClk = 1'b0;
        forever #(LP_CLK_PERIOD / 2.0) iClk = ~iClk;
    end

    initial begin
        iRstn = 1'b0;
        for (idxMemInit = 0; idxMemInit < LP_RAM_DEPTH; idxMemInit = idxMemInit + 1) begin
            uDut.uMemStage.uDataRam.rMemRam[idxMemInit] = 32'd0;
        end
        for (idxMemInit = 0; idxMemInit < LP_SPIKE_PRELOAD_MEM_COUNT; idxMemInit = idxMemInit + 1) begin
            uDut.uMemStage.uDataRam.rMemRam[LP_SPIKE_PRELOAD_MEM_ADDR[idxMemInit][9:2]] =
                LP_SPIKE_PRELOAD_MEM_DATA[idxMemInit];
        end
        repeat (5) @(posedge iClk);
        iRstn = 1'b1;
        #1;
        for (idxMemInit = 1; idxMemInit < 32; idxMemInit = idxMemInit + 1) begin
            uDut.uDecodeStage.uRegfile.rMemReg[idxMemInit] = LP_SPIKE_PRELOAD_GPR[idxMemInit];
        end
    end

    initial begin
        TopTest01 tb_test;
        @(posedge iRstn);
        tb_test = new(uIf);
        tb_test.run();
        repeat (20) @(posedge iClk);
        $finish;
    end

    initial begin
        #(LP_SIM_TIMEOUT);
        $fatal(1, "[TB] Timeout reached: %0d ns", LP_SIM_TIMEOUT);
    end

    initial begin
        $dumpfile("Top_tb_wave.vcd");
        $dumpvars(0, TbTop);
    end
endmodule
