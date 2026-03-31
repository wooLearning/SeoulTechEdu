`timescale 1ns / 1ps

module Top_uart #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 9600
) (
    input        clk,
    input        reset,
    input  [3:0] i_baud_sel,
    input  [7:0] i_tx_data,
    input        i_tx_start,
    input        i_uart_rx,
    output       o_uart_tx,
    output [7:0] o_rx_data,
    output       o_rx_done,
    output       o_tx_busy,
    output       o_frame_error
);

    wire w_b_tick;

    tx U_TX (
        .clk       (clk),
        .reset     (reset),
        .i_tx_data (i_tx_data),
        .baud_tick (w_b_tick),
        .i_tx_start(i_tx_start),
        .o_tx_data (o_uart_tx),
        .o_tx_done (),
        .o_tx_busy (o_tx_busy)
    );

    rx U_RX (
        .clk      (clk),
        .reset    (reset),
        .i_rx_data(i_uart_rx),
        .baud_tick(w_b_tick),
        .o_rx_data(o_rx_data),
        .o_rx_done(o_rx_done),
        .o_frame_error(o_frame_error)
    );

    // Baud_tick
    baud_tick_16 #(
        .SYS_CLK(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) U_BAUD_TICK_16 (
        .clk      (clk),
        .reset    (reset),
        .i_baud_sel(i_baud_sel),
        .baud_tick(w_b_tick)
    );



endmodule
