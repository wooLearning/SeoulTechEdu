`timescale 1ns / 1ps

module control (
    input  logic        clk,
    input  logic        rst,
    input  logic        i_mem_ready,
    input  logic        i_mem_error,
    input  logic [6:0]  i_opcode,
    input  logic [2:0]  i_funct3,
    input  logic [6:0]  i_funct7,
    output logic        o_pc_we,
    output logic        o_pc_we_cond,
    output logic [1:0]  o_pc_src_sel,
    output logic        o_pc_jalr_mask,
    output logic        o_old_pc_we,
    output logic        o_ir_we,
    output logic        o_mdr_we,
    output logic        o_a_we,
    output logic        o_b_we,
    output logic        o_alu_out_we,
    output logic        o_rf_we,
    output logic        o_mem_valid,
    output logic        o_mem_write,
    output logic        o_mem_addr_sel,
    output logic        o_mem_fetch_word,
    output logic [1:0]  o_alu_src_a_sel,
    output logic [1:0]  o_alu_src_b_sel,
    output logic [3:0]  o_alu_control,
    output logic [1:0]  o_rf_wdata_sel,
    output logic        o_instr_done,
    output logic [3:0]  o_state_dbg
);

    typedef enum logic [3:0] {
        ST_FETCH,
        ST_DECODE,
        ST_MEM_ADDR,
        ST_MEM_READ,
        ST_MEM_WB,
        ST_MEM_WRITE,
        ST_EXEC_R,
        ST_WB_ALU,
        ST_BRANCH,
        ST_EXEC_I,
        ST_JAL,
        ST_JALR,
        ST_LUI,
        ST_AUIPC,
        ST_FAULT
    } state_t;

    typedef enum logic [6:0] {
        R_TYPE       = 7'b011_0011,
        I_TYPE_ALU   = 7'b001_0011,
        S_TYPE       = 7'b010_0011,
        I_TYPE_LOAD  = 7'b000_0011,
        B_TYPE       = 7'b110_0011,
        I_TYPE_JALR  = 7'b110_0111,
        J_TYPE       = 7'b110_1111,
        U_TYPE_LUI   = 7'b011_0111,
        U_TYPE_AUIPC = 7'b001_0111
    } opcode_t;

    state_t state_q, state_d;

    function automatic logic [3:0] decode_alu_control(
        input logic [6:0] opcode,
        input logic [2:0] funct3,
        input logic [6:0] funct7
    );
        begin
            decode_alu_control = 4'b0000;
            case (opcode)
                R_TYPE: begin
                    decode_alu_control = {funct7[5], funct3};
                end
                I_TYPE_ALU: begin
                    case (funct3)
                        3'b001: decode_alu_control = 4'b0001;
                        3'b101: decode_alu_control = {funct7[5], 3'b101};
                        default: decode_alu_control = {1'b0, funct3};
                    endcase
                end
                default: begin
                    decode_alu_control = 4'b0000;
                end
            endcase
        end
    endfunction

    always_comb begin
        state_d = state_q;

        o_pc_we         = 1'b0;
        o_pc_we_cond    = 1'b0;
        o_pc_src_sel    = 2'b00;
        o_pc_jalr_mask  = 1'b0;
        o_old_pc_we     = 1'b0;
        o_ir_we         = 1'b0;
        o_mdr_we        = 1'b0;
        o_a_we          = 1'b0;
        o_b_we          = 1'b0;
        o_alu_out_we    = 1'b0;
        o_rf_we         = 1'b0;
        o_mem_valid     = 1'b0;
        o_mem_write     = 1'b0;
        o_mem_addr_sel  = 1'b0;
        o_mem_fetch_word = 1'b0;
        o_alu_src_a_sel = 2'b00;
        o_alu_src_b_sel = 2'b00;
        o_alu_control   = 4'b0000;
        o_rf_wdata_sel  = 2'b00;
        o_instr_done    = 1'b0;
        o_state_dbg     = state_q;

        case (state_q)
            ST_FETCH: begin
                o_mem_valid      = 1'b1;
                o_mem_fetch_word = 1'b1;
                o_alu_src_a_sel  = 2'b00;
                o_alu_src_b_sel  = 2'b01;
                o_alu_control    = 4'b0000;
                if (i_mem_ready) begin
                    if (i_mem_error) begin
                        state_d = ST_FAULT;
                    end else begin
                        o_old_pc_we = 1'b1;
                        o_ir_we     = 1'b1;
                        o_pc_we     = 1'b1;
                        state_d     = ST_DECODE;
                    end
                end
            end

            ST_DECODE: begin
                o_a_we         = 1'b1;
                o_b_we         = 1'b1;
                o_alu_out_we   = 1'b1;
                o_alu_src_a_sel = 2'b10;
                o_alu_src_b_sel = 2'b10;
                o_alu_control   = 4'b0000;
                unique case (i_opcode)
                    I_TYPE_LOAD, S_TYPE: state_d = ST_MEM_ADDR;
                    R_TYPE:              state_d = ST_EXEC_R;
                    I_TYPE_ALU:          state_d = ST_EXEC_I;
                    B_TYPE:              state_d = ST_BRANCH;
                    J_TYPE:              state_d = ST_JAL;
                    I_TYPE_JALR:         state_d = ST_JALR;
                    U_TYPE_LUI:          state_d = ST_LUI;
                    U_TYPE_AUIPC:        state_d = ST_AUIPC;
                    default:             state_d = ST_FETCH;
                endcase
            end

            ST_MEM_ADDR: begin
                o_alu_out_we    = 1'b1;
                o_alu_src_a_sel = 2'b01;
                o_alu_src_b_sel = 2'b10;
                o_alu_control   = 4'b0000;
                if (i_opcode == I_TYPE_LOAD) state_d = ST_MEM_READ;
                else                         state_d = ST_MEM_WRITE;
            end

            ST_MEM_READ: begin
                o_mem_valid    = 1'b1;
                o_mem_addr_sel = 1'b1;
                if (i_mem_ready) begin
                    if (i_mem_error) begin
                        state_d = ST_FAULT;
                    end else begin
                        o_mdr_we = 1'b1;
                        state_d  = ST_MEM_WB;
                    end
                end
            end

            ST_MEM_WB: begin
                o_rf_we        = 1'b1;
                o_rf_wdata_sel = 2'b01;
                o_instr_done   = 1'b1;
                state_d        = ST_FETCH;
            end

            ST_MEM_WRITE: begin
                o_mem_valid    = 1'b1;
                o_mem_write    = 1'b1;
                o_mem_addr_sel = 1'b1;
                if (i_mem_ready) begin
                    if (i_mem_error) begin
                        state_d = ST_FAULT;
                    end else begin
                        o_instr_done = 1'b1;
                        state_d = ST_FETCH;
                    end
                end
            end

            ST_EXEC_R: begin
                o_alu_out_we    = 1'b1;
                o_alu_src_a_sel = 2'b01;
                o_alu_src_b_sel = 2'b00;
                o_alu_control   = decode_alu_control(i_opcode, i_funct3, i_funct7);
                state_d         = ST_WB_ALU;
            end

            ST_EXEC_I: begin
                o_alu_out_we    = 1'b1;
                o_alu_src_a_sel = 2'b01;
                o_alu_src_b_sel = 2'b10;
                o_alu_control   = decode_alu_control(i_opcode, i_funct3, i_funct7);
                state_d         = ST_WB_ALU;
            end

            ST_WB_ALU: begin
                o_rf_we        = 1'b1;
                o_rf_wdata_sel = 2'b00;
                o_instr_done   = 1'b1;
                state_d        = ST_FETCH;
            end

            ST_BRANCH: begin
                o_pc_we_cond = 1'b1;
                o_pc_src_sel = 2'b01;
                o_instr_done = 1'b1;
                state_d      = ST_FETCH;
            end

            ST_JAL: begin
                o_rf_we        = 1'b1;
                o_rf_wdata_sel = 2'b11;
                o_pc_we        = 1'b1;
                o_pc_src_sel   = 2'b01;
                o_instr_done   = 1'b1;
                state_d        = ST_FETCH;
            end

            ST_JALR: begin
                o_rf_we         = 1'b1;
                o_rf_wdata_sel  = 2'b11;
                o_pc_we         = 1'b1;
                o_pc_jalr_mask  = 1'b1;
                o_alu_src_a_sel = 2'b01;
                o_alu_src_b_sel = 2'b10;
                o_alu_control   = 4'b0000;
                o_instr_done    = 1'b1;
                state_d         = ST_FETCH;
            end

            ST_LUI: begin
                o_rf_we        = 1'b1;
                o_rf_wdata_sel = 2'b10;
                o_instr_done   = 1'b1;
                state_d        = ST_FETCH;
            end

            ST_AUIPC: begin
                o_rf_we        = 1'b1;
                o_rf_wdata_sel = 2'b00;
                o_instr_done   = 1'b1;
                state_d        = ST_FETCH;
            end

            ST_FAULT: begin
                state_d = ST_FAULT;
            end

            default: begin
                state_d = ST_FETCH;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            state_q <= ST_FETCH;
        end else begin
            state_q <= state_d;
        end
    end

endmodule
