`timescale 1ns / 1ps

module apb_mmio_bridge #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int STRB_WIDTH = DATA_WIDTH / 8,
    parameter int NUM_SLAVES = 5,
    parameter logic [NUM_SLAVES-1:0][ADDR_WIDTH-1:0] SLAVE_BASE = {
        32'h2000_0000,
        32'h2000_1000,
        32'h2000_2000,
        32'h2000_3000,
        32'h2000_4000
    },
    parameter logic [NUM_SLAVES-1:0][ADDR_WIDTH-1:0] SLAVE_MASK = {
        32'hFFFF_F000,
        32'hFFFF_F000,
        32'hFFFF_F000,
        32'hFFFF_F000,
        32'hFFFF_F000
    }
) (
    input  logic                         PCLK,
    input  logic                         PRESETn,

    input  logic                         req_valid,
    output logic                         req_ready,
    input  logic [ADDR_WIDTH-1:0]        req_addr,
    input  logic                         req_write,
    input  logic [DATA_WIDTH-1:0]        req_wdata,
    input  logic [STRB_WIDTH-1:0]        req_strb,
    input  logic [2:0]                   req_prot,

    output logic                         rsp_valid,
    output logic [DATA_WIDTH-1:0]        rsp_rdata,
    output logic                         rsp_err,

    output logic [ADDR_WIDTH-1:0]        PADDR,
    output logic                         PWRITE,
    output logic                         PENABLE,
    output logic [DATA_WIDTH-1:0]        PWDATA,
    output logic [STRB_WIDTH-1:0]        PSTRB,
    output logic [2:0]                   PPROT,
    output logic [NUM_SLAVES-1:0]        PSEL,

    input  logic [NUM_SLAVES-1:0][DATA_WIDTH-1:0] PRDATA,
    input  logic [NUM_SLAVES-1:0]                 PREADY,
    input  logic [NUM_SLAVES-1:0]                 PSLVERR
);

    typedef enum logic [1:0] {
        ST_IDLE,
        ST_SETUP,
        ST_ACCESS
    } apb_state_t;

    apb_state_t state_q, state_d;

    logic [ADDR_WIDTH-1:0] req_addr_q, req_addr_d;
    logic [DATA_WIDTH-1:0] req_wdata_q, req_wdata_d;
    logic [STRB_WIDTH-1:0] req_strb_q, req_strb_d;
    logic [2:0]            req_prot_q, req_prot_d;
    logic                  req_write_q, req_write_d;
    logic [NUM_SLAVES-1:0] psel_q, psel_d;

    logic [DATA_WIDTH-1:0] active_prdata;
    logic                  active_pready;
    logic                  active_pslverr;
    logic                  decode_miss;
    logic                  decode_overlap;

    function automatic logic has_multiple_hits (
        input logic [NUM_SLAVES-1:0] sel_vec
    );
        logic seen_one;
        int i;
        begin
            seen_one = 1'b0;
            has_multiple_hits = 1'b0;
            for (i = 0; i < NUM_SLAVES; i = i + 1) begin
                if (sel_vec[i]) begin
                    if (seen_one) begin
                        has_multiple_hits = 1'b1;
                    end
                    seen_one = 1'b1;
                end
            end
        end
    endfunction

    function automatic logic [NUM_SLAVES-1:0] decode_psel (
        input logic [ADDR_WIDTH-1:0] addr
    );
        logic [NUM_SLAVES-1:0] hit_vec;
        int i;
        begin
            hit_vec = '0;
            for (i = 0; i < NUM_SLAVES; i++) begin
                if ((addr & SLAVE_MASK[i]) == (SLAVE_BASE[i] & SLAVE_MASK[i])) begin
                    hit_vec[i] = 1'b1;
                end
            end
            return hit_vec;
        end
    endfunction

    always_comb begin
        active_prdata  = '0;
        active_pready  = 1'b1;
        active_pslverr = 1'b0;
        for (int i = 0; i < NUM_SLAVES; i++) begin
            if (psel_q[i]) begin
                active_prdata  = PRDATA[i];
                active_pready  = PREADY[i];
                active_pslverr = PSLVERR[i];
            end
        end
    end

    assign decode_miss = (psel_q == '0);
    assign decode_overlap = has_multiple_hits(psel_q);

    always_comb begin
        state_d     = state_q;
        req_addr_d  = req_addr_q;
        req_wdata_d = req_wdata_q;
        req_strb_d  = req_strb_q;
        req_prot_d  = req_prot_q;
        req_write_d = req_write_q;
        psel_d      = psel_q;

        req_ready   = 1'b0;
        rsp_valid   = 1'b0;
        rsp_rdata   = active_prdata;
        rsp_err     = 1'b0;

        PADDR       = req_addr_q;
        PWDATA      = req_wdata_q;
        PWRITE      = req_write_q;
        PSTRB       = req_write_q ? req_strb_q : '0;
        PPROT       = req_prot_q;
        PENABLE     = 1'b0;
        PSEL        = '0;

        case (state_q)
            ST_IDLE: begin
                req_ready = 1'b1;
                if (req_valid) begin
                    req_addr_d  = req_addr;
                    req_wdata_d = req_wdata;
                    req_strb_d  = req_write ? req_strb : '0;
                    req_prot_d  = req_prot;
                    req_write_d = req_write;
                    psel_d      = decode_psel(req_addr);
                    state_d     = ST_SETUP;
                end
            end

            ST_SETUP: begin
                PADDR   = req_addr_q;
                PWDATA  = req_wdata_q;
                PWRITE  = req_write_q;
                PSTRB   = req_write_q ? req_strb_q : '0;
                PPROT   = req_prot_q;
                PSEL    = psel_q;
                state_d = ST_ACCESS;
            end

            ST_ACCESS: begin
                PADDR   = req_addr_q;
                PWDATA  = req_wdata_q;
                PWRITE  = req_write_q;
                PSTRB   = req_write_q ? req_strb_q : '0;
                PPROT   = req_prot_q;
                PSEL    = psel_q;
                PENABLE = 1'b1;

                if (decode_miss || decode_overlap) begin
                    rsp_valid = 1'b1;
                    rsp_rdata = '0;
                    rsp_err   = 1'b1;
                    state_d   = ST_IDLE;
                end else if (active_pready) begin
                    rsp_valid = 1'b1;
                    rsp_rdata = active_prdata;
                    rsp_err   = active_pslverr;
                    state_d   = ST_IDLE;
                end
            end

            default: begin
                state_d = ST_IDLE;
            end
        endcase
    end

    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            state_q     <= ST_IDLE;
            req_addr_q  <= '0;
            req_wdata_q <= '0;
            req_strb_q  <= '0;
            req_prot_q  <= 3'b000;
            req_write_q <= 1'b0;
            psel_q      <= '0;
        end else begin
            state_q     <= state_d;
            req_addr_q  <= req_addr_d;
            req_wdata_q <= req_wdata_d;
            req_strb_q  <= req_strb_d;
            req_prot_q  <= req_prot_d;
            req_write_q <= req_write_d;
            psel_q      <= psel_d;
        end
    end

endmodule
