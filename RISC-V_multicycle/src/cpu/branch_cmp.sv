`timescale 1ns / 1ps

module branch_cmp (
    input  logic [31:0] i_a,
    input  logic [31:0] i_b,
    input  logic [ 2:0] i_funct3,
    output logic        o_b_taken
);

    always_comb begin
        o_b_taken = 1'b0;
        case (i_funct3)
            3'b000: o_b_taken = (i_a == i_b);
            3'b001: o_b_taken = (i_a != i_b);
            3'b100: o_b_taken = ($signed(i_a) < $signed(i_b));
            3'b101: o_b_taken = ($signed(i_a) >= $signed(i_b));
            3'b110: o_b_taken = (i_a < i_b);
            3'b111: o_b_taken = (i_a >= i_b);
            default: o_b_taken = 1'b0;
        endcase
    end

endmodule
