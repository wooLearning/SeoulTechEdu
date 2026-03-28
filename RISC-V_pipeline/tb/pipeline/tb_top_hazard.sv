`timescale 1ns / 1ps

/*
[TB_INFO_START]
Name: tb_top_hazard
Target: Top
Role: Testbench for validating mixed data/control hazard behavior in the pipeline top
Scenario:
  - Exercise forwarding through ALU, branch, and store/load mixed paths
  - Trigger classic load-use and load-to-branch stalls
  - Confirm not-taken branches, taken branches, and back-to-back branch/jump behavior
  - Confirm jal, jalr, and illegal no-side-effect behavior
CheckPoint:
  - Verify hazard-related internal flags are observed during simulation
  - Check final register and memory state for the mixed hazard ROM
  - Produce a VCD so the pipeline timing can be inspected directly
[TB_INFO_END]
*/
module tb_top_hazard;
  import instr_mem_paths_pkg::*;

  localparam int LP_CLK_PERIOD = 10;
  localparam int LP_RAM_DEPTH  = 256;
  localparam int LP_MAX_CYCLES = 320;
  localparam logic [31:0] LP_LOAD_BRANCH_INSTR = 32'h00660463;
  localparam logic [31:0] LP_NOP = 32'h00000013;
  localparam string LP_INSTR_MEM_FILE = LP_INSTR_MEM_HAZARD;

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
  logic wSawIfActive;
  logic wSawIdActive;
  logic wSawExActive;
  logic wSawWbActive;
  logic wSawWbCommit;
  logic wSawLoadUseStall;
  logic wSawExMemForward;
  logic wSawMemWbForward;
  logic wSawBranchRedirect;
  logic wSawJumpRedirect;
  logic wSawNotTakenBranch;
  logic wSawBranchOperandForward;
  logic wSawLoadBranchStall;
  logic wSawIllegalInPipe;
  logic wSawBadLoadBranchSkip;
  logic wSawBadJalSkip;
  logic wSawBadJalrSkip;
  logic wSawBadTakenBranchFlush;
  integer rErrCnt;
  integer rCycle;
  integer idxMemInit;

  Top #(
    .P_USE_HAZARD_ROM(1'b1),
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

  function automatic string branch_name(input rv32i_pkg::branch_e iBranch);
    begin
      case (iBranch)
        rv32i_pkg::BR_BEQ : branch_name = "BEQ";
        rv32i_pkg::BR_BNE : branch_name = "BNE";
        rv32i_pkg::BR_BLT : branch_name = "BLT";
        rv32i_pkg::BR_BGE : branch_name = "BGE";
        rv32i_pkg::BR_BLTU: branch_name = "BLTU";
        rv32i_pkg::BR_BGEU: branch_name = "BGEU";
        default           : branch_name = "NONE";
      endcase
    end
  endfunction

  function automatic string jump_name(input rv32i_pkg::jump_e iJump);
    begin
      case (iJump)
        rv32i_pkg::JUMP_JAL : jump_name = "JAL";
        rv32i_pkg::JUMP_JALR: jump_name = "JALR";
        default             : jump_name = "NONE";
      endcase
    end
  endfunction

  task automatic log_pipeline_event(input string iTag);
    begin
      $display("[TRACE][C%0d][%s] PC=%0d (0x%08h) IF/ID/EX/WB=%0b%0b%0b%0b stall=%0b redirect=%0b fwdA=%0d fwdB=%0d ifid=0x%08h branch=%s jump=%s",
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
        uTop.rIfIdInstr,
        branch_name(uTop.rIdExBranchType),
        jump_name(uTop.rIdExJumpType)
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
    iClk               = 1'b0;
    iRstn              = 1'b0;
    wSawIfActive       = 1'b0;
    wSawIdActive       = 1'b0;
    wSawExActive       = 1'b0;
    wSawWbActive       = 1'b0;
    wSawWbCommit       = 1'b0;
    wSawLoadUseStall   = 1'b0;
    wSawExMemForward   = 1'b0;
    wSawMemWbForward   = 1'b0;
    wSawBranchRedirect = 1'b0;
    wSawJumpRedirect   = 1'b0;
    wSawNotTakenBranch = 1'b0;
    wSawBranchOperandForward = 1'b0;
    wSawLoadBranchStall = 1'b0;
    wSawIllegalInPipe  = 1'b0;
    wSawBadLoadBranchSkip = 1'b0;
    wSawBadJalSkip     = 1'b0;
    wSawBadJalrSkip    = 1'b0;
    wSawBadTakenBranchFlush = 1'b0;
    rErrCnt            = 0;
    rCycle             = 0;

    for (idxMemInit = 0; idxMemInit < LP_RAM_DEPTH; idxMemInit = idxMemInit + 1) begin
      uTop.uMemStage.uDataRam.rMemRam[idxMemInit] = 32'd0;
    end

    $dumpfile("tb_top_hazard.vcd");
    $dumpvars(0, tb_top_hazard);

    repeat (2) @(posedge iClk);
    iRstn = 1'b1;

    repeat (3) @(posedge iClk);
    #1;
    if ((uTop.rIfIdInstr === LP_NOP) && (wDbgPc >= 32'd8)) begin
      $fatal(1,
        "tb_top_hazard ROM sanity failed: IF/ID instr stayed nop at PC=%0d",
        wDbgPc
      );
    end

    begin : wait_for_completion
      repeat (LP_MAX_CYCLES) begin
        @(posedge iClk);
        #1;
        rCycle = rCycle + 1;

        if (wDbgIfActive) begin
          wSawIfActive = 1'b1;
        end

        if (wDbgIdActive) begin
          wSawIdActive = 1'b1;
        end

        if (wDbgExActive) begin
          wSawExActive = 1'b1;
        end

        if (wDbgWbActive) begin
          wSawWbActive = 1'b1;
        end

        if (wDbgWbCommit) begin
          wSawWbCommit = 1'b1;
          log_commit_event();
        end

        if (wDbgLoadUseStall) begin
          wSawLoadUseStall = 1'b1;
          log_pipeline_event("STALL");
        end

        if ((wDbgForwardA == 2'b10) || (wDbgForwardB == 2'b10)) begin
          wSawExMemForward = 1'b1;
          log_pipeline_event("FWD-EXMEM");
        end

        if ((wDbgForwardA == 2'b01) || (wDbgForwardB == 2'b01)) begin
          wSawMemWbForward = 1'b1;
          log_pipeline_event("FWD-MEMWB");
        end

        if (wDbgExPcRedirectEn && (uTop.rIdExBranchType != rv32i_pkg::BR_NONE)) begin
          wSawBranchRedirect = 1'b1;
          log_pipeline_event("BRANCH-REDIRECT");
        end

        if (wDbgExPcRedirectEn && (uTop.rIdExJumpType != rv32i_pkg::JUMP_NONE)) begin
          wSawJumpRedirect = 1'b1;
          log_pipeline_event("JUMP-REDIRECT");
        end

        if (uTop.rIdExValid &&
            (uTop.rIdExBranchType != rv32i_pkg::BR_NONE) &&
            !wDbgExPcRedirectEn) begin
          wSawNotTakenBranch = 1'b1;
        end

        if (uTop.rIdExValid &&
            (uTop.rIdExBranchType != rv32i_pkg::BR_NONE) &&
            ((wDbgForwardA != 2'b00) || (wDbgForwardB != 2'b00))) begin
          wSawBranchOperandForward = 1'b1;
        end

        if (wDbgLoadUseStall && (uTop.rIfIdInstr == LP_LOAD_BRANCH_INSTR)) begin
          wSawLoadBranchStall = 1'b1;
        end

        if (uTop.rIdExIllegal || uTop.rExMemIllegal || uTop.rMemWbIllegal) begin
          wSawIllegalInPipe = 1'b1;
          log_pipeline_event("ILLEGAL-IN-PIPE");
        end

        if (uTop.uDecodeStage.uRegfile.rMemReg[13] == 32'd99) begin
          wSawBadLoadBranchSkip = 1'b1;
        end

        if (uTop.uDecodeStage.uRegfile.rMemReg[16] == 32'd99) begin
          wSawBadJalSkip = 1'b1;
        end

        if (uTop.uDecodeStage.uRegfile.rMemReg[23] == 32'd111) begin
          wSawBadJalrSkip = 1'b1;
        end

        if (uTop.uDecodeStage.uRegfile.rMemReg[25] == 32'd140) begin
          wSawBadTakenBranchFlush = 1'b1;
        end

        if (uTop.uDecodeStage.uRegfile.rMemReg[31] == 32'd1) begin
          disable wait_for_completion;
        end
      end

      $display("[FAIL] Timeout waiting for hazard ROM completion");
      rErrCnt = rErrCnt + 1;
    end

    check_seen(wSawIfActive,            "IF stage activity observed",             "IF stage activity was never observed");
    check_seen(wSawIdActive,            "ID stage activity observed",             "ID stage activity was never observed");
    check_seen(wSawExActive,            "EX stage activity observed",             "EX stage activity was never observed");
    check_seen(wSawWbActive,            "WB stage activity observed",             "WB stage activity was never observed");
    check_seen(wSawWbCommit,            "write-back commit observed",             "write-back commit was never observed");
    check_seen(wSawLoadUseStall,        "load-use stall observed",                "load-use stall was never observed");
    check_seen(wSawExMemForward,        "EX/MEM forwarding observed",             "EX/MEM forwarding was never observed");
    check_seen(wSawMemWbForward,        "MEM/WB forwarding observed",             "MEM/WB forwarding was never observed");
    check_seen(wSawBranchRedirect,      "branch redirect observed",               "branch redirect was never observed");
    check_seen(wSawJumpRedirect,        "jump redirect observed",                 "jump redirect was never observed");
    check_seen(wSawNotTakenBranch,      "not-taken branch path observed",         "not-taken branch path was never observed");
    check_seen(wSawBranchOperandForward,"branch operand forwarding observed",     "branch operand forwarding was never observed");
    check_seen(wSawLoadBranchStall,     "load-to-branch stall observed",          "load-to-branch stall was never observed");
    check_seen(wSawIllegalInPipe,       "illegal instruction marker observed",    "illegal instruction marker was never observed");

    if (wSawBadLoadBranchSkip) begin
      $display("[FAIL] branch-flushed instruction wrote x13=99");
      rErrCnt = rErrCnt + 1;
    end else begin
      $display("[PASS] branch flush suppressed x13=99");
    end

    if (wSawBadJalSkip) begin
      $display("[FAIL] jal-flushed instruction wrote x16=99");
      rErrCnt = rErrCnt + 1;
    end else begin
      $display("[PASS] jal flush suppressed x16=99");
    end

    if (wSawBadJalrSkip) begin
      $display("[FAIL] jalr-flushed instruction wrote x23=111");
      rErrCnt = rErrCnt + 1;
    end else begin
      $display("[PASS] jalr flush suppressed x23=111");
    end

    if (wSawBadTakenBranchFlush) begin
      $display("[FAIL] taken branch failed to flush back-to-back jal (x25=140)");
      rErrCnt = rErrCnt + 1;
    end else begin
      $display("[PASS] taken branch flushed back-to-back jal");
    end

    check_reg(3,  32'd12,         "forward chain x3");
    check_reg(4,  32'd17,         "forward chain x4");
    check_reg(5,  32'd10,         "forward chain x5");
    check_reg(6,  32'd22,         "forward chain x6");
    check_reg(7,  32'd22,         "load result x7");
    check_reg(8,  32'd23,         "load-use dependent x8");
    check_reg(9,  32'd45,         "post-stall ALU x9");
    check_reg(10, 32'd1,          "branch source x10");
    check_reg(11, 32'd11,         "not-taken branch fall-through x11");
    check_reg(12, 32'd22,         "load-branch source x12");
    check_reg(13, 32'd13,         "taken branch target x13");
    check_reg(14, 32'd1,          "back-to-back branch source x14");
    check_reg(15, 32'd104,        "jal link x15");
    check_reg(16, 32'd16,         "jal target x16");
    check_reg(17, 32'd124,        "jalr base x17");
    check_reg(18, 32'd55,         "illegal no-side-effect x18");
    check_reg(19, 32'd120,        "jalr link x19");
    check_reg(20, 32'd64,         "base pointer x20");
    check_reg(21, 32'd68,         "unused base x21");
    check_reg(22, 32'd72,         "forwarded store address x22");
    check_reg(23, 32'd23,         "jalr target x23");
    check_reg(24, 32'd1,          "taken bne source x24");
    check_reg(25, 32'd25,         "taken branch target x25");
    check_reg(30, 32'd1,          "gap marker x30");
    check_reg(31, 32'd1,          "completion flag x31");

    check_mem(16, 32'd22, "store/load roundtrip word[16]");
    check_mem(18, 32'd45, "forwarded store word[18]");

    if (rErrCnt != 0) begin
      $display("tb_top_hazard FAILED with %0d error(s)", rErrCnt);
      $fatal(1, "tb_top_hazard failed");
      disable tb_main;
    end

    $display("tb_top_hazard PASSED");
    $finish;
  end

endmodule
