/*
[MODULE_INFO_START]
Name: sync_fifo
Role: RTL module implementing sync_fifo
Summary:
  - Implements synchronous single-clock FIFO with full/empty flags
  - Supports simultaneous read/write in one clock cycle
StateDescription:
  - N/A (pointer/count-based control, no explicit FSM)
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps
module sync_fifo #(
  parameter int AW = 4,
  parameter int DW = 8,
  parameter int DEPTH = (1 << AW)
) (
  input  logic          iClk,
  input  logic          iRstn,
  input  logic          iWrEn,
  input  logic          iRdEn,
  input  logic [DW-1:0] iWData,
  output logic [DW-1:0] oRData,
  output logic          oFull,
  output logic          oEmpty
);

  localparam int CW = AW + 1;  // Count width supports 0..DEPTH.

  logic [DW-1:0] rMem [0:DEPTH-1];
  logic [AW-1:0] rWrPtr;
  logic [AW-1:0] rRdPtr;
  logic [CW-1:0] rCount;
  integer rIdx;

  logic wRdFire;
  logic wWrFire;

  assign oEmpty = (rCount == 0);
  assign oFull  = (rCount == DEPTH);

  // Allow write on full only when a read also succeeds in the same cycle.
  assign wRdFire = iRdEn && !oEmpty;
  assign wWrFire = iWrEn && (!oFull || wRdFire);

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      rWrPtr <= '0;
      rRdPtr <= '0;
      rCount <= '0;
      oRData <= '0;

      for (rIdx = 0; rIdx < DEPTH; rIdx = rIdx + 1) begin
        rMem[rIdx] <= '0;
      end
    end
    else begin
      // Read returns the entry pointed by current read pointer.
      if (wRdFire) begin
        oRData <= rMem[rRdPtr];
        rRdPtr <= rRdPtr + 1'b1;
      end

      // Write stores at current write pointer.
      if (wWrFire) begin
        rMem[rWrPtr] <= iWData;
        rWrPtr <= rWrPtr + 1'b1;
      end

      case ({wWrFire, wRdFire})
        2'b10: rCount <= rCount + 1'b1;
        2'b01: rCount <= rCount - 1'b1;
        default: rCount <= rCount;
      endcase
    end
  end

endmodule
