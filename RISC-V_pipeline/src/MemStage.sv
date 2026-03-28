`timescale 1ns / 1ps

/*
[MODULE_INFO_START]
Name: MemStage
Role: RTL module implementing pipeline memory access and MEM/WB register
Summary:
  - Owns the data RAM access and final memory/non-memory write-back selection
  - Captures the MEM/WB packet used for architectural commit
StateDescription:
  - MEM/WB register: final write-back packet for register commit
[MODULE_INFO_END]
*/
module MemStage (
  input  logic                    iClk,
  input  logic                    iRstn,
  input  logic                    iExMemValid,
  input  logic                    iExMemIllegal,
  input  logic                    iExMemRegWrite,
  input  logic                    iExMemMemWrite,
  input  logic [4:0]              iExMemRdAddr,
  input  logic [31:0]             iExMemPc,
  input  logic [31:0]             iExMemInstr,
  input  logic [31:0]             iExMemAluResult,
  input  logic [31:0]             iExMemStoreData,
  input  logic [31:0]             iExMemWbDataNonMem,
  input  rv32i_pkg::wb_sel_e      iExMemWbSel,
  input  rv32i_pkg::load_type_e   iExMemLoadType,
  input  rv32i_pkg::store_type_e  iExMemStoreType,
  output logic                    oMemWbValid,
  output logic                    oMemWbIllegal,
  output logic                    oMemWbRegWrite,
  output logic [4:0]              oMemWbRdAddr,
  output logic [31:0]             oMemWbPc,
  output logic [31:0]             oMemWbInstr,
  output logic [31:0]             oMemWbWrData,
  output logic                    oMemWbMemWrite,
  output logic [31:0]             oMemWbMemAddr,
  output logic [31:0]             oMemWbMemData
);
  localparam logic [31:0] LP_NOP = 32'h00000013;

  logic [31:0] wDataRamRdData;
  logic [31:0] wMemStageWbData;

  DataRam uDataRam (
    .iClk       (iClk),
    .iWrEn      (iExMemValid && iExMemMemWrite),
    .iAddr      (iExMemAluResult),
    .iWrData    (iExMemStoreData),
    .iLoadType  (iExMemValid ? iExMemLoadType : rv32i_pkg::LOAD_NONE),
    .iStoreType (iExMemStoreType),
    .oRdData    (wDataRamRdData)
  );

  assign wMemStageWbData =
    (iExMemWbSel == rv32i_pkg::WB_MEM) ? wDataRamRdData : iExMemWbDataNonMem;

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      oMemWbValid    <= 1'b0;
      oMemWbIllegal  <= 1'b0;
      oMemWbRegWrite <= 1'b0;
      oMemWbRdAddr   <= 5'd0;
      oMemWbPc       <= 32'd0;
      oMemWbInstr    <= LP_NOP;
      oMemWbWrData   <= 32'd0;
      oMemWbMemWrite <= 1'b0;
      oMemWbMemAddr  <= 32'd0;
      oMemWbMemData  <= 32'd0;
    end else begin
      oMemWbValid    <= iExMemValid;
      oMemWbIllegal  <= iExMemIllegal;
      oMemWbRegWrite <= iExMemRegWrite;
      oMemWbRdAddr   <= iExMemRdAddr;
      oMemWbPc       <= iExMemPc;
      oMemWbInstr    <= iExMemInstr;
      oMemWbWrData   <= wMemStageWbData;
      oMemWbMemWrite <= iExMemValid && iExMemMemWrite;
      oMemWbMemAddr  <= iExMemAluResult;
      oMemWbMemData  <= iExMemStoreData;
    end
  end

endmodule
