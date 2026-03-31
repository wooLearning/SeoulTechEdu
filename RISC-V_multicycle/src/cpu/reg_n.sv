`timescale 1ns / 1ps

module reg_n #(
    parameter int WIDTH = 32,
    parameter logic [WIDTH-1:0] RESET_VALUE = '0
) (
    input  logic             clk,
    input  logic             rst,
    input  logic             i_we,
    input  logic [WIDTH-1:0] i_d,
    output logic [WIDTH-1:0] o_q
);

    always_ff @(posedge clk) begin
        if (rst) begin
            o_q <= RESET_VALUE;
        end else if (i_we) begin
            o_q <= i_d;
        end
    end

endmodule
