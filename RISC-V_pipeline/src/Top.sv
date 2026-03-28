`timescale 1ns / 1ps

/*
[MODULE_INFO_START]
Name: Top
Role: RTL module implementing the first-pass 5-stage RV32I pipeline top
Summary:
  - Reuses the legacy RV32I decode, ALU, register file, ROM, and RAM helpers
  - Implements IF/ID/EX/MEM/WB stages with predict-not-taken control flow
  - Preserves legacy unsupported-instruction behavior as no-side-effect sequential execution
StateDescription:
  - IF/ID: fetch packet with valid, PC, PC+4, instruction
  - ID/EX: decoded control, operands, immediates, and illegal metadata
  - EX/MEM: execution result, store data, memory controls, and redirect result
  - MEM/WB: final write-back packet for register commit
[MODULE_INFO_END]
*/
module Top #(
  parameter bit P_USE_BUBBLE_ROM = 1'b0,
  parameter bit P_USE_HAZARD_ROM = 1'b0,
  parameter bit P_USE_TEST2_ROM  = 1'b0,
  parameter logic [31:0] P_RESET_PC = 32'd0,
  parameter logic [31:0] P_INSTR_BASE_ADDR = 32'd0,
  parameter string P_INSTR_MEM_FILE = ""
) (
  input logic iClk,
  input logic iRstn,
  output logic [31:0] oDbgPc,
  output logic        oDbgIfActive,
  output logic        oDbgIdActive,
  output logic        oDbgExActive,
  output logic        oDbgWbActive,
  output logic        oDbgWbCommit,
  output logic        oDbgLoadUseStall,
  output logic [1:0]  oDbgForwardA,
  output logic [1:0]  oDbgForwardB,
  output logic        oDbgExPcRedirectEn,
  output logic        oTraceRetireValid,
  output logic        oTraceRetireIllegal,
  output logic [31:0] oTraceRetirePc,
  output logic [31:0] oTraceRetireInstr,
  output logic        oTraceRetireRegWrite,
  output logic [4:0]  oTraceRetireRdAddr,
  output logic [31:0] oTraceRetireRdData,
  output logic        oTraceRetireMemWrite,
  output logic [31:0] oTraceRetireMemAddr,
  output logic [31:0] oTraceRetireMemData
);

  // IF/ID pipeline registers
  logic        rIfIdValid;
  logic [31:0] rIfIdPc;
  logic [31:0] rIfIdPcPlus4;
  logic [31:0] rIfIdInstr;

  // Hazard control
  logic wHazard2Top_LoadUseStall;

  // ID/EX pipeline registers
  logic        rIdExValid;
  logic        rIdExIllegal;
  logic [31:0] rIdExPc;
  logic [31:0] rIdExPcPlus4;
  logic [31:0] rIdExInstr;
  logic [31:0] rIdExImm;
  logic [31:0] rIdExRs1Data;
  logic [31:0] rIdExRs2Data;
  logic [4:0]  rIdExRs1Addr;
  logic [4:0]  rIdExRs2Addr;
  logic [4:0]  rIdExRdAddr;
  logic        rIdExRegWrite;
  logic        rIdExMemWrite;
  logic        rIdExAluSrc;
  rv32i_pkg::alu_a_sel_e   rIdExAluASel;
  rv32i_pkg::wb_sel_e     rIdExWbSel;
  rv32i_pkg::alu_op_e     rIdExAluOp;
  rv32i_pkg::load_type_e  rIdExLoadType;
  rv32i_pkg::store_type_e rIdExStoreType;
  rv32i_pkg::branch_e     rIdExBranchType;
  rv32i_pkg::jump_e       rIdExJumpType;

  // EX stage
  logic [1:0]  wForwardA;
  logic [1:0]  wForwardB;
  logic        wExPcRedirectEn;
  logic [31:0] wExPcRedirectTarget;

  // EX/MEM pipeline registers
  logic        rExMemValid;
  logic        rExMemIllegal;
  logic        rExMemRegWrite;
  logic        rExMemMemWrite;
  logic [4:0]  rExMemRdAddr;
  logic [31:0] rExMemPc;
  logic [31:0] rExMemInstr;
  logic [31:0] rExMemAluResult;
  logic [31:0] rExMemStoreData;
  logic [31:0] rExMemWbDataNonMem;
  rv32i_pkg::wb_sel_e     rExMemWbSel;
  rv32i_pkg::load_type_e  rExMemLoadType;
  rv32i_pkg::store_type_e rExMemStoreType;

  // MEM/WB pipeline registers
  logic        rMemWbValid;
  logic        rMemWbIllegal;
  logic        rMemWbRegWrite;
  logic [4:0]  rMemWbRdAddr;
  logic [31:0] rMemWbPc;
  logic [31:0] rMemWbInstr;
  logic [31:0] rMemWbWrData;
  logic        rMemWbMemWrite;
  logic [31:0] rMemWbMemAddr;
  logic [31:0] rMemWbMemData;

  // Write-back commit
  logic        wMemWb2Regfile_WrEn;
  logic [4:0]  wMemWb2Regfile_RdAddr;
  logic [31:0] wMemWb2Regfile_WrData;

  // Retire trace registers
  logic        rTraceRetireValid;
  logic        rTraceRetireIllegal;
  logic [31:0] rTraceRetirePc;
  logic [31:0] rTraceRetireInstr;
  logic        rTraceRetireRegWrite;
  logic [4:0]  rTraceRetireRdAddr;
  logic [31:0] rTraceRetireRdData;
  logic        rTraceRetireMemWrite;
  logic [31:0] rTraceRetireMemAddr;
  logic [31:0] rTraceRetireMemData;

  assign oDbgIfActive        = rIfIdValid;
  assign oDbgIdActive        = rIdExValid;
  assign oDbgExActive        = rExMemValid;
  assign oDbgWbActive        = rMemWbValid;
  assign oDbgWbCommit        = wMemWb2Regfile_WrEn;
  assign oDbgLoadUseStall   = wHazard2Top_LoadUseStall;
  assign oDbgForwardA       = wForwardA;
  assign oDbgForwardB       = wForwardB;
  assign oDbgExPcRedirectEn = wExPcRedirectEn;
  assign oTraceRetireValid    = rTraceRetireValid;
  assign oTraceRetireIllegal  = rTraceRetireIllegal;
  assign oTraceRetirePc       = rTraceRetirePc;
  assign oTraceRetireInstr    = rTraceRetireInstr;
  assign oTraceRetireRegWrite = rTraceRetireRegWrite;
  assign oTraceRetireRdAddr   = rTraceRetireRdAddr;
  assign oTraceRetireRdData   = rTraceRetireRdData;
  assign oTraceRetireMemWrite = rTraceRetireMemWrite;
  assign oTraceRetireMemAddr  = rTraceRetireMemAddr;
  assign oTraceRetireMemData  = rTraceRetireMemData;

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      rTraceRetireValid    <= 1'b0;
      rTraceRetireIllegal  <= 1'b0;
      rTraceRetirePc       <= 32'd0;
      rTraceRetireInstr    <= 32'h00000013;
      rTraceRetireRegWrite <= 1'b0;
      rTraceRetireRdAddr   <= 5'd0;
      rTraceRetireRdData   <= 32'd0;
      rTraceRetireMemWrite <= 1'b0;
      rTraceRetireMemAddr  <= 32'd0;
      rTraceRetireMemData  <= 32'd0;
    end else begin
      rTraceRetireValid    <= rMemWbValid;
      rTraceRetireIllegal  <= rMemWbIllegal;
      rTraceRetirePc       <= rMemWbPc;
      rTraceRetireInstr    <= rMemWbInstr;
      rTraceRetireRegWrite <= wMemWb2Regfile_WrEn;
      rTraceRetireRdAddr   <= wMemWb2Regfile_RdAddr;
      rTraceRetireRdData   <= wMemWb2Regfile_WrData;
      rTraceRetireMemWrite <= rMemWbMemWrite;
      rTraceRetireMemAddr  <= rMemWbMemAddr;
      rTraceRetireMemData  <= rMemWbMemData;
    end
  end

  FetchStage #(
    .P_USE_BUBBLE_ROM (P_USE_BUBBLE_ROM),
    .P_USE_HAZARD_ROM (P_USE_HAZARD_ROM),
    .P_USE_TEST2_ROM  (P_USE_TEST2_ROM),
    .P_RESET_PC       (P_RESET_PC),
    .P_INSTR_BASE_ADDR(P_INSTR_BASE_ADDR),
    .P_INSTR_MEM_FILE (P_INSTR_MEM_FILE)
  ) uFetchStage (
    .iClk            (iClk),
    .iRstn           (iRstn),
    .iStall          (wHazard2Top_LoadUseStall),
    .iRedirectEn     (wExPcRedirectEn),
    .iRedirectTarget (wExPcRedirectTarget),
    .oDbgPc          (oDbgPc),
    .oIfIdValid      (rIfIdValid),
    .oIfIdPc         (rIfIdPc),
    .oIfIdPcPlus4    (rIfIdPcPlus4),
    .oIfIdInstr      (rIfIdInstr)
  );

  DecodeStage uDecodeStage (
    .iClk           (iClk),
    .iRstn          (iRstn),
    .iFlush         (wExPcRedirectEn),
    .iIfIdValid     (rIfIdValid),
    .iIfIdPc        (rIfIdPc),
    .iIfIdPcPlus4   (rIfIdPcPlus4),
    .iIfIdInstr     (rIfIdInstr),
    .iWbWrEn        (wMemWb2Regfile_WrEn),
    .iWbRdAddr      (wMemWb2Regfile_RdAddr),
    .iWbWrData      (wMemWb2Regfile_WrData),
    .oLoadUseStall  (wHazard2Top_LoadUseStall),
    .oIdExValid     (rIdExValid),
    .oIdExIllegal   (rIdExIllegal),
    .oIdExPc        (rIdExPc),
    .oIdExPcPlus4   (rIdExPcPlus4),
    .oIdExInstr     (rIdExInstr),
    .oIdExImm       (rIdExImm),
    .oIdExRs1Data   (rIdExRs1Data),
    .oIdExRs2Data   (rIdExRs2Data),
    .oIdExRs1Addr   (rIdExRs1Addr),
    .oIdExRs2Addr   (rIdExRs2Addr),
    .oIdExRdAddr    (rIdExRdAddr),
    .oIdExRegWrite  (rIdExRegWrite),
    .oIdExMemWrite  (rIdExMemWrite),
    .oIdExAluSrc    (rIdExAluSrc),
    .oIdExAluASel   (rIdExAluASel),
    .oIdExWbSel     (rIdExWbSel),
    .oIdExAluOp     (rIdExAluOp),
    .oIdExLoadType  (rIdExLoadType),
    .oIdExStoreType (rIdExStoreType),
    .oIdExBranchType(rIdExBranchType),
    .oIdExJumpType  (rIdExJumpType)
  );

  ExecuteStage uExecuteStage (
    .iClk              (iClk),
    .iRstn             (iRstn),
    .iIdExValid        (rIdExValid),
    .iIdExIllegal      (rIdExIllegal),
    .iIdExPc           (rIdExPc),
    .iIdExPcPlus4      (rIdExPcPlus4),
    .iIdExInstr        (rIdExInstr),
    .iIdExImm          (rIdExImm),
    .iIdExRs1Data      (rIdExRs1Data),
    .iIdExRs2Data      (rIdExRs2Data),
    .iIdExRs1Addr      (rIdExRs1Addr),
    .iIdExRs2Addr      (rIdExRs2Addr),
    .iIdExRdAddr       (rIdExRdAddr),
    .iIdExRegWrite     (rIdExRegWrite),
    .iIdExMemWrite     (rIdExMemWrite),
    .iIdExAluSrc       (rIdExAluSrc),
    .iIdExAluASel      (rIdExAluASel),
    .iIdExWbSel        (rIdExWbSel),
    .iIdExAluOp        (rIdExAluOp),
    .iIdExLoadType     (rIdExLoadType),
    .iIdExStoreType    (rIdExStoreType),
    .iIdExBranchType   (rIdExBranchType),
    .iIdExJumpType     (rIdExJumpType),
    .iExMemValid       (rExMemValid),
    .iExMemRegWrite    (rExMemRegWrite),
    .iExMemRdAddr      (rExMemRdAddr),
    .iExMemWbDataNonMem(rExMemWbDataNonMem),
    .iExMemWbSel       (rExMemWbSel),
    .iMemWbValid       (rMemWbValid),
    .iMemWbRegWrite    (rMemWbRegWrite),
    .iMemWbRdAddr      (rMemWbRdAddr),
    .iMemWbWrData      (rMemWbWrData),
    .oForwardA         (wForwardA),
    .oForwardB         (wForwardB),
    .oPcRedirectEn     (wExPcRedirectEn),
    .oPcRedirectTarget (wExPcRedirectTarget),
    .oExMemValid       (rExMemValid),
    .oExMemIllegal     (rExMemIllegal),
    .oExMemRegWrite    (rExMemRegWrite),
    .oExMemMemWrite    (rExMemMemWrite),
    .oExMemRdAddr      (rExMemRdAddr),
    .oExMemPc          (rExMemPc),
    .oExMemInstr       (rExMemInstr),
    .oExMemAluResult   (rExMemAluResult),
    .oExMemStoreData   (rExMemStoreData),
    .oExMemWbDataNonMem(rExMemWbDataNonMem),
    .oExMemWbSel       (rExMemWbSel),
    .oExMemLoadType    (rExMemLoadType),
    .oExMemStoreType   (rExMemStoreType)
  );

  MemStage uMemStage (
    .iClk             (iClk),
    .iRstn            (iRstn),
    .iExMemValid      (rExMemValid),
    .iExMemIllegal    (rExMemIllegal),
    .iExMemRegWrite   (rExMemRegWrite),
    .iExMemMemWrite   (rExMemMemWrite),
    .iExMemRdAddr     (rExMemRdAddr),
    .iExMemPc         (rExMemPc),
    .iExMemInstr      (rExMemInstr),
    .iExMemAluResult  (rExMemAluResult),
    .iExMemStoreData  (rExMemStoreData),
    .iExMemWbDataNonMem(rExMemWbDataNonMem),
    .iExMemWbSel      (rExMemWbSel),
    .iExMemLoadType   (rExMemLoadType),
    .iExMemStoreType  (rExMemStoreType),
    .oMemWbValid      (rMemWbValid),
    .oMemWbIllegal    (rMemWbIllegal),
    .oMemWbRegWrite   (rMemWbRegWrite),
    .oMemWbRdAddr     (rMemWbRdAddr),
    .oMemWbPc         (rMemWbPc),
    .oMemWbInstr      (rMemWbInstr),
    .oMemWbWrData     (rMemWbWrData),
    .oMemWbMemWrite   (rMemWbMemWrite),
    .oMemWbMemAddr    (rMemWbMemAddr),
    .oMemWbMemData    (rMemWbMemData)
  );

  WbStage uWbStage (
    .iMemWbValid    (rMemWbValid),
    .iMemWbRegWrite (rMemWbRegWrite),
    .iMemWbRdAddr   (rMemWbRdAddr),
    .iMemWbWrData   (rMemWbWrData),
    .oRegfileWrEn   (wMemWb2Regfile_WrEn),
    .oRegfileRdAddr (wMemWb2Regfile_RdAddr),
    .oRegfileWrData (wMemWb2Regfile_WrData)
  );

endmodule
