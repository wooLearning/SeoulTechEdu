`timescale 1ns / 1ps
`define SIMULATION

module register_file (
    input  logic        clk,
    input  logic        rst,
    input  logic [ 4:0] i_ra1,
    input  logic [ 4:0] i_ra2,
    input  logic [ 4:0] i_wa,
    input  logic        i_we,
    input  logic [31:0] i_wdata,
    output logic [31:0] o_rd1,
    output logic [31:0] o_rd2
);

    logic [31:0] register_file [0:31];

`ifdef SIMULATION
    initial begin
        for (int i = 0; i < 32; i++) begin
            register_file[i] = 32'b0;
        end
    end
`endif

    always_ff @(posedge clk) begin
        if ((!rst) && i_we && (i_wa != 5'd0)) begin
            register_file[i_wa] <= i_wdata;
        end
    end

    assign o_rd1 = (i_ra1 != 5'd0) ? register_file[i_ra1] : 32'b0;
    assign o_rd2 = (i_ra2 != 5'd0) ? register_file[i_ra2] : 32'b0;

endmodule
