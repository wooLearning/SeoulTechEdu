`timescale 1ns / 1ps

module APB_master #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int NUM_SLAVES = 6,
    parameter logic [NUM_SLAVES-1:0][ADDR_WIDTH-1:0] SLAVE_BASE = {
        32'h1000_0000,
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
        32'hFFFF_F000,
        32'hFFFF_F000
    }
) (
    input  logic                  PCLK,
    input  logic                  PRESET,

    input  logic [ADDR_WIDTH-1:0] Addr,
    input  logic [DATA_WIDTH-1:0] Wdata,
    input  logic                  WREQ,
    input  logic                  RREQ,
    output logic [DATA_WIDTH-1:0] Rdata,
    output logic                  Ready,
    output logic                  SlvERR,

    output logic [ADDR_WIDTH-1:0] PADDR,
    output logic [DATA_WIDTH-1:0] PWDATA,
    output logic                  PENABLE,
    output logic                  PWRITE,
    output logic [DATA_WIDTH/8-1:0] PSTRB,
    output logic [2:0]            PPROT,
    output logic                  PSEL0,
    output logic                  PSEL1,
    output logic                  PSEL2,
    output logic                  PSEL3,
    output logic                  PSEL4,
    output logic                  PSEL5,

    input  logic [DATA_WIDTH-1:0] PRDATA0,
    input  logic [DATA_WIDTH-1:0] PRDATA1,
    input  logic [DATA_WIDTH-1:0] PRDATA2,
    input  logic [DATA_WIDTH-1:0] PRDATA3,
    input  logic [DATA_WIDTH-1:0] PRDATA4,
    input  logic [DATA_WIDTH-1:0] PRDATA5,
    input  logic                  PREADY0,
    input  logic                  PREADY1,
    input  logic                  PREADY2,
    input  logic                  PREADY3,
    input  logic                  PREADY4,
    input  logic                  PREADY5,
    input  logic                  PSLVERR0,
    input  logic                  PSLVERR1,
    input  logic                  PSLVERR2,
    input  logic                  PSLVERR3,
    input  logic                  PSLVERR4,
    input  logic                  PSLVERR5
);

    logic req_valid;
    logic req_ready;
    logic rsp_valid;
    logic rsp_err;
    logic [NUM_SLAVES-1:0]                 psel_bus;
    logic [NUM_SLAVES-1:0][DATA_WIDTH-1:0] prdata_bus;
    logic [NUM_SLAVES-1:0]                 pready_bus;
    logic [NUM_SLAVES-1:0]                 pslverr_bus;

    assign req_valid = WREQ | RREQ;
    assign Ready     = rsp_valid;
    assign SlvERR    = rsp_err;

    assign PSEL0 = psel_bus[0];
    assign PSEL1 = psel_bus[1];
    assign PSEL2 = psel_bus[2];
    assign PSEL3 = psel_bus[3];
    assign PSEL4 = psel_bus[4];
    assign PSEL5 = psel_bus[5];

    assign prdata_bus[0] = PRDATA0;
    assign prdata_bus[1] = PRDATA1;
    assign prdata_bus[2] = PRDATA2;
    assign prdata_bus[3] = PRDATA3;
    assign prdata_bus[4] = PRDATA4;
    assign prdata_bus[5] = PRDATA5;

    assign pready_bus[0] = PREADY0;
    assign pready_bus[1] = PREADY1;
    assign pready_bus[2] = PREADY2;
    assign pready_bus[3] = PREADY3;
    assign pready_bus[4] = PREADY4;
    assign pready_bus[5] = PREADY5;

    assign pslverr_bus[0] = PSLVERR0;
    assign pslverr_bus[1] = PSLVERR1;
    assign pslverr_bus[2] = PSLVERR2;
    assign pslverr_bus[3] = PSLVERR3;
    assign pslverr_bus[4] = PSLVERR4;
    assign pslverr_bus[5] = PSLVERR5;

    apb_mmio_bridge #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .STRB_WIDTH(DATA_WIDTH / 8),
        .NUM_SLAVES(NUM_SLAVES),
        .SLAVE_BASE(SLAVE_BASE),
        .SLAVE_MASK(SLAVE_MASK)
    ) u_bridge (
        .PCLK(PCLK),
        .PRESETn(~PRESET),
        .req_valid(req_valid),
        .req_ready(req_ready),
        .req_addr(Addr),
        .req_write(WREQ),
        .req_wdata(Wdata),
        .req_strb(WREQ ? '1 : '0),
        .req_prot(3'b000),
        .rsp_valid(rsp_valid),
        .rsp_rdata(Rdata),
        .rsp_err(rsp_err),
        .PADDR(PADDR),
        .PWRITE(PWRITE),
        .PENABLE(PENABLE),
        .PWDATA(PWDATA),
        .PSTRB(PSTRB),
        .PPROT(PPROT),
        .PSEL(psel_bus),
        .PRDATA(prdata_bus),
        .PREADY(pready_bus),
        .PSLVERR(pslverr_bus)
    );

endmodule
