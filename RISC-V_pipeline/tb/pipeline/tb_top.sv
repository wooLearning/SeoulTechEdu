`timescale 1ns / 1ps

/*
[TB_INFO_START]
Name: tb_top
Target: Top
Role: Directed testbench for the default pipeline ROM
Scenario:
  - Run the default regression program to completion
  - Observe jal/jalr redirect behavior and final architectural state
  - Fail fast if the instruction image is not loaded or the program never retires
CheckPoint:
  - Verify redirect-related PCs and link register values
  - Compare final register and memory state against expected values
  - Print explicit PASS/FAIL messages for each check
[TB_INFO_END]
*/
module tb_top;
  import instr_mem_paths_pkg::*;

  localparam int LP_CLK_PERIOD = 10;
  localparam int LP_RAM_DEPTH  = 256;
  localparam int LP_MAX_CYCLES = 220;
  localparam logic [31:0] LP_NOP = 32'h00000013;
  localparam string LP_INSTR_MEM_FILE = LP_INSTR_MEM_DEFAULT;

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
  logic wSawJalRedirect;
  logic wSawJalrRedirect;
  logic wSawJalLink;
  logic wSawJalrLink;
  logic wSawPc332;
  logic wSawBadJalSkip;
  logic wSawWbCommit;
  integer rErrCnt;
  integer rCycle;
  integer idxMemInit;

  Top #(
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

  task automatic check_reg(
    input int          idx,
    input logic [31:0] exp,
    input string       name
  );
    begin
      if (uTop.uDecodeStage.uRegfile.rMemReg[idx] !== exp) begin
        $display("[FAIL] %s : got=%0d (0x%08h) exp=%0d (0x%08h)",
          name,
          $signed(uTop.uDecodeStage.uRegfile.rMemReg[idx]),
          uTop.uDecodeStage.uRegfile.rMemReg[idx],
          $signed(exp),
          exp
        );
        rErrCnt = rErrCnt + 1;
      end else begin
        $display("[PASS] %s : got=%0d (0x%08h) exp=%0d (0x%08h)",
          name,
          $signed(uTop.uDecodeStage.uRegfile.rMemReg[idx]),
          uTop.uDecodeStage.uRegfile.rMemReg[idx],
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
    iClk   = 1'b0;
    iRstn  = 1'b0;
    wSawJalRedirect  = 1'b0;
    wSawJalrRedirect = 1'b0;
    wSawJalLink      = 1'b0;
    wSawJalrLink     = 1'b0;
    wSawPc332        = 1'b0;
    wSawBadJalSkip   = 1'b0;
    wSawWbCommit     = 1'b0;
    rErrCnt          = 0;
    rCycle           = 0;

    for (idxMemInit = 0; idxMemInit < LP_RAM_DEPTH; idxMemInit = idxMemInit + 1) begin
      uTop.uMemStage.uDataRam.rMemRam[idxMemInit] = 32'd0;
    end

    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);

    repeat (2) @(posedge iClk);
    iRstn = 1'b1;

    repeat (3) @(posedge iClk);
    #1;
    if ((uTop.rIfIdInstr === LP_NOP) && (wDbgPc >= 32'd8)) begin
      $fatal(1,
        "tb_top default ROM sanity failed: IF/ID instr stayed nop at PC=%0d",
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
          if (uTop.rIdExJumpType != rv32i_pkg::JUMP_NONE) begin
            log_pipeline_event("JUMP-REDIRECT");
          end else if (uTop.rIdExBranchType != rv32i_pkg::BR_NONE) begin
            log_pipeline_event("BRANCH-REDIRECT");
          end else begin
            log_pipeline_event("REDIRECT");
          end
        end

        if (wDbgPc == 32'd312) begin
          wSawJalRedirect = 1'b1;
        end

        if (wDbgPc == 32'd320) begin
          wSawJalrRedirect = 1'b1;
        end

        if (wDbgPc == 32'd332) begin
          wSawPc332 = 1'b1;
        end

        if (uTop.uDecodeStage.uRegfile.rMemReg[3] == 32'd308) begin
          wSawJalLink = 1'b1;
        end

        if (uTop.uDecodeStage.uRegfile.rMemReg[23] == 32'd320) begin
          wSawJalrLink = 1'b1;
        end

        if (uTop.uDecodeStage.uRegfile.rMemReg[29] == 32'd111) begin
          wSawBadJalSkip = 1'b1;
        end

        if (uTop.uDecodeStage.uRegfile.rMemReg[29] == 32'd77) begin
          disable wait_for_completion;
        end
      end

      $display("[FAIL] Timeout waiting for program completion");
      rErrCnt = rErrCnt + 1;
    end

    check_seen(wSawWbCommit,     "write-back commit was observed", "write-back commit was never observed");
    check_seen(wSawJalRedirect,  "jal redirect was observed",      "jal redirect PC was never observed");
    check_seen(wSawJalrRedirect, "jalr redirect was observed",     "jalr redirect PC was never observed");
    check_seen(wSawJalLink,      "jal link was observed",          "jal link value x3=308 was never observed");
    check_seen(wSawJalrLink,     "jalr link was observed",         "jalr link value x23=320 was never observed");
    check_seen(wSawPc332,        "PC=332 was observed",            "PC=332 was never observed");

    if (wSawBadJalSkip) begin
      $display("[FAIL] jal skipped instruction wrote x29=111");
      rErrCnt = rErrCnt + 1;
    end else begin
      $display("[PASS] jal skipped sequential addi");
    end

    check_reg(0,  32'd0,          "x0 hardwired zero");
    check_reg(4,  32'd18,         "R add");
    check_reg(5,  32'd12,         "R sub");
    check_reg(6,  32'd120,        "R sll");
    check_reg(7,  32'd1,          "R slt");
    check_reg(8,  32'd0,          "R sltu");
    check_reg(9,  32'd12,         "R xor");
    check_reg(10, 32'd1,          "R srl");
    check_reg(11, -32'sd2,        "R sra");
    check_reg(12, 32'd15,         "R or");
    check_reg(13, 32'd3,          "R and");
    check_reg(14, 32'd20,         "I addi");
    check_reg(15, 32'd1,          "I slti");
    check_reg(16, 32'd0,          "I sltiu");
    check_reg(17, 32'd12,         "I xori");
    check_reg(18, 32'd15,         "I ori");
    check_reg(19, 32'd7,          "I andi");
    check_reg(20, 32'd48,         "I slli");
    check_reg(21, 32'd7,          "I srli");
    check_reg(22, -32'sd4,        "I srai");
    check_reg(3,  32'h12345000,   "lui write-back");
    check_reg(23, 32'd4420,       "auipc write-back");
    check_reg(24, 32'd20,         "lw roundtrip");
    check_reg(25, 32'd6,          "branch not-taken count");
    check_reg(26, 32'd6,          "branch taken count");
    check_reg(27, 32'd0,          "backward branch loop counter");
    check_reg(28, 32'd1,          "backward branch exit flag");
    check_reg(1,  -32'sd3532,     "lh sign extension");
    check_reg(2,  32'd62004,      "lhu zero extension");
    check_reg(29, 32'd77,         "post-u-type execution");
    check_reg(30, -32'sd128,      "lb sign extension");
    check_reg(31, 32'd128,        "lbu / illegal no regwrite side effect");

    if (uTop.uMemStage.uDataRam.rMemRam[16] !== 32'd20) begin
      $display("[FAIL] Data memory word[16] : got=%0d exp=20", uTop.uMemStage.uDataRam.rMemRam[16]);
      rErrCnt = rErrCnt + 1;
    end else begin
      $display("[PASS] Data memory word[16] : got=%0d (0x%08h) exp=%0d (0x%08h)",
        uTop.uMemStage.uDataRam.rMemRam[16],
        uTop.uMemStage.uDataRam.rMemRam[16],
        32'd20,
        32'd20
      );
    end

    if (uTop.uMemStage.uDataRam.rMemRam[17] !== 32'hF2347F80) begin
      $display("[FAIL] Data memory word[17] : got=0x%08h exp=0xF2347F80", uTop.uMemStage.uDataRam.rMemRam[17]);
      rErrCnt = rErrCnt + 1;
    end else begin
      $display("[PASS] Data memory word[17] : got=0x%08h exp=0x%08h",
        uTop.uMemStage.uDataRam.rMemRam[17],
        32'hF2347F80
      );
    end

    if (rErrCnt != 0) begin
      $display("tb_top FAILED with %0d error(s)", rErrCnt);
      $fatal(1, "tb_top failed");
      disable tb_main;
    end

    $display("tb_top PASSED");
    $finish;
  end

endmodule
