`timescale 1ns / 1ps

// CPU: single-hart RV32I multicycle core
module Top_CPU (
    input  logic        clk,
    input  logic        rst,
    input  logic        i_mem_ready,
    input  logic [31:0] i_mem_rdata,
    input  logic        i_mem_error,
    output logic        o_mem_valid,
    output logic        o_mem_write,
    output logic [31:0] o_mem_addr,
    output logic [31:0] o_mem_wdata,
    output logic [ 2:0] o_mem_funct3,
    output logic [31:0] o_pc_data,
    output logic        o_instr_done,
    output logic [ 3:0] o_state_dbg,
    output logic        o_commit_valid,
    output logic [ 4:0] o_commit_rd,
    output logic [31:0] o_commit_wdata
);

    logic        w_pc_we;
    logic        w_pc_we_cond;
    logic [1:0]  w_pc_src_sel;
    logic        w_pc_jalr_mask;
    logic        w_old_pc_we;
    logic        w_ir_we;
    logic        w_mdr_we;
    logic        w_a_we;
    logic        w_b_we;
    logic        w_alu_out_we;
    logic        w_rf_we;
    logic        w_mem_addr_sel;
    logic        w_mem_fetch_word;
    logic [1:0]  w_alu_src_a_sel;
    logic [1:0]  w_alu_src_b_sel;
    logic [3:0]  w_alu_control;
    logic [1:0]  w_rf_wdata_sel;
    logic [6:0]  w_opcode;
    logic [2:0]  w_funct3;
    logic [6:0]  w_funct7;
    logic        w_branch_taken;
    logic        w_instr_done;
    logic [3:0]  w_state_dbg;

    control U_CONTROL (
        .clk            (clk),
        .rst            (rst),
        .i_mem_ready    (i_mem_ready),
        .i_mem_error    (i_mem_error),
        .i_opcode       (w_opcode),
        .i_funct3       (w_funct3),
        .i_funct7       (w_funct7),
        .o_pc_we        (w_pc_we),
        .o_pc_we_cond   (w_pc_we_cond),
        .o_pc_src_sel   (w_pc_src_sel),
        .o_pc_jalr_mask (w_pc_jalr_mask),
        .o_old_pc_we    (w_old_pc_we),
        .o_ir_we        (w_ir_we),
        .o_mdr_we       (w_mdr_we),
        .o_a_we         (w_a_we),
        .o_b_we         (w_b_we),
        .o_alu_out_we   (w_alu_out_we),
        .o_rf_we        (w_rf_we),
        .o_mem_valid    (o_mem_valid),
        .o_mem_write    (o_mem_write),
        .o_mem_addr_sel (w_mem_addr_sel),
        .o_mem_fetch_word(w_mem_fetch_word),
        .o_alu_src_a_sel(w_alu_src_a_sel),
        .o_alu_src_b_sel(w_alu_src_b_sel),
        .o_alu_control  (w_alu_control),
        .o_rf_wdata_sel (w_rf_wdata_sel),
        .o_instr_done   (w_instr_done),
        .o_state_dbg    (w_state_dbg)
    );

    datapath U_DP (
        .clk            (clk),
        .rst            (rst),
        .i_mem_rdata    (i_mem_rdata),
        .i_pc_we        (w_pc_we),
        .i_pc_we_cond   (w_pc_we_cond),
        .i_pc_src_sel   (w_pc_src_sel),
        .i_pc_jalr_mask (w_pc_jalr_mask),
        .i_old_pc_we    (w_old_pc_we),
        .i_ir_we        (w_ir_we),
        .i_mdr_we       (w_mdr_we),
        .i_a_we         (w_a_we),
        .i_b_we         (w_b_we),
        .i_alu_out_we   (w_alu_out_we),
        .i_rf_we        (w_rf_we),
        .i_mem_addr_sel (w_mem_addr_sel),
        .i_mem_fetch_word(w_mem_fetch_word),
        .i_alu_src_a_sel(w_alu_src_a_sel),
        .i_alu_src_b_sel(w_alu_src_b_sel),
        .i_alu_control  (w_alu_control),
        .i_rf_wdata_sel (w_rf_wdata_sel),
        .o_mem_addr     (o_mem_addr),
        .o_mem_wdata    (o_mem_wdata),
        .o_mem_funct3   (o_mem_funct3),
        .o_opcode       (w_opcode),
        .o_funct3       (w_funct3),
        .o_funct7       (w_funct7),
        .o_pc_data      (o_pc_data),
        .o_branch_taken (w_branch_taken),
        .o_commit_valid (o_commit_valid),
        .o_commit_rd    (o_commit_rd),
        .o_commit_wdata (o_commit_wdata)
    );

    assign o_instr_done = w_instr_done;
    assign o_state_dbg  = w_state_dbg;

endmodule

