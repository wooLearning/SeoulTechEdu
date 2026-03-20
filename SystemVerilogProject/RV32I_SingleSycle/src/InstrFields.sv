`timescale 1ns / 1ps

// Splits a 32-bit instruction into the fields used by control and datapath.
module InstrFields (
  input  logic [31:0] iInstr,
  output logic [6:0]  oOpcode,
  output logic [2:0]  oFunct3,
  output logic [6:0]  oFunct7,
  output logic [4:0]  oRs1,
  output logic [4:0]  oRs2,
  output logic [4:0]  oRd
);

  // Bit slices follow the RV32I base encoding.
  assign oOpcode = iInstr[6:0];
  assign oRd     = iInstr[11:7];
  assign oFunct3 = iInstr[14:12];
  assign oRs1    = iInstr[19:15];
  assign oRs2    = iInstr[24:20];
  assign oFunct7 = iInstr[31:25];

endmodule
