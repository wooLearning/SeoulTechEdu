`timescale 1ns / 1ps

// Simple word-addressed data RAM with byte/half/word load-store support.
module DataRam #(
  parameter integer P_ADDR_WIDTH = 8,
  parameter integer P_DATA_WIDTH = 32
) (
  input  logic                      iClk,
  input  logic                      iWrEn,
  input  logic [31:0]               iAddr,
  input  logic [P_DATA_WIDTH-1:0]   iWrData,
  input  rv32i_pkg::load_type_e     iLoadType,
  input  rv32i_pkg::store_type_e    iStoreType,
  output logic [P_DATA_WIDTH-1:0]   oRdData
);

  localparam integer LP_DEPTH = (1 << P_ADDR_WIDTH);

  logic [P_DATA_WIDTH-1:0] rMemRam [0:LP_DEPTH-1];
  logic [P_DATA_WIDTH-1:0] wWordData;
  logic [7:0]              wByteData;
  logic [15:0]             wHalfData;

  assign wWordData = rMemRam[iAddr[P_ADDR_WIDTH+1:2]];

  always_comb begin
    unique case (iAddr[1:0])
      2'd0:    wByteData = wWordData[7:0];
      2'd1:    wByteData = wWordData[15:8];
      2'd2:    wByteData = wWordData[23:16];
      default: wByteData = wWordData[31:24];
    endcase
  end

  assign wHalfData = iAddr[1] ? wWordData[31:16] : wWordData[15:0];

  always_comb begin
    oRdData = 32'd0;

    unique case (iLoadType)
      rv32i_pkg::LOAD_LB:  oRdData = {{24{wByteData[7]}}, wByteData};
      rv32i_pkg::LOAD_LH:  oRdData = {{16{wHalfData[15]}}, wHalfData};
      rv32i_pkg::LOAD_LW:  oRdData = wWordData;
      rv32i_pkg::LOAD_LBU: oRdData = {24'd0, wByteData};
      rv32i_pkg::LOAD_LHU: oRdData = {16'd0, wHalfData};
      default:             oRdData = wWordData;
    endcase
  end

  always_ff @(posedge iClk) begin
    if (iWrEn) begin
      unique case (iStoreType)
        rv32i_pkg::STORE_SB: begin
          unique case (iAddr[1:0])
            2'd0:    rMemRam[iAddr[P_ADDR_WIDTH+1:2]][7:0]   <= iWrData[7:0];
            2'd1:    rMemRam[iAddr[P_ADDR_WIDTH+1:2]][15:8]  <= iWrData[7:0];
            2'd2:    rMemRam[iAddr[P_ADDR_WIDTH+1:2]][23:16] <= iWrData[7:0];
            default: rMemRam[iAddr[P_ADDR_WIDTH+1:2]][31:24] <= iWrData[7:0];
          endcase
        end
        rv32i_pkg::STORE_SH: begin
          if (iAddr[1]) begin
            rMemRam[iAddr[P_ADDR_WIDTH+1:2]][31:16] <= iWrData[15:0];
          end else begin
            rMemRam[iAddr[P_ADDR_WIDTH+1:2]][15:0] <= iWrData[15:0];
          end
        end
        rv32i_pkg::STORE_SW: begin
          rMemRam[iAddr[P_ADDR_WIDTH+1:2]] <= iWrData;
        end
        default: begin end
      endcase
    end
  end

endmodule
