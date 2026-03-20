`timescale 1ns / 1ps

// Datapath for the single-cycle core: register file, immediate path, ALU, and PC redirect logic.
module Datapath (
  input  logic                iClk,
  input  logic                iRstn,
  input  logic [31:0]         iPc,
  input  logic [31:0]         iPcPlus4,
  input  logic [31:0]         iInstr,
  input  logic [4:0]          iRs1Addr,
  input  logic [4:0]          iRs2Addr,
  input  logic [4:0]          iRdAddr,
  input  logic                iRegWrite,
  input  logic                iAluSrc,
  input  rv32i_pkg::wb_sel_e  iWbSel,
  input  rv32i_pkg::alu_op_e  iAluOp,
  input  rv32i_pkg::imm_sel_e iImmSel,
  input  rv32i_pkg::branch_e  iBranchType,
  input  rv32i_pkg::jump_e    iJumpType,
  input  logic [31:0]         iMemRdData,
  output logic [31:0]         oAluResult,
  output logic [31:0]         oRs2Data,
  output logic [31:0]         oRdWrData,
  output logic                oPcTargetEn,
  output logic [31:0]         oPcTarget
);

  logic [31:0] wRs1Data;
  logic [31:0] wRs2Data;
  logic [31:0] wImmData;
  logic [31:0] wAluB;
  logic [31:0] wAluResult;
  logic [31:0] wRdWrData;
  logic [31:0] wPcPlusImm;
  logic        wEq;
  logic        wBranchTaken;
  logic        wLtSigned;
  logic        wLtUnsigned;

  ImmGen uImmGen (
    .iInstr  (iInstr),
    .iImmSel (iImmSel),
    .oImm    (wImmData)
  );

  Regfile uRegfile (
    .iClk      (iClk),
    .iRstn     (iRstn),
    .iRs1Addr  (iRs1Addr),
    .iRs2Addr  (iRs2Addr),
    .iRdAddr   (iRdAddr),
    .iRdWrData (wRdWrData),
    .iRdWrEn   (iRegWrite),
    .oRs1RdData(wRs1Data),
    .oRs2RdData(wRs2Data)
  );

  // Operand B comes from rs2 or the decoded immediate depending on instruction type.
  assign wAluB       = iAluSrc ? wImmData : wRs2Data;
  // Branches reuse rs1/rs2 compare results instead of a dedicated comparator.
  assign wEq         = (wRs1Data == wRs2Data);
  assign wPcPlusImm  = iPc + wImmData;
  assign wLtSigned   = ($signed(wRs1Data) < $signed(wRs2Data));
  assign wLtUnsigned = (wRs1Data < wRs2Data);

  Alu uAlu (
    .iA      (wRs1Data),
    .iB      (wAluB),
    .iAluOp  (iAluOp),
    .oResult (wAluResult)
  );

  assign oAluResult   = wAluResult;
  assign oRs2Data     = wRs2Data;
  assign oRdWrData    = wRdWrData;

  always_comb begin
    // Select the value written back into rd.
    wRdWrData = wAluResult;

    unique case (iWbSel)
      rv32i_pkg::WB_ALU: wRdWrData = wAluResult;
      rv32i_pkg::WB_MEM: wRdWrData = iMemRdData;
      rv32i_pkg::WB_PC4: wRdWrData = iPcPlus4;
      rv32i_pkg::WB_IMM: wRdWrData = wImmData;
      rv32i_pkg::WB_PCIMM: wRdWrData = wPcPlusImm;
      default: wRdWrData = wAluResult;
    endcase
  end

  always_comb begin
    // Branch decision is generated from the compare flags above.
    wBranchTaken = 1'b0;

    unique case (iBranchType)
      rv32i_pkg::BR_BEQ:  wBranchTaken = wEq;
      rv32i_pkg::BR_BNE:  wBranchTaken = !wEq;
      rv32i_pkg::BR_BLT:  wBranchTaken = wLtSigned;
      rv32i_pkg::BR_BGE:  wBranchTaken = !wLtSigned;
      rv32i_pkg::BR_BLTU: wBranchTaken = wLtUnsigned;
      rv32i_pkg::BR_BGEU: wBranchTaken = !wLtUnsigned;
      default: wBranchTaken = 1'b0;
    endcase
  end

  always_comb begin
    // Jumps always redirect control flow; branches redirect only when taken.
    oPcTargetEn = 1'b0;
    oPcTarget   = wPcPlusImm;

    unique case (iJumpType)
      rv32i_pkg::JUMP_JAL: begin
        oPcTargetEn = 1'b1;
        oPcTarget   = wPcPlusImm;
      end
      rv32i_pkg::JUMP_JALR: begin
        oPcTargetEn = 1'b1;
        oPcTarget   = {wAluResult[31:1], 1'b0};
      end
      default: begin
        oPcTargetEn = wBranchTaken;
        oPcTarget   = wPcPlusImm;
      end
    endcase
  end

endmodule
