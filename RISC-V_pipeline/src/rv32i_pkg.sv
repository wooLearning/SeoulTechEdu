`timescale 1ns / 1ps

// Shared enums and opcode constants for the RV32I subset in this project.
package rv32i_pkg;
  typedef enum logic [1:0] {
    ALUA_RS1,
    ALUA_PC,
    ALUA_ZERO
  } alu_a_sel_e;

  // ALU operation select used by arithmetic, load/store address calc, and shifts.
  typedef enum logic [3:0] {
    ALU_ADD,
    ALU_SUB,
    ALU_SLL,
    ALU_SLT,
    ALU_SLTU,
    ALU_XOR,
    ALU_SRL,
    ALU_SRA,
    ALU_OR,
    ALU_AND
  } alu_op_e;

  typedef enum logic [1:0] {
    WB_ALU,
    WB_MEM,
    WB_PC4
  } wb_sel_e;

  typedef enum logic [2:0] {
    LOAD_NONE,
    LOAD_LB,
    LOAD_LH,
    LOAD_LW,
    LOAD_LBU,
    LOAD_LHU
  } load_type_e;

  typedef enum logic [1:0] {
    STORE_NONE,
    STORE_SB,
    STORE_SH,
    STORE_SW
  } store_type_e;

  typedef enum logic [2:0] {
    IMM_NONE,
    IMM_I,
    IMM_S,
    IMM_B,
    IMM_J,
    IMM_U
  } imm_sel_e;

  typedef enum logic [2:0] {
    BR_NONE,
    BR_BEQ,
    BR_BNE,
    BR_BLT,
    BR_BGE,
    BR_BLTU,
    BR_BGEU
  } branch_e;

  typedef enum logic [1:0] {
    JUMP_NONE,
    JUMP_JAL,
    JUMP_JALR
  } jump_e;

  // Opcode constants currently decoded by this core.
  // Note:
  // - These are opcode-group names, not full instruction-format categories.
  // - LP_OPCODE_OPIMM refers to OP-IMM (0010011) only.
  // - Other instructions that also use an I-type bit layout, such as LOAD,
  //   are decoded with their own opcode constants below.
  localparam logic [6:0] LP_OPCODE_RTYPE  = 7'b0110011;//r type
  localparam logic [6:0] LP_OPCODE_OPIMM  = 7'b0010011;//i type
  localparam logic [6:0] LP_OPCODE_AUIPC  = 7'b0010111;//u type
  localparam logic [6:0] LP_OPCODE_LOAD   = 7'b0000011;//i type
  localparam logic [6:0] LP_OPCODE_JALR   = 7'b1100111;//i type
  localparam logic [6:0] LP_OPCODE_STORE  = 7'b0100011;//s type
  localparam logic [6:0] LP_OPCODE_BRANCH = 7'b1100011;//b type
  localparam logic [6:0] LP_OPCODE_JAL    = 7'b1101111;//j type
  localparam logic [6:0] LP_OPCODE_LUI    = 7'b0110111;//u type
endpackage
