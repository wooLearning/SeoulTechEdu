`timescale 1ns / 1ps

/*
[MODULE_INFO_START]
Name: fnd_counter_core
Role: RTL module implementing the minimum 4-digit FND counter
Summary:
  - Counts only while i_run is high
  - Uses a fixed centisecond tick and scans 4 decimal digits
StateDescription:
  - Running: increments the displayed value every fixed tick
  - Stopped: holds the current display value
[MODULE_INFO_END]
*/

module fnd_counter_core #(
    parameter int CLK_FREQ_HZ = 100_000_000,
    parameter int REFRESH_DIGIT_HZ = 1000,
    parameter int COUNT_TICK_CYCLES = 1_000_000
) (
    input  logic       clk,
    input  logic       rst,
    input  logic       i_run,
    output logic [6:0] o_seg,
    output logic       o_dp,
    output logic [3:0] o_an
);

    localparam int MAX_COUNT         = 9999;
    localparam int REFRESH_DIVIDER   = (CLK_FREQ_HZ / (REFRESH_DIGIT_HZ * 4) > 0) ? (CLK_FREQ_HZ / (REFRESH_DIGIT_HZ * 4)) : 1;
    localparam int FIXED_TICK_CYCLES = (COUNT_TICK_CYCLES > 0) ? COUNT_TICK_CYCLES : 1;

    logic [31:0] r_count;
    logic [31:0] r_tick_count;
    logic [31:0] r_refresh_count;
    logic [1:0]  r_scan_sel;
    logic [3:0]  w_digit0;
    logic [3:0]  w_digit1;
    logic [3:0]  w_digit2;
    logic [3:0]  w_digit3;
    logic [3:0]  w_active_digit;
    logic [31:0] w_next_count;
    logic        w_counter_tick;
    logic [6:0]  w_seg_raw;

    assign w_counter_tick = (r_tick_count == (FIXED_TICK_CYCLES - 1));
    assign w_next_count   = (r_count == MAX_COUNT) ? 32'd0 : (r_count + 32'd1);

    always_ff @(posedge clk) begin
        if (rst) begin
            r_count      <= 32'd0;
            r_tick_count <= 32'd0;
        end else if (i_run) begin
            if (w_counter_tick) begin
                r_tick_count <= 32'd0;
                r_count      <= w_next_count;
            end else begin
                r_tick_count <= r_tick_count + 32'd1;
            end
        end else begin
            r_tick_count <= 32'd0;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            r_refresh_count <= 32'd0;
            r_scan_sel      <= 2'd0;
        end else if (r_refresh_count == (REFRESH_DIVIDER - 1)) begin
            r_refresh_count <= 32'd0;
            r_scan_sel      <= r_scan_sel + 2'd1;
        end else begin
            r_refresh_count <= r_refresh_count + 32'd1;
        end
    end

    assign w_digit0 = r_count % 10;
    assign w_digit1 = (r_count / 10) % 10;
    assign w_digit2 = (r_count / 100) % 10;
    assign w_digit3 = (r_count / 1000) % 10;

    always_comb begin
        o_an           = 4'b1111;
        w_active_digit = 4'd0;

        case (r_scan_sel)
            2'd0: begin
                o_an           = 4'b1110;
                w_active_digit = w_digit0;
            end
            2'd1: begin
                o_an           = 4'b1101;
                w_active_digit = w_digit1;
            end
            2'd2: begin
                o_an           = 4'b1011;
                w_active_digit = w_digit2;
            end
            default: begin
                o_an           = 4'b0111;
                w_active_digit = w_digit3;
            end
        endcase
    end

    always_comb begin
        case (w_active_digit)
            4'd0:    w_seg_raw = 7'b1000000;
            4'd1:    w_seg_raw = 7'b1111001;
            4'd2:    w_seg_raw = 7'b0100100;
            4'd3:    w_seg_raw = 7'b0110000;
            4'd4:    w_seg_raw = 7'b0011001;
            4'd5:    w_seg_raw = 7'b0010010;
            4'd6:    w_seg_raw = 7'b0000010;
            4'd7:    w_seg_raw = 7'b1111000;
            4'd8:    w_seg_raw = 7'b0000000;
            4'd9:    w_seg_raw = 7'b0010000;
            default: w_seg_raw = 7'b1111111;
        endcase
    end

    assign o_seg = w_seg_raw;
    assign o_dp  = 1'b1;

endmodule
