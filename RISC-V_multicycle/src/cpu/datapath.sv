`timescale 1ns / 1ps

module datapath (
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] i_mem_rdata,
    input  logic        i_pc_we,
    input  logic        i_pc_we_cond,
    input  logic [1:0]  i_pc_src_sel,
    input  logic        i_pc_jalr_mask,
    input  logic        i_old_pc_we,
    input  logic        i_ir_we,
    input  logic        i_mdr_we,
    input  logic        i_a_we,
    input  logic        i_b_we,
    input  logic        i_alu_out_we,
    input  logic        i_rf_we,
    input  logic        i_mem_addr_sel,
    input  logic        i_mem_fetch_word,
    input  logic [1:0]  i_alu_src_a_sel,
    input  logic [1:0]  i_alu_src_b_sel,
    input  logic [3:0]  i_alu_control,
    input  logic [1:0]  i_rf_wdata_sel,
    output logic [31:0] o_mem_addr,
    output logic [31:0] o_mem_wdata,
    output logic [ 2:0] o_mem_funct3,
    output logic [ 6:0] o_opcode,
    output logic [ 2:0] o_funct3,
    output logic [ 6:0] o_funct7,
    output logic [31:0] o_pc_data,
    output logic        o_branch_taken,
    output logic        o_commit_valid,
    output logic [ 4:0] o_commit_rd,
    output logic [31:0] o_commit_wdata
);

    logic [31:0] w_pc_data;
    logic [31:0] w_pc_next;
    logic [31:0] w_old_pc_data;
    logic [31:0] w_ir_data;
    logic [31:0] w_mdr_data;
    logic [31:0] w_a_data;
    logic [31:0] w_b_data;
    logic [31:0] w_alu_out_data;
    logic [31:0] w_rf_rd1;
    logic [31:0] w_rf_rd2;
    logic [31:0] w_imm_data;
    logic [31:0] w_alu_src_a;
    logic [31:0] w_alu_src_b;
    logic [31:0] w_alu_result;
    logic [31:0] w_rf_wdata;
    logic        w_pc_write_enable;

    assign o_opcode = w_ir_data[6:0];
    assign o_funct3 = w_ir_data[14:12];
    assign o_funct7 = w_ir_data[31:25];
    assign o_pc_data = w_pc_data;

    assign o_mem_addr   = (i_mem_addr_sel == 1'b0) ? w_pc_data : w_alu_out_data;
    assign o_mem_wdata  = w_b_data;
    assign o_mem_funct3 = i_mem_fetch_word ? 3'b010 : w_ir_data[14:12];

    assign o_commit_valid = i_rf_we;
    assign o_commit_rd    = w_ir_data[11:7];
    assign o_commit_wdata = w_rf_wdata;

    always_comb begin
        case (i_alu_src_a_sel)
            2'b00: w_alu_src_a = w_pc_data;
            2'b01: w_alu_src_a = w_a_data;
            2'b10: w_alu_src_a = w_old_pc_data;
            default: w_alu_src_a = 32'b0;
        endcase
    end

    always_comb begin
        case (i_alu_src_b_sel)
            2'b00: w_alu_src_b = w_b_data;
            2'b01: w_alu_src_b = 32'd4;
            2'b10: w_alu_src_b = w_imm_data;
            default: w_alu_src_b = 32'b0;
        endcase
    end

    always_comb begin
        case (i_rf_wdata_sel)
            2'b00: w_rf_wdata = w_alu_out_data;
            2'b01: w_rf_wdata = w_mdr_data;
            2'b10: w_rf_wdata = w_imm_data;
            2'b11: w_rf_wdata = w_pc_data;
            default: w_rf_wdata = w_alu_out_data;
        endcase
    end

    always_comb begin
        case (i_pc_src_sel)
            2'b00: w_pc_next = w_alu_result;
            2'b01: w_pc_next = w_alu_out_data;
            default: w_pc_next = w_alu_result;
        endcase

        if (i_pc_jalr_mask) begin
            w_pc_next = {w_pc_next[31:1], 1'b0};
        end
    end

    assign w_pc_write_enable = i_pc_we | (i_pc_we_cond & o_branch_taken);

    pc_reg U_PC (
        .clk      (clk),
        .rst      (rst),
        .i_we     (w_pc_write_enable),
        .i_pc_next(w_pc_next),
        .o_pc_data(w_pc_data)
    );

    reg_n #(
        .WIDTH(32),
        .RESET_VALUE(32'b0)
    ) U_OLD_PC (
        .clk (clk),
        .rst (rst),
        .i_we(i_old_pc_we),
        .i_d (w_pc_data),
        .o_q (w_old_pc_data)
    );

    reg_n #(
        .WIDTH(32),
        .RESET_VALUE(32'h0000_0013)
    ) U_IR (
        .clk (clk),
        .rst (rst),
        .i_we(i_ir_we),
        .i_d (i_mem_rdata),
        .o_q (w_ir_data)
    );

    reg_n #(
        .WIDTH(32),
        .RESET_VALUE(32'b0)
    ) U_MDR (
        .clk (clk),
        .rst (rst),
        .i_we(i_mdr_we),
        .i_d (i_mem_rdata),
        .o_q (w_mdr_data)
    );

    reg_n #(
        .WIDTH(32),
        .RESET_VALUE(32'b0)
    ) U_A (
        .clk (clk),
        .rst (rst),
        .i_we(i_a_we),
        .i_d (w_rf_rd1),
        .o_q (w_a_data)
    );

    reg_n #(
        .WIDTH(32),
        .RESET_VALUE(32'b0)
    ) U_B (
        .clk (clk),
        .rst (rst),
        .i_we(i_b_we),
        .i_d (w_rf_rd2),
        .o_q (w_b_data)
    );

    reg_n #(
        .WIDTH(32),
        .RESET_VALUE(32'b0)
    ) U_ALU_OUT (
        .clk (clk),
        .rst (rst),
        .i_we(i_alu_out_we),
        .i_d (w_alu_result),
        .o_q (w_alu_out_data)
    );

    register_file U_REG_FILE (
        .clk    (clk),
        .rst    (rst),
        .i_ra1  (w_ir_data[19:15]),
        .i_ra2  (w_ir_data[24:20]),
        .i_wa   (w_ir_data[11:7]),
        .i_we   (i_rf_we),
        .i_wdata(w_rf_wdata),
        .o_rd1  (w_rf_rd1),
        .o_rd2  (w_rf_rd2)
    );

    imm_extender U_IMM (
        .i_instr_data(w_ir_data),
        .o_imm_data  (w_imm_data)
    );

    alu U_ALU (
        .i_a          (w_alu_src_a),
        .i_b          (w_alu_src_b),
        .i_alu_control(i_alu_control),
        .o_alu_data   (w_alu_result)
    );

    branch_cmp U_BRANCH_CMP (
        .i_a      (w_a_data),
        .i_b      (w_b_data),
        .i_funct3 (w_ir_data[14:12]),
        .o_b_taken(o_branch_taken)
    );

endmodule
