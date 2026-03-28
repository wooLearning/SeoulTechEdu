`timescale 1ns / 1ps

/*
[MODULE_INFO_START]
Name: WbStage
Role: RTL module implementing final write-back commit selection
Summary:
  - Turns the MEM/WB packet into the regfile write enable/address/data triplet
  - Keeps architectural commit gating isolated from the memory stage register
StateDescription:
  - Combinational only: no internal state
[MODULE_INFO_END]
*/
module WbStage (
  input  logic        iMemWbValid,
  input  logic        iMemWbRegWrite,
  input  logic [4:0]  iMemWbRdAddr,
  input  logic [31:0] iMemWbWrData,
  output logic        oRegfileWrEn,
  output logic [4:0]  oRegfileRdAddr,
  output logic [31:0] oRegfileWrData
);

  assign oRegfileWrEn   = iMemWbValid && iMemWbRegWrite;
  assign oRegfileRdAddr = iMemWbRdAddr;
  assign oRegfileWrData = iMemWbWrData;

endmodule
