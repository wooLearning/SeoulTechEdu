`timescale 1ns / 1ps

module imm_extender (
    input  logic [31:0] i_instr_data,
    output logic [31:0] o_imm_data
);

    typedef enum logic [6:0] {
        I_TYPE_ALU   = 7'b001_0011,
        S_TYPE       = 7'b010_0011,
        I_TYPE_LOAD  = 7'b000_0011,
        B_TYPE       = 7'b110_0011,
        I_TYPE_JALR  = 7'b110_0111,
        J_TYPE       = 7'b110_1111,
        U_TYPE_LUI   = 7'b011_0111,
        U_TYPE_AUIPC = 7'b001_0111
    } opcode_t;

    always_comb begin
        o_imm_data = 32'd0;
        case (i_instr_data[6:0])
            I_TYPE_ALU, I_TYPE_LOAD, I_TYPE_JALR: begin
                o_imm_data = {{20{i_instr_data[31]}}, i_instr_data[31:20]};
            end
            S_TYPE: begin
                o_imm_data = {{20{i_instr_data[31]}}, i_instr_data[31:25], i_instr_data[11:7]};
            end
            B_TYPE: begin
                o_imm_data = {
                    {19{i_instr_data[31]}},
                    i_instr_data[31],
                    i_instr_data[7],
                    i_instr_data[30:25],
                    i_instr_data[11:8],
                    1'b0
                };
            end
            J_TYPE: begin
                o_imm_data = {
                    {11{i_instr_data[31]}},
                    i_instr_data[31],
                    i_instr_data[19:12],
                    i_instr_data[20],
                    i_instr_data[30:21],
                    1'b0
                };
            end
            U_TYPE_LUI, U_TYPE_AUIPC: begin
                o_imm_data = {i_instr_data[31:12], 12'b0};
            end
            default: begin
                o_imm_data = 32'd0;
            end
        endcase
    end

endmodule
