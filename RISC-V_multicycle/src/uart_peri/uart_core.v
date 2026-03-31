`timescale 1ns / 1ps

module uart_core #(
    parameter integer CLK_FREQ_HZ   = 100_000_000,
    parameter integer BAUD_RATE     = 3000000,
    parameter integer TX_FIFO_DEPTH = 16,
    parameter integer RX_FIFO_DEPTH = 32
) (
    input        clk,
    input        reset,
    input  [3:0] i_baud_sel,
    input        i_uart_rx,
    output       o_uart_tx,
    input        i_tx_push,
    input  [7:0] i_tx_data,
    output       o_tx_full,
    output       o_tx_empty,
    input        i_rx_pop,
    output [7:0] o_rx_data,
    output       o_rx_full,
    output       o_rx_empty,
    output       o_tx_busy,
    output       o_rx_overflow,
    output       o_frame_error,
    input        i_clear_overflow,
    input        i_clear_frame_error
);

    wire [7:0] w_tx_fifo_data;
    wire       w_tx_fifo_full;
    wire       w_tx_fifo_empty;
    wire       w_tx_start;
    wire [7:0] w_uart_rx_data;
    wire       w_uart_rx_done;
    wire       w_uart_frame_error;
    wire       w_rx_fifo_full;
    wire       w_rx_fifo_empty;
    wire       w_rx_push;

    reg        r_rx_overflow;
    reg        r_frame_error;

    assign w_tx_start = (!w_tx_fifo_empty) && (!o_tx_busy);
    assign w_rx_push  = w_uart_rx_done && (!w_rx_fifo_full);

    Top_FIFO #(
        .Data_Width   (8),
        .Address_Depth(TX_FIFO_DEPTH)
    ) U_TX_FIFO (
        .clk    (clk),
        .rst    (reset),
        .i_push (i_tx_push),
        .i_pop  (w_tx_start),
        .i_data (i_tx_data),
        .o_data (w_tx_fifo_data),
        .o_full (w_tx_fifo_full),
        .o_empty(w_tx_fifo_empty)
    );

    Top_FIFO #(
        .Data_Width   (8),
        .Address_Depth(RX_FIFO_DEPTH)
    ) U_RX_FIFO (
        .clk    (clk),
        .rst    (reset),
        .i_push (w_rx_push),
        .i_pop  (i_rx_pop),
        .i_data (w_uart_rx_data),
        .o_data (o_rx_data),
        .o_full (w_rx_fifo_full),
        .o_empty(w_rx_fifo_empty)
    );

    Top_uart #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) U_UART (
        .clk      (clk),
        .reset    (reset),
        .i_baud_sel(i_baud_sel),
        .i_tx_data(w_tx_fifo_data),
        .i_tx_start(w_tx_start),
        .i_uart_rx(i_uart_rx),
        .o_uart_tx(o_uart_tx),
        .o_rx_data(w_uart_rx_data),
        .o_rx_done(w_uart_rx_done),
        .o_tx_busy(o_tx_busy),
        .o_frame_error(w_uart_frame_error)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_rx_overflow <= 1'b0;
            r_frame_error <= 1'b0;
        end else begin
            if (i_clear_overflow) begin
                r_rx_overflow <= 1'b0;
            end else if (w_uart_rx_done && w_rx_fifo_full) begin
                r_rx_overflow <= 1'b1;
            end

            if (i_clear_frame_error) begin
                r_frame_error <= 1'b0;
            end else if (w_uart_frame_error) begin
                r_frame_error <= 1'b1;
            end
        end
    end

    assign o_tx_full     = w_tx_fifo_full;
    assign o_tx_empty    = w_tx_fifo_empty;
    assign o_rx_full     = w_rx_fifo_full;
    assign o_rx_empty    = w_rx_fifo_empty;
    assign o_rx_overflow = r_rx_overflow;
    assign o_frame_error = r_frame_error;

endmodule
