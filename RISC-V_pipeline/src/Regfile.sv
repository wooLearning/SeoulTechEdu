`timescale 1ns / 1ps

// 32-entry integer register file with x0 hardwired to zero.
module Regfile (
  input  logic        iClk,
  input  logic        iRstn,
  input  logic [4:0]  iRs1Addr,
  input  logic [4:0]  iRs2Addr,
  input  logic [4:0]  iRdAddr,
  input  logic [31:0] iRdWrData,
  input  logic        iRdWrEn,
  output logic [31:0] oRs1RdData,
  output logic [31:0] oRs2RdData
);

  logic [31:0] rMemReg [0:31];
  integer idx;

  always_comb begin
    // Reads are combinational; x0 always returns zero.
    oRs1RdData = 32'd0;
    oRs2RdData = 32'd0;

    if (iRs1Addr != 5'd0) begin
      oRs1RdData = rMemReg[iRs1Addr];
    end

    if (iRs2Addr != 5'd0) begin
      oRs2RdData = rMemReg[iRs2Addr];
    end
  end

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      // Reset clears the register state for deterministic simulation.
      for (idx = 0; idx < 32; idx = idx + 1) begin
        rMemReg[idx] <= 32'd0;
      end
    end else begin
      if (iRdWrEn && (iRdAddr != 5'd0)) begin
        rMemReg[iRdAddr] <= iRdWrData;
      end

      // Keep x0 pinned to zero even if a write is attempted.
      rMemReg[0] <= 32'd0;
    end
  end

endmodule
