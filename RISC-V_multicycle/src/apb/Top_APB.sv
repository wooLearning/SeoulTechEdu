`timescale 1ns / 1ps

// APB: MMIO bus wrapper around the existing APB master/bridge design.
module Top_APB (
    input  logic        clk,
    input  logic        rst,
    input  logic        i_req_valid,
    input  logic        i_req_write,
    input  logic [31:0] i_req_addr,
    input  logic [31:0] i_req_wdata,
    input  logic [ 2:0] i_req_funct3,
    input  logic [ 3:0] i_baud_sel,
    input  logic        i_uart_rx,
    input  logic [15:0] i_gpi,
    output logic [15:0] io_gpo,
    inout  wire [ 3:0]  io_gpio,
    output logic [ 6:0] o_fnd_seg,
    output logic        o_fnd_dp,
    output logic [ 3:0] o_fnd_an,
    output logic        o_uart_tx,
    output logic        o_rsp_valid,
    output logic [31:0] o_rsp_rdata,
    output logic        o_rsp_error
);

    logic        w_wreq;
    logic        w_rreq;
    logic [31:0] w_rdata;
    logic        w_ready;
    logic        w_slverr;

    logic [31:0] w_paddr;
    logic [31:0] w_pwdata;
    logic        w_penable;
    logic        w_pwrite;
    logic [3:0]  w_pstrb;
    logic [2:0]  w_pprot;
    logic        w_psel0;
    logic        w_psel1;
    logic        w_psel2;
    logic        w_psel3;
    logic        w_psel4;
    logic        w_psel5;

    logic [31:0] w_prdata0;
    logic [31:0] w_prdata1;
    logic [31:0] w_prdata2;
    logic [31:0] w_prdata3;
    logic [31:0] w_prdata4;
    logic [31:0] w_prdata5;
    logic        w_pready0;
    logic        w_pready1;
    logic        w_pready2;
    logic        w_pready3;
    logic        w_pready4;
    logic        w_pready5;
    logic        w_pslverr0;
    logic        w_pslverr1;
    logic        w_pslverr2;
    logic        w_pslverr3;
    logic        w_pslverr4;
    logic        w_pslverr5;

    tri   [15:0] w_gpio_bus;

    assign w_wreq = i_req_valid && i_req_write;
    assign w_rreq = i_req_valid && !i_req_write;

    assign o_rsp_valid = w_ready;
    assign o_rsp_rdata = w_rdata;
    assign o_rsp_error = w_slverr;

    APB_master #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .NUM_SLAVES(6),
        .SLAVE_BASE({
            32'h2000_4000,
            32'h2000_3000,
            32'h2000_2000,
            32'h2000_1000,
            32'h2000_0000,
            32'h3000_0000
        }),
        .SLAVE_MASK({
            32'hFFFF_F000,
            32'hFFFF_F000,
            32'hFFFF_F000,
            32'hFFFF_F000,
            32'hFFFF_F000,
            32'hFFFF_F000
        })
    ) U_APB_MASTER (
        .PCLK    (clk),
        .PRESET  (rst),
        .Addr    (i_req_addr),
        .Wdata   (i_req_wdata),
        .WREQ    (w_wreq),
        .RREQ    (w_rreq),
        .Rdata   (w_rdata),
        .Ready   (w_ready),
        .SlvERR  (w_slverr),
        .PADDR   (w_paddr),
        .PWDATA  (w_pwdata),
        .PENABLE (w_penable),
        .PWRITE  (w_pwrite),
        .PSTRB   (w_pstrb),
        .PPROT   (w_pprot),
        .PSEL0   (w_psel0),
        .PSEL1   (w_psel1),
        .PSEL2   (w_psel2),
        .PSEL3   (w_psel3),
        .PSEL4   (w_psel4),
        .PSEL5   (w_psel5),
        .PRDATA0 (w_prdata0),
        .PRDATA1 (w_prdata1),
        .PRDATA2 (w_prdata2),
        .PRDATA3 (w_prdata3),
        .PRDATA4 (w_prdata4),
        .PRDATA5 (w_prdata5),
        .PREADY0 (w_pready0),
        .PREADY1 (w_pready1),
        .PREADY2 (w_pready2),
        .PREADY3 (w_pready3),
        .PREADY4 (w_pready4),
        .PREADY5 (w_pready5),
        .PSLVERR0(w_pslverr0),
        .PSLVERR1(w_pslverr1),
        .PSLVERR2(w_pslverr2),
        .PSLVERR3(w_pslverr3),
        .PSLVERR4(w_pslverr4),
        .PSLVERR5(w_pslverr5)
    );

    assign w_prdata0  = 32'h0000_0000;
    assign w_pready0  = 1'b1;
    assign w_pslverr0 = 1'b1;

    gpo_apb_wrapper U_GPO (
        .pclk    (clk),
        .presetn (~rst),
        .paddr   (w_paddr[7:0]),
        .psel    (w_psel1),
        .penable (w_penable),
        .pwrite  (w_pwrite),
        .pwdata  (w_pwdata),
        .pstrb   (w_pstrb),
        .pready  (w_pready1),
        .prdata  (w_prdata1),
        .pslverr (w_pslverr1),
        .io_gpo  (io_gpo)
    );

    gpi_apb_wrapper U_GPI (
        .pclk    (clk),
        .presetn (~rst),
        .paddr   (w_paddr[7:0]),
        .psel    (w_psel2),
        .penable (w_penable),
        .pwrite  (w_pwrite),
        .pwdata  (w_pwdata),
        .pstrb   (w_pstrb),
        .pready  (w_pready2),
        .prdata  (w_prdata2),
        .pslverr (w_pslverr2),
        .i_gpi   (i_gpi)
    );

    gpio_apb_wrapper U_GPIO (
        .pclk    (clk),
        .presetn (~rst),
        .paddr   (w_paddr[7:0]),
        .psel    (w_psel3),
        .penable (w_penable),
        .pwrite  (w_pwrite),
        .pwdata  (w_pwdata),
        .pstrb   (w_pstrb),
        .pready  (w_pready3),
        .prdata  (w_prdata3),
        .pslverr (w_pslverr3),
        .io_gpio (w_gpio_bus)
    );

    assign io_gpio       = w_gpio_bus[3:0];
    assign w_gpio_bus[3:0] = io_gpio;
    assign w_gpio_bus[15:4] = 12'hZZZ;

    fnd_apb_wrapper #(
        .CLK_FREQ_HZ(100_000_000)
    ) U_FND (
        .pclk     (clk),
        .presetn  (~rst),
        .paddr    (w_paddr[7:0]),
        .psel     (w_psel4),
        .penable  (w_penable),
        .pwrite   (w_pwrite),
        .pwdata   (w_pwdata),
        .pstrb    (w_pstrb),
        .pready   (w_pready4),
        .prdata   (w_prdata4),
        .pslverr  (w_pslverr4),
        .o_fnd_seg(o_fnd_seg),
        .o_fnd_dp (o_fnd_dp),
        .o_fnd_an (o_fnd_an)
    );

    uart_apb_wrapper U_UART (
        .pclk     (clk),
        .presetn  (~rst),
        .paddr    (w_paddr[7:0]),
        .psel     (w_psel5),
        .penable  (w_penable),
        .pwrite   (w_pwrite),
        .pwdata   (w_pwdata),
        .pstrb    (w_pstrb),
        .pready   (w_pready5),
        .prdata   (w_prdata5),
        .pslverr  (w_pslverr5),
        .i_baud_sel(i_baud_sel),
        .i_uart_rx(i_uart_rx),
        .o_uart_tx(o_uart_tx)
    );

endmodule

