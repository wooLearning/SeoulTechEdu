`timescale 1ns / 1ps

/*
[MODULE_INFO_START]
Name: FetchStage
Role: RTL module implementing the pipeline fetch stage and IF/ID register
Summary:
  - Owns the PC, instruction ROM selection, and IF/ID pipeline packet
  - Applies redirect flushes and load-use stall gating at the fetch boundary
StateDescription:
  - IF/ID register: valid, PC, PC+4, instruction
[MODULE_INFO_END]
*/
module FetchStage #(
  parameter bit P_USE_BUBBLE_ROM = 1'b0,
  parameter bit P_USE_HAZARD_ROM = 1'b0,
  parameter bit P_USE_TEST2_ROM  = 1'b0,
  parameter logic [31:0] P_RESET_PC = 32'd0,
  parameter logic [31:0] P_INSTR_BASE_ADDR = 32'd0,
  parameter string P_INSTR_MEM_FILE = ""
) (
  input  logic        iClk,
  input  logic        iRstn,
  input  logic        iStall,
  input  logic        iRedirectEn,
  input  logic [31:0] iRedirectTarget,
  output logic [31:0] oDbgPc,
  output logic        oIfIdValid,
  output logic [31:0] oIfIdPc,
  output logic [31:0] oIfIdPcPlus4,
  output logic [31:0] oIfIdInstr
);

  import instr_mem_paths_pkg::*;

  localparam logic [31:0] LP_NOP = 32'h00000013;
  localparam string LP_INIT_FILE = (P_INSTR_MEM_FILE != "") ? P_INSTR_MEM_FILE :
                                   P_USE_HAZARD_ROM         ? LP_INSTR_MEM_HAZARD :
                                   P_USE_BUBBLE_ROM         ? LP_INSTR_MEM_BUBBLE :
                                   P_USE_TEST2_ROM          ? LP_INSTR_MEM_TEST2  :
                                                               LP_INSTR_MEM_DEFAULT;

  logic [31:0] wPc;
  logic [31:0] wPcPlus4;
  logic [31:0] wInstr;
  logic        wPcWriteEn;

  assign oDbgPc    = wPc;
  assign wPcWriteEn = !iStall;

  Pc #(
    .P_RESET_PC (P_RESET_PC)
  ) uPc (
    .iClk        (iClk),
    .iRstn       (iRstn),
    .iPcWe       (wPcWriteEn),
    .iPcTargetEn (iRedirectEn),
    .iPcTarget   (iRedirectTarget),
    .oPc         (wPc),
    .oPcPlus4    (wPcPlus4)
  );

  InstrRom #(
    .P_DEPTH     (128),
    .P_BASE_ADDR (P_INSTR_BASE_ADDR),
    .P_INIT_FILE (LP_INIT_FILE)
  ) uInstrRom (
    .iAddr  (wPc),
    .oInstr (wInstr)
  );

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      oIfIdValid   <= 1'b0;
      oIfIdPc      <= 32'd0;
      oIfIdPcPlus4 <= 32'd0;
      oIfIdInstr   <= LP_NOP;
    end else if (iRedirectEn) begin
      oIfIdValid   <= 1'b0;
      oIfIdPc      <= 32'd0;
      oIfIdPcPlus4 <= 32'd0;
      oIfIdInstr   <= LP_NOP;
    end else if (!iStall) begin
      oIfIdValid   <= 1'b1;
      oIfIdPc      <= wPc;
      oIfIdPcPlus4 <= wPcPlus4;
      oIfIdInstr   <= wInstr;
    end
  end

endmodule
