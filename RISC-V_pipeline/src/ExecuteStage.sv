`timescale 1ns / 1ps

/*
[MODULE_INFO_START]
Name: ExecuteStage
Role: RTL module implementing pipeline execute, forwarding, redirect generation, and EX/MEM register
Summary:
  - Owns forwarding select, ALU operand muxing, compare logic, and redirect generation
  - Packages the EX result into the EX/MEM pipeline register
StateDescription:
  - EX/MEM register: execution result, store data, memory controls, and redirect result
[MODULE_INFO_END]
*/
module ExecuteStage (
  input  logic                    iClk,
  input  logic                    iRstn,
  input  logic                    iIdExValid,
  input  logic                    iIdExIllegal,
  input  logic [31:0]             iIdExPc,
  input  logic [31:0]             iIdExPcPlus4,
  input  logic [31:0]             iIdExInstr,
  input  logic [31:0]             iIdExImm,
  input  logic [31:0]             iIdExRs1Data,
  input  logic [31:0]             iIdExRs2Data,
  input  logic [4:0]              iIdExRs1Addr,
  input  logic [4:0]              iIdExRs2Addr,
  input  logic [4:0]              iIdExRdAddr,
  input  logic                    iIdExRegWrite,
  input  logic                    iIdExMemWrite,
  input  logic                    iIdExAluSrc,
  input  rv32i_pkg::alu_a_sel_e   iIdExAluASel,
  input  rv32i_pkg::wb_sel_e      iIdExWbSel,
  input  rv32i_pkg::alu_op_e      iIdExAluOp,
  input  rv32i_pkg::load_type_e   iIdExLoadType,
  input  rv32i_pkg::store_type_e  iIdExStoreType,
  input  rv32i_pkg::branch_e      iIdExBranchType,
  input  rv32i_pkg::jump_e        iIdExJumpType,
  input  logic                    iExMemValid,
  input  logic                    iExMemRegWrite,
  input  logic [4:0]              iExMemRdAddr,
  input  logic [31:0]             iExMemWbDataNonMem,
  input  rv32i_pkg::wb_sel_e      iExMemWbSel,
  input  logic                    iMemWbValid,
  input  logic                    iMemWbRegWrite,
  input  logic [4:0]              iMemWbRdAddr,
  input  logic [31:0]             iMemWbWrData,
  output logic [1:0]              oForwardA,
  output logic [1:0]              oForwardB,
  output logic                    oPcRedirectEn,
  output logic [31:0]             oPcRedirectTarget,
  output logic                    oExMemValid,
  output logic                    oExMemIllegal,
  output logic                    oExMemRegWrite,
  output logic                    oExMemMemWrite,
  output logic [4:0]              oExMemRdAddr,
  output logic [31:0]             oExMemPc,
  output logic [31:0]             oExMemInstr,
  output logic [31:0]             oExMemAluResult,
  output logic [31:0]             oExMemStoreData,
  output logic [31:0]             oExMemWbDataNonMem,
  output rv32i_pkg::wb_sel_e      oExMemWbSel,
  output rv32i_pkg::load_type_e   oExMemLoadType,
  output rv32i_pkg::store_type_e  oExMemStoreType
);
  localparam logic [31:0] LP_NOP = 32'h00000013;

  logic [31:0] wExRs1Data;
  logic [31:0] wExRs2Data;
  logic [31:0] wExAluOperandA;
  logic [31:0] wExAluOperandB;
  logic [31:0] wExAluResult;
  logic [31:0] wExPcPlusImm;
  logic [31:0] wExStoreData;
  logic [31:0] wExWbDataNonMem;
  logic        wExEq;
  logic        wExLtSigned;
  logic        wExLtUnsigned;
  logic        wExBranchTaken;

  ForwardingUnit uForwardingUnit (
    .iExRs1Addr       (iIdExRs1Addr),
    .iExRs2Addr       (iIdExRs2Addr),
    .iMemRdAddr       (iExMemRdAddr),
    .iMemRegWrite     (iExMemRegWrite),
    .iMemForwardValid (iExMemValid && (iExMemWbSel != rv32i_pkg::WB_MEM)),
    .iWbRdAddr        (iMemWbRdAddr),
    .iWbRegWrite      (iMemWbRegWrite),
    .iWbValid         (iMemWbValid),
    .oForwardA        (oForwardA),
    .oForwardB        (oForwardB)
  );

  always_comb begin
    unique case (oForwardA)
      2'b10:   wExRs1Data = iExMemWbDataNonMem;
      2'b01:   wExRs1Data = iMemWbWrData;
      default: wExRs1Data = iIdExRs1Data;
    endcase
  end

  always_comb begin
    unique case (oForwardB)
      2'b10:   wExRs2Data = iExMemWbDataNonMem;
      2'b01:   wExRs2Data = iMemWbWrData;
      default: wExRs2Data = iIdExRs2Data;
    endcase
  end

  always_comb begin
    unique case (iIdExAluASel)
      rv32i_pkg::ALUA_PC:   wExAluOperandA = iIdExPc;
      rv32i_pkg::ALUA_ZERO: wExAluOperandA = 32'd0;
      default:              wExAluOperandA = wExRs1Data;
    endcase
  end

  assign wExAluOperandB = iIdExAluSrc ? iIdExImm : wExRs2Data;
  assign wExStoreData   = wExRs2Data;
  assign wExPcPlusImm   = iIdExPc + iIdExImm;
  assign wExEq          = (wExRs1Data == wExRs2Data);
  assign wExLtSigned    = ($signed(wExRs1Data) < $signed(wExRs2Data));
  assign wExLtUnsigned  = (wExRs1Data < wExRs2Data);

  Alu uExAlu (
    .iA      (wExAluOperandA),
    .iB      (wExAluOperandB),
    .iAluOp  (iIdExAluOp),
    .oResult (wExAluResult)
  );

  always_comb begin
    wExBranchTaken = 1'b0;

    unique case (iIdExBranchType)
      rv32i_pkg::BR_BEQ:  wExBranchTaken = wExEq;
      rv32i_pkg::BR_BNE:  wExBranchTaken = !wExEq;
      rv32i_pkg::BR_BLT:  wExBranchTaken = wExLtSigned;
      rv32i_pkg::BR_BGE:  wExBranchTaken = !wExLtSigned;
      rv32i_pkg::BR_BLTU: wExBranchTaken = wExLtUnsigned;
      rv32i_pkg::BR_BGEU: wExBranchTaken = !wExLtUnsigned;
      default:            wExBranchTaken = 1'b0;
    endcase
  end

  always_comb begin
    oPcRedirectEn     = 1'b0;
    oPcRedirectTarget = wExPcPlusImm;

    if (iIdExValid) begin
      unique case (iIdExJumpType)
        rv32i_pkg::JUMP_JAL: begin
          oPcRedirectEn     = 1'b1;
          oPcRedirectTarget = wExPcPlusImm;
        end
        rv32i_pkg::JUMP_JALR: begin
          oPcRedirectEn     = 1'b1;
          oPcRedirectTarget = {wExAluResult[31:1], 1'b0};
        end
        default: begin
          oPcRedirectEn     = wExBranchTaken;
          oPcRedirectTarget = wExPcPlusImm;
        end
      endcase
    end
  end

  always_comb begin
    unique case (iIdExWbSel)
      rv32i_pkg::WB_PC4: wExWbDataNonMem = iIdExPcPlus4;
      default:           wExWbDataNonMem = wExAluResult;
    endcase
  end

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      oExMemValid       <= 1'b0;
      oExMemIllegal     <= 1'b0;
      oExMemRegWrite    <= 1'b0;
      oExMemMemWrite    <= 1'b0;
      oExMemRdAddr      <= 5'd0;
      oExMemPc          <= 32'd0;
      oExMemInstr       <= LP_NOP;
      oExMemAluResult   <= 32'd0;
      oExMemStoreData   <= 32'd0;
      oExMemWbDataNonMem<= 32'd0;
      oExMemWbSel       <= rv32i_pkg::WB_ALU;
      oExMemLoadType    <= rv32i_pkg::LOAD_NONE;
      oExMemStoreType   <= rv32i_pkg::STORE_NONE;
    end else begin
      oExMemValid        <= iIdExValid;
      oExMemIllegal      <= iIdExIllegal;
      oExMemRegWrite     <= iIdExRegWrite;
      oExMemMemWrite     <= iIdExMemWrite;
      oExMemRdAddr       <= iIdExRdAddr;
      oExMemPc           <= iIdExPc;
      oExMemInstr        <= iIdExInstr;
      oExMemAluResult    <= wExAluResult;
      oExMemStoreData    <= wExStoreData;
      oExMemWbDataNonMem <= wExWbDataNonMem;
      oExMemWbSel        <= iIdExWbSel;
      oExMemLoadType     <= iIdExLoadType;
      oExMemStoreType    <= iIdExStoreType;
    end
  end

endmodule
