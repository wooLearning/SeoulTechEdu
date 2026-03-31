`timescale 1ns / 1ps

module pc_reg #(
    parameter logic [31:0] RESET_PC = 32'h0000_0000
) (
    input  logic        clk,
    input  logic        rst,
    input  logic        i_we,
    input  logic [31:0] i_pc_next,
    output logic [31:0] o_pc_data
);

    always_ff @(posedge clk) begin
        if (rst) begin
            o_pc_data <= RESET_PC;
        end else if (i_we) begin
            o_pc_data <= i_pc_next;
        end
    end

endmodule
