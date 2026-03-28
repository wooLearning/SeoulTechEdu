`timescale 1ns / 1ps

// Builds sign-extended immediates for the supported instruction formats.
module ImmGen (
  input  logic [31:0]             iInstr,
  input  rv32i_pkg::imm_sel_e     iImmSel,
  output logic [31:0]             oImm
);

  logic [31:0] wImmI;
  logic [31:0] wImmS;
  logic [31:0] wImmB;
  logic [31:0] wImmJ;
  logic [31:0] wImmU;

  // B/J-type immediates include the low zero bit used by aligned control-flow targets.
  assign wImmI = {{20{iInstr[31]}}, iInstr[31:20]};
  assign wImmS = {{20{iInstr[31]}}, iInstr[31:25], iInstr[11:7]};
  assign wImmB = {{19{iInstr[31]}}, iInstr[31], iInstr[7], iInstr[30:25], iInstr[11:8], 1'b0};
  assign wImmJ = {{11{iInstr[31]}}, iInstr[31], iInstr[19:12], iInstr[20], iInstr[30:21], 1'b0};
  assign wImmU = {iInstr[31:12], 12'd0};

  always_comb begin
    oImm = 32'd0;

    unique case (iImmSel)
      rv32i_pkg::IMM_I: oImm = wImmI;
      rv32i_pkg::IMM_S: oImm = wImmS;
      rv32i_pkg::IMM_B: oImm = wImmB;
      rv32i_pkg::IMM_J: oImm = wImmJ;
      rv32i_pkg::IMM_U: oImm = wImmU;
      default: oImm = 32'd0;
    endcase
  end

endmodule
