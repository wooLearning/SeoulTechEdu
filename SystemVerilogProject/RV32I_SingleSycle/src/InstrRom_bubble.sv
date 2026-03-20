`timescale 1ns / 1ps

// Alternate instruction ROM that runs the bubble-sort program.
module InstrRom_bubble #(
  parameter integer P_ADDR_WIDTH = 8,
  parameter integer P_DATA_WIDTH = 32
) (
  input  logic [31:0]             iAddr,
  output logic [P_DATA_WIDTH-1:0] oInstr
);

  localparam integer LP_DEPTH = 32;
  localparam integer LP_WORD_ADDR_WIDTH = (P_ADDR_WIDTH < 5) ? P_ADDR_WIDTH : 5;

  wire [31:0] wMem[0:LP_DEPTH-1];
  wire [LP_WORD_ADDR_WIDTH-1:0] wWordAddr;
  wire [31:0]                  wWordAddrExt;
  wire                         wAddrInRange;

  // ROM is indexed by word address because the core fetches 32-bit instructions.
  assign wWordAddr   = iAddr[LP_WORD_ADDR_WIDTH+1:2];
  assign wWordAddrExt = {{(32-LP_WORD_ADDR_WIDTH){1'b0}}, wWordAddr};
  assign wAddrInRange = (iAddr[31:LP_WORD_ADDR_WIDTH+2] == '0) && (wWordAddrExt < LP_DEPTH);

  assign wMem[0]  = 32'h04000093; // addi x1, x0, 64
  assign wMem[1]  = 32'h00400113; // addi x2, x0, 4
  assign wMem[2]  = 32'h02010663; // beq x2, x0, done
  assign wMem[3]  = 32'h00008193; // addi x3, x1, 0
  assign wMem[4]  = 32'h00010213; // addi x4, x2, 0
  assign wMem[5]  = 32'h0001A283; // lw x5, 0(x3)
  assign wMem[6]  = 32'h0041A303; // lw x6, 4(x3)
  assign wMem[7]  = 32'h02534063; // blt x6, x5, do_swap
  assign wMem[8]  = 32'h00418193; // addi x3, x3, 4
  assign wMem[9]  = 32'hFFF20213; // addi x4, x4, -1
  assign wMem[10] = 32'hFE0216E3; // bne x4, x0, inner_loop
  assign wMem[11] = 32'hFFF10113; // addi x2, x2, -1
  assign wMem[12] = 32'hFC011EE3; // bne x2, x0, outer_loop
  assign wMem[13] = 32'h00100F93; // addi x31, x0, 1
  assign wMem[14] = 32'hFE000EE3; // beq x0, x0, done
  assign wMem[15] = 32'h0061A023; // sw x6, 0(x3)
  assign wMem[16] = 32'h0051A223; // sw x5, 4(x3)
  assign wMem[17] = 32'hFC000EE3; // beq x0, x0, after_swap
  assign wMem[18] = 32'h00000013;
  assign wMem[19] = 32'h00000013;
  assign wMem[20] = 32'h00000013;
  assign wMem[21] = 32'h00000013;
  assign wMem[22] = 32'h00000013;
  assign wMem[23] = 32'h00000013;
  assign wMem[24] = 32'h00000013;
  assign wMem[25] = 32'h00000013;
  assign wMem[26] = 32'h00000013;
  assign wMem[27] = 32'h00000013;
  assign wMem[28] = 32'h00000013;
  assign wMem[29] = 32'h00000013;
  assign wMem[30] = 32'h00000013;
  assign wMem[31] = 32'h00000013;

  // Unused or out-of-range slots fall back to nop.
  assign oInstr = wAddrInRange ? wMem[wWordAddr] : 32'h00000013;

endmodule
