`timescale 1ns / 1ps

module alu (
    input  logic [31:0] i_a,
    input  logic [31:0] i_b,
    input  logic [ 3:0] i_alu_control,
    output logic [31:0] o_alu_data
);

    typedef enum logic [3:0] {
        ADD  = 4'b0_000,
        SUB  = 4'b1_000,
        SLL  = 4'b0_001,
        SLT  = 4'b0_010,
        SLTU = 4'b0_011,
        XOR  = 4'b0_100,
        SRL  = 4'b0_101,
        SRA  = 4'b1_101,
        OR   = 4'b0_110,
        AND  = 4'b0_111
    } inst_t;

    always_comb begin
        o_alu_data = 32'b0;
        case (i_alu_control)
            ADD:  o_alu_data = i_a + i_b;
            SUB:  o_alu_data = i_a - i_b;
            SLL:  o_alu_data = i_a << i_b[4:0];
            SLT:  o_alu_data = ($signed(i_a) < $signed(i_b)) ? 32'd1 : 32'd0;
            SLTU: o_alu_data = (i_a < i_b) ? 32'd1 : 32'd0;
            XOR:  o_alu_data = i_a ^ i_b;
            SRL:  o_alu_data = i_a >> i_b[4:0];
            SRA:  o_alu_data = $signed(i_a) >>> i_b[4:0];
            OR:   o_alu_data = i_a | i_b;
            AND:  o_alu_data = i_a & i_b;
            default: o_alu_data = 32'b0;
        endcase
    end

endmodule
