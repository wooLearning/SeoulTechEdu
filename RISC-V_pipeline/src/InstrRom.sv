`timescale 1ns / 1ps

/*
[MODULE_INFO_START]
Name: InstrRom
Role: RTL module implementing the shared parameterized instruction ROM
Summary:
  - Uses one fixed-size readmem-backed ROM structure for every program image
  - Selects the image through a single P_INIT_FILE parameter
  - Returns nop for out-of-range instruction fetches
StateDescription:
  - ROM word 0..P_DEPTH-1: initialized from P_INIT_FILE, defaulting to nop
[MODULE_INFO_END]
*/
module InstrRom #(
  parameter integer P_ADDR_WIDTH = 8,
  parameter integer P_DATA_WIDTH = 32,
  parameter integer P_DEPTH      = 128,
  parameter logic [31:0] P_BASE_ADDR = 32'd0,
  parameter string  P_INIT_FILE  = "src/mem/InstructionDefault.mem"
) (
  input  logic [31:0]             iAddr,
  output logic [P_DATA_WIDTH-1:0] oInstr
);

  localparam integer LP_WORD_ADDR_WIDTH = (P_DEPTH <= 2) ? 1 : $clog2(P_DEPTH);
  localparam logic [31:0] LP_NOP = 32'h00000013;

  (* rom_style = "distributed" *) logic [P_DATA_WIDTH-1:0] rMem[0:P_DEPTH-1];
  logic [LP_WORD_ADDR_WIDTH-1:0]   wWordAddr;
  logic [31:0]                     wWordAddrExt;
  logic [31:0]                     wRelAddr;
  logic                            wAddrAboveBase;
  logic                            wAddrInRange;
  integer                          idxInit;
`ifndef SYNTHESIS
  integer                          fdImage;
`endif

  assign wAddrAboveBase = (iAddr >= P_BASE_ADDR);
  assign wRelAddr     = iAddr - P_BASE_ADDR;
  assign wWordAddr    = wRelAddr[LP_WORD_ADDR_WIDTH+1:2];
  assign wWordAddrExt = {{(32-LP_WORD_ADDR_WIDTH){1'b0}}, wWordAddr};
  assign wAddrInRange = wAddrAboveBase &&
                        (wRelAddr[31:LP_WORD_ADDR_WIDTH+2] == '0) &&
                        (wWordAddrExt < P_DEPTH);

  initial begin
    for (idxInit = 0; idxInit < P_DEPTH; idxInit = idxInit + 1) begin
      rMem[idxInit] = LP_NOP;
    end

`ifdef SYNTHESIS
    $readmemh(P_INIT_FILE, rMem);
`else
    fdImage = $fopen(P_INIT_FILE, "r");
    if (fdImage == 0) begin
      $fatal(1, "InstrRom failed to load image '%s'", P_INIT_FILE);
    end else begin
      $fclose(fdImage);
      $readmemh(P_INIT_FILE, rMem);
      $display("[INFO] InstrRom loaded %s", P_INIT_FILE);
    end
`endif
  end

  assign oInstr = wAddrInRange ? rMem[wWordAddr] : LP_NOP;

endmodule
