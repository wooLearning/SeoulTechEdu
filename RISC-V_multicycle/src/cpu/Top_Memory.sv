`timescale 1ns / 1ps

module Top_Memory (
    input  logic        clk,
    input  logic        rst,
    input  logic        i_req_valid,
    input  logic        i_req_write,
    input  logic [31:0] i_req_addr,
    input  logic [31:0] i_req_wdata,
    input  logic [ 2:0] i_req_funct3,
    input  logic [ 7:0] i_dbg_result_idx,
    output logic        o_rsp_valid,
    output logic [31:0] o_rsp_rdata,
    output logic        o_rsp_error,
    output logic [31:0] o_dbg_result_word
);

    localparam logic [31:0] ROM_BASE  = 32'h0000_0000;
    localparam logic [31:0] RAM_BASE  = 32'h1000_0000;
    localparam integer MEM_BYTES = 1024 * 4;

    logic        w_rom_hit;
    logic        w_ram_hit;
    logic        w_rom_req;
    logic        w_ram_req;
    logic [31:0] w_rom_rdata;
    logic        w_rom_rsp_valid;
    logic [31:0] w_ram_rdata;
    logic        w_ram_rsp_valid;
    logic [31:0] w_dbg_result_word;
    logic        r_error_q;

    assign w_rom_hit = (i_req_addr >= ROM_BASE) && (i_req_addr < ROM_BASE + MEM_BYTES);
    assign w_ram_hit = (i_req_addr >= RAM_BASE) && (i_req_addr < RAM_BASE + MEM_BYTES);
    assign w_rom_req = i_req_valid && !i_req_write && w_rom_hit;
    assign w_ram_req = i_req_valid && w_ram_hit;

    rom_table U_ROM (
        .clk        (clk),
        .i_req_valid(w_rom_req),
        .i_addr     (i_req_addr),
        .i_funct3   (i_req_funct3),
        .o_rsp_valid(w_rom_rsp_valid),
        .o_rdata    (w_rom_rdata)
    );

    data_memory U_RAM (
        .clk           (clk),
        .i_req_valid   (w_ram_req),
        .i_req_write   (i_req_write),
        .i_addr        (i_req_addr),
        .i_wdata       (i_req_wdata),
        .i_funct3      (i_req_funct3),
        .i_dbg_word_idx(i_dbg_result_idx),
        .o_rsp_valid   (w_ram_rsp_valid),
        .o_rdata       (w_ram_rdata),
        .o_dbg_word    (w_dbg_result_word)
    );

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            r_error_q <= 1'b0;
        end else begin
            r_error_q <= i_req_valid && ((!w_rom_hit && !w_ram_hit) || (w_rom_hit && i_req_write));
        end
    end

    always_comb begin
        o_rsp_valid = 1'b0;
        o_rsp_rdata = 32'h0000_0000;
        o_rsp_error = 1'b0;

        if (w_rom_rsp_valid) begin
            o_rsp_valid = 1'b1;
            o_rsp_rdata = w_rom_rdata;
        end else if (w_ram_rsp_valid) begin
            o_rsp_valid = 1'b1;
            o_rsp_rdata = w_ram_rdata;
        end else if (r_error_q) begin
            o_rsp_valid = 1'b1;
            o_rsp_error = 1'b1;
        end
    end

    assign o_dbg_result_word = w_dbg_result_word;

endmodule

