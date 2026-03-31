`timescale 1ns / 1ps

module uart_apb_wrapper #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 9600
) (
    input         pclk,
    input         presetn,
    input  [7:0]  paddr,
    input         psel,
    input         penable,
    input         pwrite,
    input  [31:0] pwdata,
    input  [3:0]  pstrb,
    output        pready,
    output [31:0] prdata,
    output        pslverr,
    input  [3:0]  i_baud_sel,
    input         i_uart_rx,
    output        o_uart_tx
);

    localparam [7:0] ADDR_ID      = 8'h00;
    localparam [7:0] ADDR_STATUS  = 8'h04;
    localparam [7:0] ADDR_TXDATA  = 8'h08;
    localparam [7:0] ADDR_RXDATA  = 8'h0C;
    localparam [7:0] ADDR_CONTROL = 8'h10;
    localparam [7:0] ADDR_BAUDCFG = 8'h14;
    localparam [31:0] UART_ID     = 32'h5541_5254;

    wire apb_access;
    wire wr_en;
    wire rd_en;
    wire addr_known;
    wire tx_push;
    wire rx_pop;
    wire clear_overflow;
    wire clear_frame_error;
    wire [7:0] w_rx_data;
    wire       w_tx_full;
    wire       w_tx_empty;
    wire       w_rx_full;
    wire       w_rx_empty;
    wire       w_tx_busy;
    wire       w_rx_overflow;
    wire       w_frame_error;
    wire [3:0] w_uart_baud_sel;

    reg  [31:0] r_prdata;
    reg         r_pslverr;
    reg  [3:0]  r_apb_baud_sel;
    reg         r_baud_source_sel;

    assign apb_access = psel & penable;
    assign wr_en      = apb_access & pwrite;
    assign rd_en      = apb_access & ~pwrite;
    assign pready     = 1'b1;

    assign addr_known = (paddr == ADDR_ID)      |
                        (paddr == ADDR_STATUS)  |
                        (paddr == ADDR_TXDATA)  |
                        (paddr == ADDR_RXDATA)  |
                        (paddr == ADDR_CONTROL) |
                        (paddr == ADDR_BAUDCFG);

    assign tx_push = wr_en && (paddr == ADDR_TXDATA) && pstrb[0] && !w_tx_full;
    assign rx_pop  = rd_en && (paddr == ADDR_RXDATA) && !w_rx_empty;
    assign clear_overflow    = wr_en && (paddr == ADDR_CONTROL) && pstrb[0] && pwdata[0];
    assign clear_frame_error = wr_en && (paddr == ADDR_CONTROL) && pstrb[0] && pwdata[1];
    assign w_uart_baud_sel   = (r_baud_source_sel) ? r_apb_baud_sel : i_baud_sel;

    uart_core #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) U_UART_CORE (
        .clk                (pclk),
        .reset              (~presetn),
        .i_baud_sel         (w_uart_baud_sel),
        .i_uart_rx          (i_uart_rx),
        .o_uart_tx          (o_uart_tx),
        .i_tx_push          (tx_push),
        .i_tx_data          (pwdata[7:0]),
        .o_tx_full          (w_tx_full),
        .o_tx_empty         (w_tx_empty),
        .i_rx_pop           (rx_pop),
        .o_rx_data          (w_rx_data),
        .o_rx_full          (w_rx_full),
        .o_rx_empty         (w_rx_empty),
        .o_tx_busy          (w_tx_busy),
        .o_rx_overflow      (w_rx_overflow),
        .o_frame_error      (w_frame_error),
        .i_clear_overflow   (clear_overflow),
        .i_clear_frame_error(clear_frame_error)
    );

    always @(*) begin
        r_prdata  = 32'h0000_0000;
        r_pslverr = 1'b0;

        if (apb_access && !addr_known) begin
            r_pslverr = 1'b1;
        end else begin
            case (paddr)
                ADDR_ID: begin
                    r_prdata = UART_ID;
                end
                ADDR_STATUS: begin
                    r_prdata[0] = w_tx_full;
                    r_prdata[1] = w_tx_empty;
                    r_prdata[2] = w_rx_full;
                    r_prdata[3] = w_rx_empty;
                    r_prdata[4] = w_tx_busy;
                    r_prdata[5] = w_rx_overflow;
                    r_prdata[6] = w_frame_error;
                end
                ADDR_TXDATA: begin
                    if (wr_en && w_tx_full) r_pslverr = 1'b1;
                end
                ADDR_RXDATA: begin
                    r_prdata = {24'h000000, w_rx_data};
                    if (rd_en && w_rx_empty) r_pslverr = 1'b1;
                end
                ADDR_CONTROL: begin
                    r_prdata[0] = w_rx_overflow;
                    r_prdata[1] = w_frame_error;
                end
                ADDR_BAUDCFG: begin
                    r_prdata[3:0]  = r_apb_baud_sel;
                    r_prdata[4]    = r_baud_source_sel;
                    r_prdata[11:8] = w_uart_baud_sel;
                end
                default: begin
                    r_prdata = 32'h0000_0000;
                end
            endcase
        end
    end

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            r_apb_baud_sel    <= 4'd5;
            r_baud_source_sel <= 1'b0;
        end else if (wr_en && (paddr == ADDR_BAUDCFG) && pstrb[0]) begin
            r_apb_baud_sel    <= pwdata[3:0];
            r_baud_source_sel <= pwdata[4];
        end
    end

    assign prdata  = r_prdata;
    assign pslverr = r_pslverr;

endmodule
