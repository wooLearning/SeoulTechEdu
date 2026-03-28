`timescale 1ns / 1ps

/*
[MODULE_INFO_START]
Name: instr_mem_paths_pkg
Role: Shared package for absolute instruction-memory image paths
Summary:
  - Keeps the four active ROM-image absolute paths in one place
  - Lets Top/FetchStage and all testbenches share the same path constants
  - Makes swapping default/bubble/hazard/test2 images a one-line change
StateDescription:
  - LP_INSTR_MEM_DEFAULT: default regression image
  - LP_INSTR_MEM_BUBBLE: bubble-sort image
  - LP_INSTR_MEM_HAZARD: mixed hazard image
  - LP_INSTR_MEM_TEST2: timing/test2 image
[MODULE_INFO_END]
*/
package instr_mem_paths_pkg;
`ifdef VERILATOR
  localparam string LP_PROJECT_ROOT = "/mnt/d/02_learning_lab/RV32I_PIPELINE_ONLY/FPGA_Auto_Project/Project/rv32i";
`else
  localparam string LP_PROJECT_ROOT = "D:/02_learning_lab/RV32I_PIPELINE_ONLY/FPGA_Auto_Project/Project/rv32i";
`endif

  // Change these four constants if the program image locations ever move.
  localparam string LP_INSTR_MEM_DEFAULT = {LP_PROJECT_ROOT, "/src/mem/InstructionDefault.mem"};
  localparam string LP_INSTR_MEM_BUBBLE  = {LP_PROJECT_ROOT, "/src/mem/InstructionBubble.mem"};
  localparam string LP_INSTR_MEM_HAZARD  = {LP_PROJECT_ROOT, "/src/mem/InstructionHazard.mem"};
  localparam string LP_INSTR_MEM_TEST2   = {LP_PROJECT_ROOT, "/src/mem/InstructionFORTIMING.mem"};
  localparam string LP_INSTR_MEM_SPIKE_TOP = {LP_PROJECT_ROOT, "/src/mem/InstructionSpikeTop.mem"};
endpackage
