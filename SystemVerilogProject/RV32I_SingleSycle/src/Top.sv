`timescale 1ns / 1ps

// Single-cycle top level tying together PC, ROM, control, datapath, and data RAM.
module Top #(
  parameter bit P_USE_BUBBLE_ROM = 1'b0
) (
  input logic iClk,
  input logic iRstn
);

  // Top-level point-to-point wiring follows:
  // w[SrcInstance]2[DstInstance]_[Signal]
  // Use Top as destination only when Top itself computes/uses the signal or
  // when the signal fans out to multiple consumers.

  // PC path
  logic [31:0] wPc2Top_Pc;
  logic [31:0] wPc2Datapath_PcPlus4;

  // Fetch/decode path
  logic [31:0] wInstrRom2Top_Instr;
  logic [6:0]  wInstrFields2ControlUnit_Opcode;
  logic [2:0]  wInstrFields2ControlUnit_Funct3;
  logic [6:0]  wInstrFields2ControlUnit_Funct7;
  logic [4:0]  wInstrFields2Datapath_Rs1Addr;
  logic [4:0]  wInstrFields2Datapath_Rs2Addr;
  logic [4:0]  wInstrFields2Datapath_RdAddr;

  // Datapath <-> Top / Data RAM path
  logic [31:0] wDatapath2DataRam_AluResult;
  logic [31:0] wDataRam2Datapath_RdData;
  logic [31:0] wDatapath2DataRam_Rs2Data;
  logic [31:0] wDatapath2Pc_PcTarget;
  logic [31:0] wDatapath2Top_RdWrData;

  // Control outputs delivered to datapath or data RAM
  logic        wControlUnit2Datapath_RegWrite;
  logic        wControlUnit2DataRam_MemWrite;
  logic        wControlUnit2Datapath_AluSrc;
  logic        wDatapath2Pc_PcTargetEn;
  logic        wControlUnit2Top_Illegal;
  rv32i_pkg::wb_sel_e     wControlUnit2Datapath_WbSel;
  rv32i_pkg::alu_op_e     wControlUnit2Datapath_AluOp;
  rv32i_pkg::load_type_e  wControlUnit2DataRam_LoadType;
  rv32i_pkg::store_type_e wControlUnit2DataRam_StoreType;
  rv32i_pkg::imm_sel_e    wControlUnit2Datapath_ImmSel;
  rv32i_pkg::branch_e     wControlUnit2Datapath_BranchType;
  rv32i_pkg::jump_e       wControlUnit2Datapath_JumpType;

  Pc uPc (
    .iClk         (iClk),
    .iRstn        (iRstn),
    .iPcWe        (1'b1),
    .iPcTargetEn  (wDatapath2Pc_PcTargetEn),
    .iPcTarget    (wDatapath2Pc_PcTarget),
    .oPc          (wPc2Top_Pc),
    .oPcPlus4     (wPc2Datapath_PcPlus4)
  );

  // To run the bubble-sort scenario, instantiate Top with
  // P_USE_BUBBLE_ROM=1 so src/InstrRom_bubble.sv is selected.
  generate
    if (P_USE_BUBBLE_ROM) begin : genBubbleRom
      InstrRom_bubble uInstrRom (
        .iAddr  (wPc2Top_Pc),
        .oInstr (wInstrRom2Top_Instr)
      );
    end else begin : genDefaultRom
      InstrRom uInstrRom (
        .iAddr  (wPc2Top_Pc),
        .oInstr (wInstrRom2Top_Instr)
      );
    end
  endgenerate

  InstrFields uInstrFields (
    .iInstr  (wInstrRom2Top_Instr),
    .oOpcode (wInstrFields2ControlUnit_Opcode),
    .oFunct3 (wInstrFields2ControlUnit_Funct3),
    .oFunct7 (wInstrFields2ControlUnit_Funct7),
    .oRs1    (wInstrFields2Datapath_Rs1Addr),
    .oRs2    (wInstrFields2Datapath_Rs2Addr),
    .oRd     (wInstrFields2Datapath_RdAddr)
  );

  // Control consumes only decode fields.
  // Register indices are extracted once in Top and forwarded to datapath.
  ControlUnit uControlUnit (
    .iInstrValid (1'b1),
    .iOpcode     (wInstrFields2ControlUnit_Opcode),
    .iFunct3     (wInstrFields2ControlUnit_Funct3),
    .iFunct7     (wInstrFields2ControlUnit_Funct7),
    
    .oRegWrite   (wControlUnit2Datapath_RegWrite),
    .oAluSrc     (wControlUnit2Datapath_AluSrc),
    .oWbSel      (wControlUnit2Datapath_WbSel),
    .oAluOp      (wControlUnit2Datapath_AluOp),
    .oImmSel     (wControlUnit2Datapath_ImmSel),
    .oBranchType (wControlUnit2Datapath_BranchType),
    .oJumpType   (wControlUnit2Datapath_JumpType),

    .oLoadType   (wControlUnit2DataRam_LoadType),
    .oStoreType  (wControlUnit2DataRam_StoreType),
    .oMemWrite   (wControlUnit2DataRam_MemWrite),
    
    .oIllegal    (wControlUnit2Top_Illegal)
  );

  // Datapath handles register reads/writes, immediate generation, ALU execution,
  // write-back selection, and branch comparison.
  Datapath uDatapath (
    .iClk         (iClk),
    .iRstn        (iRstn),
    .iPc          (wPc2Top_Pc),
    .iPcPlus4     (wPc2Datapath_PcPlus4),
    .iInstr       (wInstrRom2Top_Instr),
    .iRs1Addr     (wInstrFields2Datapath_Rs1Addr),
    .iRs2Addr     (wInstrFields2Datapath_Rs2Addr),
    .iRdAddr      (wInstrFields2Datapath_RdAddr),
    .iRegWrite    (wControlUnit2Datapath_RegWrite),
    .iAluSrc      (wControlUnit2Datapath_AluSrc),
    .iWbSel       (wControlUnit2Datapath_WbSel),
    .iAluOp       (wControlUnit2Datapath_AluOp),
    .iImmSel      (wControlUnit2Datapath_ImmSel),
    .iBranchType  (wControlUnit2Datapath_BranchType),
    .iJumpType    (wControlUnit2Datapath_JumpType),
    .iMemRdData   (wDataRam2Datapath_RdData),
    .oAluResult   (wDatapath2DataRam_AluResult),
    .oRs2Data     (wDatapath2DataRam_Rs2Data),
    .oRdWrData    (wDatapath2Top_RdWrData),
    .oPcTargetEn  (wDatapath2Pc_PcTargetEn),
    .oPcTarget    (wDatapath2Pc_PcTarget)
  );

  // ALU result is a byte address; DataRam internally maps it to a word array
  // and selects byte/halfword lanes for load/store sub-word accesses.
  DataRam uDataRam (
    .iClk       (iClk),
    .iWrEn      (wControlUnit2DataRam_MemWrite),
    .iAddr      (wDatapath2DataRam_AluResult),
    .iWrData    (wDatapath2DataRam_Rs2Data),
    .iLoadType  (wControlUnit2DataRam_LoadType),
    .iStoreType (wControlUnit2DataRam_StoreType),
    .oRdData    (wDataRam2Datapath_RdData)
  );

endmodule
