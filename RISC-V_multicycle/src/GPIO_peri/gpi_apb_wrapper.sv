`timescale 1ns / 1ps

module gpi_apb_wrapper (
    input  logic        pclk,
    input  logic        presetn,
    input  logic [ 7:0] paddr,
    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    input  logic [31:0] pwdata,
    input  logic [ 3:0] pstrb,
    output logic        pready,
    output logic [31:0] prdata,
    output logic        pslverr,
    input  logic [15:0] i_gpi
);

    localparam [7:0] GPI_CTL_ADDR   = 8'h00;
    localparam [7:0] GPI_IDATA_ADDR = 8'h04;

    logic [31:0] core_prdata;
    logic        core_pready;
    logic        apb_access;
    logic        valid_addr;
    logic        valid_write_addr;

    assign apb_access      = psel & penable;
    assign valid_addr      = (paddr == GPI_CTL_ADDR) | (paddr == GPI_IDATA_ADDR);
    assign valid_write_addr = (paddr == GPI_CTL_ADDR);

    GPI U_GPI_CORE (
        .PCLK   (pclk),
        .PRESET (~presetn),
        .PADDR  ({24'h0, paddr}),
        .PWDATA (pwdata),
        .PENABLE(penable),
        .PWRITE (pwrite),
        .PSEL   (psel),
        .GPI    (i_gpi),
        .PRDATA (core_prdata),
        .PREADY (core_pready)
    );

    always_comb begin
        pready  = core_pready;
        prdata  = valid_addr ? core_prdata : 32'h0000_0000;
        pslverr = 1'b0;

        if (apb_access && !valid_addr) begin
            pslverr = 1'b1;
        end

        if (apb_access && pwrite && !valid_write_addr) begin
            pslverr = 1'b1;
        end

        if (apb_access && pwrite && !pstrb[1:0]) begin
            pslverr = 1'b1;
        end
    end

endmodule
