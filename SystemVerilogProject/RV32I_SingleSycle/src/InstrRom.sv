`timescale 1ns / 1ps

// Default instruction ROM used by the regression/self-check program.
module InstrRom #(
  parameter integer P_ADDR_WIDTH = 8,
  parameter integer P_DATA_WIDTH = 32
) (
  input  logic [31:0]             iAddr,
  output logic [P_DATA_WIDTH-1:0] oInstr
);

  localparam integer LP_DEPTH = 84;
  localparam integer LP_WORD_ADDR_WIDTH = (P_ADDR_WIDTH < 7) ? P_ADDR_WIDTH : 7;

  wire [31:0] wMem[0:LP_DEPTH-1];
  wire [LP_WORD_ADDR_WIDTH-1:0] wWordAddr;
  wire [31:0]                  wWordAddrExt;
  wire                         wAddrInRange;

  // ROM is indexed by word address because the core fetches 32-bit instructions.
  assign wWordAddr   = iAddr[LP_WORD_ADDR_WIDTH+1:2];
  assign wWordAddrExt = {{(32-LP_WORD_ADDR_WIDTH){1'b0}}, wWordAddr};
  assign wAddrInRange = (iAddr[31:LP_WORD_ADDR_WIDTH+2] == '0) && (wWordAddrExt < LP_DEPTH);

  assign wMem[0]  = 32'h00F00093; // addi x1, x0, 15
  assign wMem[1]  = 32'h00300113; // addi x2, x0, 3
  assign wMem[2]  = 32'hFF000193; // addi x3, x0, -16
  assign wMem[3]  = 32'h00208233; // add x4, x1, x2
  assign wMem[4]  = 32'h402082B3; // sub x5, x1, x2
  assign wMem[5]  = 32'h00209333; // sll x6, x1, x2
  assign wMem[6]  = 32'h0011A3B3; // slt x7, x3, x1
  assign wMem[7]  = 32'h0011B433; // sltu x8, x3, x1
  assign wMem[8]  = 32'h0020C4B3; // xor x9, x1, x2
  assign wMem[9]  = 32'h0020D533; // srl x10, x1, x2
  assign wMem[10] = 32'h4021D5B3; // sra x11, x3, x2
  assign wMem[11] = 32'h0020E633; // or x12, x1, x2
  assign wMem[12] = 32'h0020F6B3; // and x13, x1, x2
  assign wMem[13] = 32'h00508713; // addi x14, x1, 5
  assign wMem[14] = 32'h0001A793; // slti x15, x3, 0
  assign wMem[15] = 32'h0011B813; // sltiu x16, x3, 1
  assign wMem[16] = 32'h0030C893; // xori x17, x1, 3
  assign wMem[17] = 32'h0020E913; // ori x18, x1, 2
  assign wMem[18] = 32'h0070F993; // andi x19, x1, 7
  assign wMem[19] = 32'h00411A13; // slli x20, x2, 4
  assign wMem[20] = 32'h0010DA93; // srli x21, x1, 1
  assign wMem[21] = 32'h4021DB13; // srai x22, x3, 2
  assign wMem[22] = 32'h04000B93; // addi x23, x0, 64
  assign wMem[23] = 32'h00EBA023; // sw x14, 0(x23)
  assign wMem[24] = 32'h000BAC03; // lw x24, 0(x23)
  assign wMem[25] = 32'h00000C93; // addi x25, x0, 0
  assign wMem[26] = 32'h00000D13; // addi x26, x0, 0
  assign wMem[27] = 32'h00208463; // beq x1, x2, +8
  assign wMem[28] = 32'h001C8C93; // addi x25, x25, 1
  assign wMem[29] = 32'h00108463; // beq x1, x1, +8
  assign wMem[30] = 32'h063D0D13; // addi x26, x26, 99
  assign wMem[31] = 32'h001D0D13; // addi x26, x26, 1
  assign wMem[32] = 32'h00109463; // bne x1, x1, +8
  assign wMem[33] = 32'h001C8C93; // addi x25, x25, 1
  assign wMem[34] = 32'h00209463; // bne x1, x2, +8
  assign wMem[35] = 32'h063D0D13; // addi x26, x26, 99
  assign wMem[36] = 32'h001D0D13; // addi x26, x26, 1
  assign wMem[37] = 32'h0020C463; // blt x1, x2, +8
  assign wMem[38] = 32'h001C8C93; // addi x25, x25, 1
  assign wMem[39] = 32'h0011C463; // blt x3, x1, +8
  assign wMem[40] = 32'h063D0D13; // addi x26, x26, 99
  assign wMem[41] = 32'h001D0D13; // addi x26, x26, 1
  assign wMem[42] = 32'h00115463; // bge x2, x1, +8
  assign wMem[43] = 32'h001C8C93; // addi x25, x25, 1
  assign wMem[44] = 32'h0020D463; // bge x1, x2, +8
  assign wMem[45] = 32'h063D0D13; // addi x26, x26, 99
  assign wMem[46] = 32'h001D0D13; // addi x26, x26, 1
  assign wMem[47] = 32'h0020E463; // bltu x1, x2, +8
  assign wMem[48] = 32'h001C8C93; // addi x25, x25, 1
  assign wMem[49] = 32'h00116463; // bltu x2, x1, +8
  assign wMem[50] = 32'h063D0D13; // addi x26, x26, 99
  assign wMem[51] = 32'h001D0D13; // addi x26, x26, 1
  assign wMem[52] = 32'h00117463; // bgeu x2, x1, +8
  assign wMem[53] = 32'h001C8C93; // addi x25, x25, 1
  assign wMem[54] = 32'h0020F463; // bgeu x1, x2, +8
  assign wMem[55] = 32'h063D0D13; // addi x26, x26, 99
  assign wMem[56] = 32'h001D0D13; // addi x26, x26, 1
  assign wMem[57] = 32'h00200D93; // addi x27, x0, 2
  assign wMem[58] = 32'h00000E13; // addi x28, x0, 0
  assign wMem[59] = 32'hFFFD8D93; // addi x27, x27, -1
  assign wMem[60] = 32'hFE0D9EE3; // bne x27, x0, -4
  assign wMem[61] = 32'h001E0E13; // addi x28, x28, 1
  assign wMem[62] = 32'h04400B93; // addi x23, x0, 68
  assign wMem[63] = 32'h08000093; // addi x1, x0, 128
  assign wMem[64] = 32'h001B8023; // sb x1, 0(x23)
  assign wMem[65] = 32'h07F00113; // addi x2, x0, 127
  assign wMem[66] = 32'h002B80A3; // sb x2, 1(x23)
  assign wMem[67] = 32'hFF200113; // addi x2, x0, -14
  assign wMem[68] = 32'h00811113; // slli x2, x2, 8
  assign wMem[69] = 32'h03410113; // addi x2, x2, 52
  assign wMem[70] = 32'h002B9123; // sh x2, 2(x23)
  assign wMem[71] = 32'h000B8F03; // lb x30, 0(x23)
  assign wMem[72] = 32'h000BCF83; // lbu x31, 0(x23)
  assign wMem[73] = 32'h002B9083; // lh x1, 2(x23)
  assign wMem[74] = 32'h002BD103; // lhu x2, 2(x23)
  assign wMem[75] = 32'hFFFFFFFF; // illegal opcode
  assign wMem[76] = 32'h008001EF; // jal x3, +8
  assign wMem[77] = 32'h06F00E93; // addi x29, x0, 111 (skipped by jal)
  assign wMem[78] = 32'h14100B93; // addi x23, x0, 321
  assign wMem[79] = 32'h000B8BE7; // jalr x23, x23, 0 -> target 320 after bit0 clear
  assign wMem[80] = 32'h123451B7; // lui x3, 0x12345
  assign wMem[81] = 32'h00001B97; // auipc x23, 0x1
  assign wMem[82] = 32'h04D00E93; // addi x29, x0, 77
  assign wMem[83] = 32'h00000013; // nop addi x0, x0, 0

  // Out-of-range fetches return nop (addi x0, x0, 0).
  assign oInstr = wAddrInRange ? wMem[wWordAddr] : 32'h00000013;

endmodule
