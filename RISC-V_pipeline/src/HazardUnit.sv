`timescale 1ns / 1ps

/*
[MODULE_INFO_START]
Name: HazardUnit
Role: RTL module implementing pipeline load-use hazard detection
Summary:
  - Detects the single-cycle stall required for load-use hazards
  - Leaves control-flow flush decisions to the top-level pipeline controller
StateDescription:
  - Combinational only: no internal state
[MODULE_INFO_END]
*/
module HazardUnit (
  input  logic       iIdValid,
  input  logic [4:0] iIdRs1Addr,
  input  logic [4:0] iIdRs2Addr,
  input  logic       iIdUsesRs1,
  input  logic       iIdUsesRs2,
  input  logic       iExValid,
  input  logic [4:0] iExRdAddr,
  input  logic       iExIsLoad,
  output logic       oLoadUseStall
);

  always_comb begin
    oLoadUseStall = 1'b0;

    if (iIdValid && iExValid && iExIsLoad && (iExRdAddr != 5'd0)) begin
      if ((iIdUsesRs1 && (iIdRs1Addr == iExRdAddr)) ||
          (iIdUsesRs2 && (iIdRs2Addr == iExRdAddr))) begin
        oLoadUseStall = 1'b1;
      end
    end
  end

endmodule
