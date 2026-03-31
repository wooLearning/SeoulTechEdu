`timescale 1ns / 1ps

module Top_module (
    input  logic        clk,
    input  logic        rst,
    input  logic        i_uart_rx,
    output logic        o_uart_tx,
    output logic [ 6:0] o_fnd_seg,
    output logic        o_fnd_dp,
    output logic [ 3:0] o_fnd_an,
    input  logic [10:0] i_gpi_sw,
    output logic [15:0] io_gpo,
    inout  wire [ 3:0]  io_gpio,
    input  logic [ 3:0] i_baud_sel
);

    logic        w_cpu_mem_valid;
    logic        w_cpu_mem_write;
    logic [31:0] w_cpu_mem_addr;
    logic [31:0] w_cpu_mem_wdata;
    logic [ 2:0] w_cpu_mem_funct3;
    logic        w_cpu_mem_ready;
    logic [31:0] w_cpu_mem_rdata;
    logic        w_cpu_mem_error;

    logic        w_mem_req_valid;
    logic        w_mem_req_write;
    logic [31:0] w_mem_req_addr;
    logic [31:0] w_mem_req_wdata;
    logic [ 2:0] w_mem_req_funct3;
    logic        w_mem_rsp_valid;
    logic [31:0] w_mem_rsp_rdata;
    logic        w_mem_rsp_error;

    logic        w_apb_req_valid;
    logic        w_apb_req_write;
    logic [31:0] w_apb_req_addr;
    logic [31:0] w_apb_req_wdata;
    logic [ 2:0] w_apb_req_funct3;
    logic        w_apb_rsp_valid;
    logic [31:0] w_apb_rsp_rdata;
    logic        w_apb_rsp_error;

    logic [31:0] w_pc_data;
    logic [31:0] w_dbg_result_word;
    logic        w_instr_done;
    logic [ 3:0] w_state_dbg;
    logic        w_commit_valid;
    logic [ 4:0] w_commit_rd;
    logic [31:0] w_commit_wdata;
    logic [63:0] w_cycle_count_q;
    logic [63:0] w_instr_count_q;
    logic [15:0] w_gpi;

    assign w_gpi = {5'b0, i_gpi_sw};

    Top_CPU U_CPU (
        .clk           (clk),
        .rst           (rst),
        .i_mem_ready   (w_cpu_mem_ready),
        .i_mem_rdata   (w_cpu_mem_rdata),
        .i_mem_error   (w_cpu_mem_error),
        .o_mem_valid   (w_cpu_mem_valid),
        .o_mem_write   (w_cpu_mem_write),
        .o_mem_addr    (w_cpu_mem_addr),
        .o_mem_wdata   (w_cpu_mem_wdata),
        .o_mem_funct3  (w_cpu_mem_funct3),
        .o_pc_data     (w_pc_data),
        .o_instr_done  (w_instr_done),
        .o_state_dbg   (w_state_dbg),
        .o_commit_valid(w_commit_valid),
        .o_commit_rd   (w_commit_rd),
        .o_commit_wdata(w_commit_wdata)
    );

    Top_Memory_CNTL U_MEMORY_CONTROLLER (
        .clk             (clk),
        .rst             (rst),
        .i_req_valid     (w_cpu_mem_valid),
        .i_req_write     (w_cpu_mem_write),
        .i_req_addr      (w_cpu_mem_addr),
        .i_req_wdata     (w_cpu_mem_wdata),
        .i_req_funct3    (w_cpu_mem_funct3),
        .o_rsp_valid     (w_cpu_mem_ready),
        .o_rsp_rdata     (w_cpu_mem_rdata),
        .o_rsp_error     (w_cpu_mem_error),
        .o_mem_req_valid (w_mem_req_valid),
        .o_mem_req_write (w_mem_req_write),
        .o_mem_req_addr  (w_mem_req_addr),
        .o_mem_req_wdata (w_mem_req_wdata),
        .o_mem_req_funct3(w_mem_req_funct3),
        .i_mem_rsp_valid (w_mem_rsp_valid),
        .i_mem_rsp_rdata (w_mem_rsp_rdata),
        .i_mem_rsp_error (w_mem_rsp_error),
        .o_apb_req_valid (w_apb_req_valid),
        .o_apb_req_write (w_apb_req_write),
        .o_apb_req_addr  (w_apb_req_addr),
        .o_apb_req_wdata (w_apb_req_wdata),
        .o_apb_req_funct3(w_apb_req_funct3),
        .i_apb_rsp_valid (w_apb_rsp_valid),
        .i_apb_rsp_rdata (w_apb_rsp_rdata),
        .i_apb_rsp_error (w_apb_rsp_error)
    );

    Top_Memory U_MEMORY (
        .clk             (clk),
        .rst             (rst),
        .i_req_valid     (w_mem_req_valid),
        .i_req_write     (w_mem_req_write),
        .i_req_addr      (w_mem_req_addr),
        .i_req_wdata     (w_mem_req_wdata),
        .i_req_funct3    (w_mem_req_funct3),
        .i_dbg_result_idx(w_gpi[7:0]),
        .o_rsp_valid     (w_mem_rsp_valid),
        .o_rsp_rdata     (w_mem_rsp_rdata),
        .o_rsp_error     (w_mem_rsp_error),
        .o_dbg_result_word(w_dbg_result_word)
    );

    Top_APB U_APB (
        .clk        (clk),
        .rst        (rst),
        .i_req_valid(w_apb_req_valid),
        .i_req_write(w_apb_req_write),
        .i_req_addr (w_apb_req_addr),
        .i_req_wdata(w_apb_req_wdata),
        .i_req_funct3(w_apb_req_funct3),
        .i_baud_sel (i_baud_sel),
        .i_uart_rx  (i_uart_rx),
        .i_gpi      (w_gpi),
        .io_gpo     (io_gpo),
        .io_gpio    (io_gpio),
        .o_fnd_seg  (o_fnd_seg),
        .o_fnd_dp   (o_fnd_dp),
        .o_fnd_an   (o_fnd_an),
        .o_uart_tx  (o_uart_tx),
        .o_rsp_valid(w_apb_rsp_valid),
        .o_rsp_rdata(w_apb_rsp_rdata),
        .o_rsp_error(w_apb_rsp_error)
    );

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            w_cycle_count_q <= 64'd0;
            w_instr_count_q <= 64'd0;
        end else begin
            w_cycle_count_q <= w_cycle_count_q + 64'd1;
            if (w_instr_done) begin
                w_instr_count_q <= w_instr_count_q + 64'd1;
            end
        end
    end

endmodule




