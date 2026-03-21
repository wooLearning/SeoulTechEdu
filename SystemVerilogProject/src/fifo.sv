/*
[MODULE_INFO_START]
Name: fifo
Role: RTL module implementing fifo
Summary:
  - Implements asynchronous dual-clock FIFO with Gray-code pointer synchronization
  - Provides registered read data and full/empty status flags
StateDescription:
  - N/A (pointer-based control, no explicit FSM)
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps
module fifo #(
  parameter int AW = 4,
  parameter int DW = 8,
  parameter int DEPTH = (1 << AW)
) (
  input  logic          iWrClk,
  input  logic          iRdClk,
  input  logic          iRstn,
  input  logic          iWrEn,
  input  logic          iRdEn,
  input  logic [DW-1:0] iWData,
  output logic [DW-1:0] oRData,
  output logic          oFull,
  output logic          oEmpty
);

  localparam int PW = AW + 1;  // Pointer width includes wrap bit.

  logic [DW-1:0] rMem [0:DEPTH-1];

  logic [PW-1:0] rWrBin;
  logic [PW-1:0] rWrGray;
  logic [PW-1:0] rRdBin;
  logic [PW-1:0] rRdGray;

  // Gray-pointer synchronizers (2-FF) across clock domains.
  logic [PW-1:0] rRdGraySync1, rRdGraySync2;
  logic [PW-1:0] rWrGraySync1, rWrGraySync2;

  logic [PW-1:0] wWrBinNext;
  logic [PW-1:0] wWrGrayNext;
  logic [PW-1:0] wRdBinNext;
  logic [PW-1:0] wRdGrayNext;
  logic          wWrFire;
  logic          wRdFire;
  logic          wFullNext;
  logic          wEmptyNext;

  function automatic logic [PW-1:0] fBin2Gray(input logic [PW-1:0] iBin);
    fBin2Gray = (iBin >> 1) ^ iBin;
  endfunction

  // Write/read acceptance decisions in each clock domain.
  assign wWrFire    = iWrEn && !oFull;
  assign wRdFire    = iRdEn && !oEmpty;
  assign wWrBinNext = rWrBin + (wWrFire ? 1'b1 : 1'b0);
  assign wRdBinNext = rRdBin + (wRdFire ? 1'b1 : 1'b0);
  assign wWrGrayNext = fBin2Gray(wWrBinNext);
  assign wRdGrayNext = fBin2Gray(wRdBinNext);

  // Full when next write Gray pointer reaches synchronized read pointer with
  // inverted MSBs (classic async FIFO full detection, assumes AW >= 2).
  assign wFullNext =
    (wWrGrayNext == {~rRdGraySync2[PW-1:PW-2], rRdGraySync2[PW-3:0]});

  // Empty when next read Gray pointer catches synchronized write pointer.
  assign wEmptyNext = (wRdGrayNext == rWrGraySync2);

  // Write clock domain: memory write + write pointer + full flag + read-pointer sync.
  always_ff @(posedge iWrClk or negedge iRstn) begin
    if (!iRstn) begin
      rWrBin      <= '0;
      rWrGray     <= '0;
      rRdGraySync1 <= '0;
      rRdGraySync2 <= '0;
      oFull       <= 1'b0;
    end
    else begin
      rRdGraySync1 <= rRdGray;
      rRdGraySync2 <= rRdGraySync1;

      if (wWrFire) begin
        rMem[rWrBin[AW-1:0]] <= iWData;
        rWrBin               <= wWrBinNext;
        rWrGray              <= wWrGrayNext;
      end

      oFull <= wFullNext;
    end
  end

  // Read clock domain: read pointer + registered read data + empty flag + write-pointer sync.
  always_ff @(posedge iRdClk or negedge iRstn) begin
    if (!iRstn) begin
      rRdBin      <= '0;
      rRdGray     <= '0;
      rWrGraySync1 <= '0;
      rWrGraySync2 <= '0;
      oRData      <= '0;
      oEmpty      <= 1'b1;
    end
    else begin
      rWrGraySync1 <= rWrGray;
      rWrGraySync2 <= rWrGraySync1;

      if (wRdFire) begin
        oRData <= rMem[rRdBin[AW-1:0]];
        rRdBin <= wRdBinNext;
        rRdGray <= wRdGrayNext;
      end

      oEmpty <= wEmptyNext;
    end
  end

endmodule
