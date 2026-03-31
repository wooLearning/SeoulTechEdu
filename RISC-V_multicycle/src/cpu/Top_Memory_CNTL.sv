`timescale 1ns / 1ps

module Top_Memory_CNTL (
    input  logic        clk,
    input  logic        rst,
    input  logic        i_req_valid,
    input  logic        i_req_write,
    input  logic [31:0] i_req_addr,
    input  logic [31:0] i_req_wdata,
    input  logic [ 2:0] i_req_funct3,
    output logic        o_rsp_valid,
    output logic [31:0] o_rsp_rdata,
    output logic        o_rsp_error,
    output logic        o_mem_req_valid,
    output logic        o_mem_req_write,
    output logic [31:0] o_mem_req_addr,
    output logic [31:0] o_mem_req_wdata,
    output logic [ 2:0] o_mem_req_funct3,
    input  logic        i_mem_rsp_valid,
    input  logic [31:0] i_mem_rsp_rdata,
    input  logic        i_mem_rsp_error,
    output logic        o_apb_req_valid,
    output logic        o_apb_req_write,
    output logic [31:0] o_apb_req_addr,
    output logic [31:0] o_apb_req_wdata,
    output logic [ 2:0] o_apb_req_funct3,
    input  logic        i_apb_rsp_valid,
    input  logic [31:0] i_apb_rsp_rdata,
    input  logic        i_apb_rsp_error
);

    localparam logic [31:0] ROM_BASE   = 32'h0000_0000;
    localparam logic [31:0] ROM_BYTES  = 32'h0000_1000;
    localparam logic [31:0] RAM_BASE   = 32'h1000_0000;
    localparam logic [31:0] RAM_BYTES  = 32'h0000_1000;
    localparam logic [31:0] MMIO_BASE  = 32'h2000_0000;
    localparam logic [31:0] MMIO_BYTES = 32'h0000_5000;

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_MEM_START,
        ST_MEM_WAIT,
        ST_APB_START,
        ST_APB_WAIT,
        ST_ERROR
    } state_t;

    state_t state_q, state_d;

    logic        req_write_q, req_write_d;
    logic [31:0] req_addr_q, req_addr_d;
    logic [31:0] req_wdata_q, req_wdata_d;
    logic [ 2:0] req_funct3_q, req_funct3_d;

    logic w_target_mem;
    logic w_target_apb;
    logic w_addr_misaligned;
    logic w_size_invalid;

    function automatic logic is_misaligned(
        input logic [2:0]  funct3,
        input logic [31:0] addr
    );
        begin
            is_misaligned = 1'b0;
            case (funct3)
                3'b001, 3'b101: is_misaligned = addr[0];
                3'b010:         is_misaligned = |addr[1:0];
                default:        is_misaligned = 1'b0;
            endcase
        end
    endfunction

    function automatic logic is_invalid_size(
        input logic       is_write,
        input logic [2:0] funct3
    );
        begin
            if (is_write) begin
                is_invalid_size = !((funct3 == 3'b000) || (funct3 == 3'b001) || (funct3 == 3'b010));
            end else begin
                is_invalid_size = !((funct3 == 3'b000) || (funct3 == 3'b001) || (funct3 == 3'b010) ||
                                    (funct3 == 3'b100) || (funct3 == 3'b101));
            end
        end
    endfunction

    assign w_target_mem = ((i_req_addr >= ROM_BASE) && (i_req_addr < ROM_BASE + ROM_BYTES)) ||
                          ((i_req_addr >= RAM_BASE) && (i_req_addr < RAM_BASE + RAM_BYTES));
    assign w_target_apb = (i_req_addr >= MMIO_BASE) && (i_req_addr < MMIO_BASE + MMIO_BYTES);
    assign w_addr_misaligned = is_misaligned(i_req_funct3, i_req_addr);
    assign w_size_invalid    = is_invalid_size(i_req_write, i_req_funct3);

    always_comb begin
        state_d      = state_q;
        req_write_d  = req_write_q;
        req_addr_d   = req_addr_q;
        req_wdata_d  = req_wdata_q;
        req_funct3_d = req_funct3_q;

        o_rsp_valid = 1'b0;
        o_rsp_rdata = 32'h0000_0000;
        o_rsp_error = 1'b0;

        o_mem_req_valid  = 1'b0;
        o_mem_req_write  = req_write_q;
        o_mem_req_addr   = req_addr_q;
        o_mem_req_wdata  = req_wdata_q;
        o_mem_req_funct3 = req_funct3_q;

        o_apb_req_valid  = 1'b0;
        o_apb_req_write  = req_write_q;
        o_apb_req_addr   = req_addr_q;
        o_apb_req_wdata  = req_wdata_q;
        o_apb_req_funct3 = req_funct3_q;

        case (state_q)
            ST_IDLE: begin
                if (i_req_valid) begin
                    req_write_d  = i_req_write;
                    req_addr_d   = i_req_addr;
                    req_wdata_d  = i_req_wdata;
                    req_funct3_d = i_req_funct3;

                    if (w_addr_misaligned || w_size_invalid || !(w_target_mem || w_target_apb)) begin
                        state_d = ST_ERROR;
                    end else if (w_target_mem) begin
                        state_d = ST_MEM_START;
                    end else begin
                        state_d = ST_APB_START;
                    end
                end
            end

            ST_MEM_START: begin
                o_mem_req_valid = 1'b1;
                if (i_mem_rsp_valid) begin
                    o_rsp_valid = 1'b1;
                    o_rsp_rdata = i_mem_rsp_rdata;
                    o_rsp_error = i_mem_rsp_error;
                    state_d     = ST_IDLE;
                end else begin
                    state_d = ST_MEM_WAIT;
                end
            end

            ST_MEM_WAIT: begin
                if (i_mem_rsp_valid) begin
                    o_rsp_valid = 1'b1;
                    o_rsp_rdata = i_mem_rsp_rdata;
                    o_rsp_error = i_mem_rsp_error;
                    state_d     = ST_IDLE;
                end
            end

            ST_APB_START: begin
                o_apb_req_valid = 1'b1;
                if (i_apb_rsp_valid) begin
                    o_rsp_valid = 1'b1;
                    o_rsp_rdata = i_apb_rsp_rdata;
                    o_rsp_error = i_apb_rsp_error;
                    state_d     = ST_IDLE;
                end else begin
                    state_d = ST_APB_WAIT;
                end
            end

            ST_APB_WAIT: begin
                if (i_apb_rsp_valid) begin
                    o_rsp_valid = 1'b1;
                    o_rsp_rdata = i_apb_rsp_rdata;
                    o_rsp_error = i_apb_rsp_error;
                    state_d     = ST_IDLE;
                end
            end

            ST_ERROR: begin
                o_rsp_valid = 1'b1;
                o_rsp_rdata = 32'h0000_0000;
                o_rsp_error = 1'b1;
                state_d     = ST_IDLE;
            end

            default: begin
                state_d = ST_IDLE;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            state_q <= ST_IDLE;
        end else begin
            state_q <= state_d;
        end
    end

    always_ff @(posedge clk) begin
        req_write_q  <= req_write_d;
        req_addr_q   <= req_addr_d;
        req_wdata_q  <= req_wdata_d;
        req_funct3_q <= req_funct3_d;
    end

endmodule

