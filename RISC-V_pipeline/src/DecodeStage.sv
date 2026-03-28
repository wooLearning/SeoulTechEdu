`timescale 1ns / 1ps

/*
[MODULE_INFO_START]
Name: DecodeStage
Role: RTL module implementing pipeline decode, hazard detect, and ID/EX register
Summary:
  - Owns instruction decode, immediate generation, regfile read, and load-use hazard detect
  - Applies decode-side write-back bypass and bubbles the ID/EX packet on flush or stall
StateDescription:
  - ID/EX register: decoded control, operands, immediates, and illegal metadata
[MODULE_INFO_END]
*/
module DecodeStage (
  input  logic                    iClk,
  input  logic                    iRstn,
  input  logic                    iFlush,
  input  logic                    iIfIdValid,
  input  logic [31:0]             iIfIdPc,
  input  logic [31:0]             iIfIdPcPlus4,
  input  logic [31:0]             iIfIdInstr,
  input  logic                    iWbWrEn,
  input  logic [4:0]              iWbRdAddr,
  input  logic [31:0]             iWbWrData,
  output logic                    oLoadUseStall,
  output logic                    oIdExValid,
  output logic                    oIdExIllegal,
  output logic [31:0]             oIdExPc,
  output logic [31:0]             oIdExPcPlus4,
  output logic [31:0]             oIdExInstr,
  output logic [31:0]             oIdExImm,
  output logic [31:0]             oIdExRs1Data,
  output logic [31:0]             oIdExRs2Data,
  output logic [4:0]              oIdExRs1Addr,
  output logic [4:0]              oIdExRs2Addr,
  output logic [4:0]              oIdExRdAddr,
  output logic                    oIdExRegWrite,
  output logic                    oIdExMemWrite,
  output logic                    oIdExAluSrc,
  output rv32i_pkg::alu_a_sel_e   oIdExAluASel,
  output rv32i_pkg::wb_sel_e      oIdExWbSel,
  output rv32i_pkg::alu_op_e      oIdExAluOp,
  output rv32i_pkg::load_type_e   oIdExLoadType,
  output rv32i_pkg::store_type_e  oIdExStoreType,
  output rv32i_pkg::branch_e      oIdExBranchType,
  output rv32i_pkg::jump_e        oIdExJumpType
);
  localparam logic [31:0] LP_NOP = 32'h00000013;

  logic [6:0]  wIdOpcode;
  logic [2:0]  wIdFunct3;
  logic [6:0]  wIdFunct7;
  logic [4:0]  wIdRs1Addr;
  logic [4:0]  wIdRs2Addr;
  logic [4:0]  wIdRdAddr;
  logic [31:0] wIdImm;
  logic [31:0] wRegfileRs1DataRaw;
  logic [31:0] wRegfileRs2DataRaw;
  logic [31:0] wIdRs1Data;
  logic [31:0] wIdRs2Data;
  logic        wIdRegWrite;
  logic        wIdMemWrite;
  logic        wIdAluSrc;
  logic        wIdIllegal;
  logic        wIdUsesRs1;
  logic        wIdUsesRs2;
  rv32i_pkg::alu_a_sel_e   wIdAluASel;
  rv32i_pkg::wb_sel_e      wIdWbSel;
  rv32i_pkg::alu_op_e      wIdAluOp;
  rv32i_pkg::load_type_e   wIdLoadType;
  rv32i_pkg::store_type_e  wIdStoreType;
  rv32i_pkg::imm_sel_e     wIdImmSel;
  rv32i_pkg::branch_e      wIdBranchType;
  rv32i_pkg::jump_e        wIdJumpType;

  InstrFields uInstrFields (
    .iInstr  (iIfIdInstr),
    .oOpcode (wIdOpcode),
    .oFunct3 (wIdFunct3),
    .oFunct7 (wIdFunct7),
    .oRs1    (wIdRs1Addr),
    .oRs2    (wIdRs2Addr),
    .oRd     (wIdRdAddr)
  );

  ControlUnit uControlUnit (
    .iInstrValid (iIfIdValid),
    .iOpcode     (wIdOpcode),
    .iFunct3     (wIdFunct3),
    .iFunct7     (wIdFunct7),
    .oRegWrite   (wIdRegWrite),
    .oMemWrite   (wIdMemWrite),
    .oAluSrc     (wIdAluSrc),
    .oAluASel    (wIdAluASel),
    .oWbSel      (wIdWbSel),
    .oAluOp      (wIdAluOp),
    .oLoadType   (wIdLoadType),
    .oStoreType  (wIdStoreType),
    .oImmSel     (wIdImmSel),
    .oBranchType (wIdBranchType),
    .oJumpType   (wIdJumpType),
    .oIllegal    (wIdIllegal)
  );

  ImmGen uImmGen (
    .iInstr  (iIfIdInstr),
    .iImmSel (wIdImmSel),
    .oImm    (wIdImm)
  );

  Regfile uRegfile (
    .iClk       (iClk),
    .iRstn      (iRstn),
    .iRs1Addr   (wIdRs1Addr),
    .iRs2Addr   (wIdRs2Addr),
    .iRdAddr    (iWbRdAddr),
    .iRdWrData  (iWbWrData),
    .iRdWrEn    (iWbWrEn),
    .oRs1RdData (wRegfileRs1DataRaw),
    .oRs2RdData (wRegfileRs2DataRaw)
  );

  HazardUnit uHazardUnit (
    .iIdValid      (iIfIdValid),
    .iIdRs1Addr    (wIdRs1Addr),
    .iIdRs2Addr    (wIdRs2Addr),
    .iIdUsesRs1    (wIdUsesRs1),
    .iIdUsesRs2    (wIdUsesRs2),
    .iExValid      (oIdExValid),
    .iExRdAddr     (oIdExRdAddr),
    .iExIsLoad     (oIdExLoadType != rv32i_pkg::LOAD_NONE),
    .oLoadUseStall (oLoadUseStall)
  );

  assign wIdRs1Data =
    (wIdRs1Addr != 5'd0) && iWbWrEn && (iWbRdAddr == wIdRs1Addr) ?
    iWbWrData : wRegfileRs1DataRaw;

  assign wIdRs2Data =
    (wIdRs2Addr != 5'd0) && iWbWrEn && (iWbRdAddr == wIdRs2Addr) ?
    iWbWrData : wRegfileRs2DataRaw;

  always_comb begin
    wIdUsesRs1 = 1'b0;
    wIdUsesRs2 = 1'b0;

    if (iIfIdValid) begin
      unique case (wIdOpcode)
        rv32i_pkg::LP_OPCODE_RTYPE: begin
          wIdUsesRs1 = 1'b1;
          wIdUsesRs2 = 1'b1;
        end
        rv32i_pkg::LP_OPCODE_OPIMM,
        rv32i_pkg::LP_OPCODE_LOAD,
        rv32i_pkg::LP_OPCODE_JALR: begin
          wIdUsesRs1 = 1'b1;
        end
        rv32i_pkg::LP_OPCODE_STORE,
        rv32i_pkg::LP_OPCODE_BRANCH: begin
          wIdUsesRs1 = 1'b1;
          wIdUsesRs2 = 1'b1;
        end
        default: begin end
      endcase
    end
  end

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      oIdExValid      <= 1'b0;
      oIdExIllegal    <= 1'b0;
      oIdExPc         <= 32'd0;
      oIdExPcPlus4    <= 32'd0;
      oIdExInstr      <= LP_NOP;
      oIdExImm        <= 32'd0;
      oIdExRs1Data    <= 32'd0;
      oIdExRs2Data    <= 32'd0;
      oIdExRs1Addr    <= 5'd0;
      oIdExRs2Addr    <= 5'd0;
      oIdExRdAddr     <= 5'd0;
      oIdExRegWrite   <= 1'b0;
      oIdExMemWrite   <= 1'b0;
      oIdExAluSrc     <= 1'b0;
      oIdExAluASel    <= rv32i_pkg::ALUA_RS1;
      oIdExWbSel      <= rv32i_pkg::WB_ALU;
      oIdExAluOp      <= rv32i_pkg::ALU_ADD;
      oIdExLoadType   <= rv32i_pkg::LOAD_NONE;
      oIdExStoreType  <= rv32i_pkg::STORE_NONE;
      oIdExBranchType <= rv32i_pkg::BR_NONE;
      oIdExJumpType   <= rv32i_pkg::JUMP_NONE;
    end else if (iFlush || oLoadUseStall) begin
      oIdExValid      <= 1'b0;
      oIdExIllegal    <= 1'b0;
      oIdExPc         <= 32'd0;
      oIdExPcPlus4    <= 32'd0;
      oIdExInstr      <= LP_NOP;
      oIdExImm        <= 32'd0;
      oIdExRs1Data    <= 32'd0;
      oIdExRs2Data    <= 32'd0;
      oIdExRs1Addr    <= 5'd0;
      oIdExRs2Addr    <= 5'd0;
      oIdExRdAddr     <= 5'd0;
      oIdExRegWrite   <= 1'b0;
      oIdExMemWrite   <= 1'b0;
      oIdExAluSrc     <= 1'b0;
      oIdExAluASel    <= rv32i_pkg::ALUA_RS1;
      oIdExWbSel      <= rv32i_pkg::WB_ALU;
      oIdExAluOp      <= rv32i_pkg::ALU_ADD;
      oIdExLoadType   <= rv32i_pkg::LOAD_NONE;
      oIdExStoreType  <= rv32i_pkg::STORE_NONE;
      oIdExBranchType <= rv32i_pkg::BR_NONE;
      oIdExJumpType   <= rv32i_pkg::JUMP_NONE;
    end else begin
      oIdExValid      <= iIfIdValid;
      oIdExIllegal    <= wIdIllegal;
      oIdExPc         <= iIfIdPc;
      oIdExPcPlus4    <= iIfIdPcPlus4;
      oIdExInstr      <= iIfIdInstr;
      oIdExImm        <= wIdImm;
      oIdExRs1Data    <= wIdRs1Data;
      oIdExRs2Data    <= wIdRs2Data;
      oIdExRs1Addr    <= wIdRs1Addr;
      oIdExRs2Addr    <= wIdRs2Addr;
      oIdExRdAddr     <= wIdRdAddr;
      oIdExRegWrite   <= wIdRegWrite;
      oIdExMemWrite   <= wIdMemWrite;
      oIdExAluSrc     <= wIdAluSrc;
      oIdExAluASel    <= wIdAluASel;
      oIdExWbSel      <= wIdWbSel;
      oIdExAluOp      <= wIdAluOp;
      oIdExLoadType   <= wIdLoadType;
      oIdExStoreType  <= wIdStoreType;
      oIdExBranchType <= wIdBranchType;
      oIdExJumpType   <= wIdJumpType;
    end
  end

endmodule
