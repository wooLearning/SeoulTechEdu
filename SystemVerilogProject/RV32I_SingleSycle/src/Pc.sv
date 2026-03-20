`timescale 1ns / 1ps

// Program counter register plus next-PC selection for sequential and branch flow.
module Pc (
  input  logic        iClk,
  input  logic        iRstn,
  input  logic        iPcWe,
  input  logic        iPcTargetEn,
  input  logic [31:0] iPcTarget,
  output logic [31:0] oPc,
  output logic [31:0] oPcPlus4
);

  logic [31:0] wPcPlus4;
  logic [31:0] wNextPc;

  assign wPcPlus4 = oPc + 32'd4;
  assign oPcPlus4 = wPcPlus4;
  assign wNextPc  = iPcTargetEn ? iPcTarget : wPcPlus4;

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      // Reset starts instruction fetch from address 0.
      oPc <= 32'd0;
    end else if (iPcWe) begin
      oPc <= wNextPc;
    end
  end

endmodule
