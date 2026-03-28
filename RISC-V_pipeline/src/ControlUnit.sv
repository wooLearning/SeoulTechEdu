`timescale 1ns / 1ps

// Decodes opcode/funct fields into datapath control signals.
module ControlUnit (
  input  logic                   iInstrValid,  // High when the current instruction should be decoded.
  input  logic [6:0]             iOpcode,      // Major opcode field from the instruction.
  input  logic [2:0]             iFunct3,      // Sub-opcode field used by ALU/load/store/branch decode.
  input  logic [6:0]             iFunct7,      // Extended sub-opcode used by R-type and shift-immediate decode.
  output logic                   oRegWrite,    // Enables write-back into rd.
  output logic                   oMemWrite,    // Enables store into data memory.
  output logic                   oAluSrc,      // Selects ALU operand B: rs2(0) or immediate(1).
  output rv32i_pkg::alu_a_sel_e  oAluASel,     // Selects ALU operand A: rs1, PC, or zero.
  output rv32i_pkg::wb_sel_e     oWbSel,       // Selects write-back source.
  output rv32i_pkg::alu_op_e     oAluOp,       // Selects ALU operation.
  output rv32i_pkg::load_type_e  oLoadType,    // Selects load width/sign mode in DataRam.
  output rv32i_pkg::store_type_e oStoreType,   // Selects store width in DataRam.
  output rv32i_pkg::imm_sel_e    oImmSel,      // Selects immediate format in ImmGen.
  output rv32i_pkg::branch_e     oBranchType,  // Selects branch compare mode in Datapath.
  output rv32i_pkg::jump_e       oJumpType,    // Selects unconditional PC redirect mode in Datapath.
  output logic                   oIllegal      // High when the instruction is unsupported or malformed.
);

  // Internal "this case matched a supported instruction" flag.
  // Outputs are initialized to safe defaults first, then this flag is used
  // to decide whether writes/branches should be enabled or blocked.
  logic wDecodeValid;

  always_comb begin
    // Safe defaults prevent illegal instructions from updating architectural state.
    oRegWrite   = 1'b0;
    oMemWrite   = 1'b0;
    oAluSrc     = 1'b0;
    oAluASel    = rv32i_pkg::ALUA_RS1;
    oWbSel      = rv32i_pkg::WB_ALU;
    oAluOp      = rv32i_pkg::ALU_ADD;
    oLoadType   = rv32i_pkg::LOAD_NONE;
    oStoreType  = rv32i_pkg::STORE_NONE;
    oImmSel     = rv32i_pkg::IMM_NONE;
    oBranchType = rv32i_pkg::BR_NONE;
    oJumpType   = rv32i_pkg::JUMP_NONE;
    oIllegal    = 1'b1;
    wDecodeValid = 1'b0;

    if (iInstrValid) begin
      unique case (iOpcode)
        rv32i_pkg::LP_OPCODE_RTYPE: begin
          // R-type is distinguished by the funct7/funct3 combination.
          unique case ({iFunct7, iFunct3})
            10'b0000000_000: begin oAluOp = rv32i_pkg::ALU_ADD;  wDecodeValid = 1'b1; end
            10'b0100000_000: begin oAluOp = rv32i_pkg::ALU_SUB;  wDecodeValid = 1'b1; end
            10'b0000000_001: begin oAluOp = rv32i_pkg::ALU_SLL;  wDecodeValid = 1'b1; end
            10'b0000000_010: begin oAluOp = rv32i_pkg::ALU_SLT;  wDecodeValid = 1'b1; end
            10'b0000000_011: begin oAluOp = rv32i_pkg::ALU_SLTU; wDecodeValid = 1'b1; end
            10'b0000000_100: begin oAluOp = rv32i_pkg::ALU_XOR;  wDecodeValid = 1'b1; end
            10'b0000000_101: begin oAluOp = rv32i_pkg::ALU_SRL;  wDecodeValid = 1'b1; end
            10'b0100000_101: begin oAluOp = rv32i_pkg::ALU_SRA;  wDecodeValid = 1'b1; end
            10'b0000000_110: begin oAluOp = rv32i_pkg::ALU_OR;   wDecodeValid = 1'b1; end
            10'b0000000_111: begin oAluOp = rv32i_pkg::ALU_AND;  wDecodeValid = 1'b1; end
            default: begin end
          endcase

          oRegWrite = wDecodeValid;
          oIllegal  = !wDecodeValid;

        end

        rv32i_pkg::LP_OPCODE_OPIMM: begin
          // OP-IMM arithmetic instructions reuse the ALU write-back path.
          oAluSrc   = 1'b1;
          oWbSel    = rv32i_pkg::WB_ALU;
          oImmSel   = rv32i_pkg::IMM_I;

          unique case (iFunct3)
            3'b000: begin oAluOp = rv32i_pkg::ALU_ADD;  wDecodeValid = 1'b1; end
            3'b010: begin oAluOp = rv32i_pkg::ALU_SLT;  wDecodeValid = 1'b1; end
            3'b011: begin oAluOp = rv32i_pkg::ALU_SLTU; wDecodeValid = 1'b1; end
            3'b100: begin oAluOp = rv32i_pkg::ALU_XOR;  wDecodeValid = 1'b1; end
            3'b110: begin oAluOp = rv32i_pkg::ALU_OR;   wDecodeValid = 1'b1; end
            3'b111: begin oAluOp = rv32i_pkg::ALU_AND;  wDecodeValid = 1'b1; end
            3'b001: begin
              if (iFunct7 == 7'b0000000) begin
                oAluOp = rv32i_pkg::ALU_SLL;
                wDecodeValid = 1'b1;
              end
            end
            3'b101: begin
              if (iFunct7 == 7'b0000000) begin
                oAluOp = rv32i_pkg::ALU_SRL;
                wDecodeValid = 1'b1;
              end else if (iFunct7 == 7'b0100000) begin
                oAluOp = rv32i_pkg::ALU_SRA;
                wDecodeValid = 1'b1;
              end
            end
            default: begin end
          endcase

          oRegWrite = wDecodeValid;
          oIllegal  = !wDecodeValid;
          
        end

        rv32i_pkg::LP_OPCODE_AUIPC: begin
          // AUIPC is handled as ALU(PC + IMM_U) to keep write-back muxing shallow.
          oAluSrc      = 1'b1;
          oAluASel     = rv32i_pkg::ALUA_PC;
          oWbSel       = rv32i_pkg::WB_ALU;
          oAluOp       = rv32i_pkg::ALU_ADD;
          oImmSel      = rv32i_pkg::IMM_U;
          wDecodeValid = 1'b1;

          oRegWrite = 1'b1;
          oIllegal  = 1'b0;
        end

        rv32i_pkg::LP_OPCODE_LOAD: begin
          // Load address = rs1 + imm, then DataRam chooses lb/lh/lw/lbu/lhu.
          oAluSrc   = 1'b1;
          oWbSel    = rv32i_pkg::WB_MEM;
          oAluOp    = rv32i_pkg::ALU_ADD;
          oImmSel   = rv32i_pkg::IMM_I;

          unique case (iFunct3)
            3'b000: begin oLoadType = rv32i_pkg::LOAD_LB;  wDecodeValid = 1'b1; end
            3'b001: begin oLoadType = rv32i_pkg::LOAD_LH;  wDecodeValid = 1'b1; end
            3'b010: begin oLoadType = rv32i_pkg::LOAD_LW;  wDecodeValid = 1'b1; end
            3'b100: begin oLoadType = rv32i_pkg::LOAD_LBU; wDecodeValid = 1'b1; end
            3'b101: begin oLoadType = rv32i_pkg::LOAD_LHU; wDecodeValid = 1'b1; end
            default: begin end
          endcase

          oRegWrite = wDecodeValid;
          oIllegal  = !wDecodeValid;
        end

        rv32i_pkg::LP_OPCODE_JALR: begin
          // JALR writes rd with PC+4 and redirects to (rs1 + imm) with bit 0 cleared.
          oAluSrc   = 1'b1;
          oWbSel    = rv32i_pkg::WB_PC4;
          oAluOp    = rv32i_pkg::ALU_ADD;
          oImmSel   = rv32i_pkg::IMM_I;

          if (iFunct3 == 3'b000) begin
            oJumpType   = rv32i_pkg::JUMP_JALR;
            wDecodeValid = 1'b1;
          end

          oRegWrite = wDecodeValid;
          oIllegal  = !wDecodeValid;
        end

        rv32i_pkg::LP_OPCODE_STORE: begin
          // Store address = rs1 + imm, then DataRam chooses sb/sh/sw.
          oAluSrc   = 1'b1;
          oAluOp    = rv32i_pkg::ALU_ADD;
          oImmSel   = rv32i_pkg::IMM_S;

          unique case (iFunct3)
            3'b000: begin oStoreType = rv32i_pkg::STORE_SB; wDecodeValid = 1'b1; end
            3'b001: begin oStoreType = rv32i_pkg::STORE_SH; wDecodeValid = 1'b1; end
            3'b010: begin oStoreType = rv32i_pkg::STORE_SW; wDecodeValid = 1'b1; end
            default: begin end
          endcase

          oMemWrite = wDecodeValid;
          oIllegal  = !wDecodeValid;
        end

        rv32i_pkg::LP_OPCODE_BRANCH: begin
          // Branches use rs1/rs2 compare results inside the datapath.
          oImmSel = rv32i_pkg::IMM_B;

          unique case (iFunct3)
            3'b000: begin oBranchType = rv32i_pkg::BR_BEQ;  wDecodeValid = 1'b1; end
            3'b001: begin oBranchType = rv32i_pkg::BR_BNE;  wDecodeValid = 1'b1; end
            3'b100: begin oBranchType = rv32i_pkg::BR_BLT;  wDecodeValid = 1'b1; end
            3'b101: begin oBranchType = rv32i_pkg::BR_BGE;  wDecodeValid = 1'b1; end
            3'b110: begin oBranchType = rv32i_pkg::BR_BLTU; wDecodeValid = 1'b1; end
            3'b111: begin oBranchType = rv32i_pkg::BR_BGEU; wDecodeValid = 1'b1; end
            default: begin end
          endcase

          oIllegal = !wDecodeValid;
        end

        rv32i_pkg::LP_OPCODE_JAL: begin
          // JAL writes rd with PC+4 and redirects to PC + imm.
          oWbSel      = rv32i_pkg::WB_PC4;
          oImmSel     = rv32i_pkg::IMM_J;
          oJumpType   = rv32i_pkg::JUMP_JAL;
          wDecodeValid = 1'b1;

          oRegWrite = 1'b1;
          oIllegal  = 1'b0;
        end

        rv32i_pkg::LP_OPCODE_LUI: begin
          // LUI is handled as ALU(0 + IMM_U) to keep write-back muxing shallow.
          oAluSrc      = 1'b1;
          oAluASel     = rv32i_pkg::ALUA_ZERO;
          oWbSel       = rv32i_pkg::WB_ALU;
          oAluOp       = rv32i_pkg::ALU_ADD;
          oImmSel      = rv32i_pkg::IMM_U;
          wDecodeValid = 1'b1;

          oRegWrite = 1'b1;
          oIllegal  = 1'b0;
        end

        default: begin
          oIllegal = 1'b1;
        end
      endcase
    end
  end

endmodule
