`timescale 1ns / 1ps

module rx (
    input        clk,
    input        reset,
    input        i_rx_data,
    input        baud_tick,
    output [7:0] o_rx_data,
    output       o_rx_done,
    output       o_frame_error
);

    parameter IDLE=2'b00, START = 2'b01, DATA=2'b10, STOP=2'b11;

    reg [1:0] c_state, n_state;
    reg [2:0] c_bit_counter, n_bit_counter;

    reg [7:0] c_rx_buf, n_rx_buf;
    assign o_rx_data = c_rx_buf;

    reg [3:0] c_baud_cnt, n_baud_cnt;

    reg c_rx_done, n_rx_done;
    assign o_rx_done = c_rx_done;

    reg rx_sync_ff1, rx_sync_ff2;
    reg c_frame_error, n_frame_error;
    assign o_frame_error = c_frame_error;
    //SL
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state       <= IDLE;
            c_bit_counter <= 3'b0;
            c_rx_buf      <= 8'h00;
            c_baud_cnt    <= 4'b0;
            c_rx_done     <= 1'b0;
            c_frame_error <= 1'b0;
            // Tx의 IDLE 상태는 HIGH이므로.
            rx_sync_ff1    <= 1'b1;
            rx_sync_ff2    <= 1'b1;
        end else begin
            c_state       <= n_state;
            c_bit_counter <= n_bit_counter;
            c_rx_buf      <= n_rx_buf;
            c_baud_cnt    <= n_baud_cnt;
            c_rx_done     <= n_rx_done;
             c_frame_error  <= n_frame_error;
            //싱크로나이저 입력
            rx_sync_ff1    <= i_rx_data;
            rx_sync_ff2    <= rx_sync_ff1;
        end
    end

    //Next CL
    always @(*) begin
        //full case 처리
        n_state       = c_state;
        n_bit_counter = c_bit_counter;
        n_rx_buf      = c_rx_buf;
        n_baud_cnt    = c_baud_cnt;
        n_rx_done     = 1'b0;
        n_frame_error = 1'b0;
        case (c_state)
            IDLE: begin
                n_bit_counter = 3'b0;
                n_baud_cnt    = 4'b0;
                //n_rx_done        = 1'b0;
                if ((baud_tick) && (!rx_sync_ff2)) begin
                    n_state  = START;
                    n_rx_buf = 8'b0;
                end
            end
            //start uart frame 
            START: begin
                if (baud_tick) begin
                    // start 구간 중간에라도 high로 올라오면 false start
                    if (rx_sync_ff2 == 1'b1) begin
                        n_state    = IDLE;
                        n_baud_cnt = 4'b0;
                    end
                    // 반 비트(8tick) 동안 low 유지되면 정상 start 인정
                    else if (c_baud_cnt == 7) begin
                        n_baud_cnt = 4'b0;
                        n_state    = DATA;
                    end
                    else begin
                        n_baud_cnt = c_baud_cnt + 1'b1;
                    end
                end
            end
            DATA: begin
                if (baud_tick) begin
                    if (c_baud_cnt == 15) begin
                        n_baud_cnt = 4'b0;
                        n_rx_buf   = {rx_sync_ff2, c_rx_buf[7:1]};
                        if (c_bit_counter == 7) begin
                            n_state = STOP; 
                        end else begin
                            n_bit_counter = c_bit_counter + 1;
                            n_state = DATA;
                        end
                    end else n_baud_cnt = c_baud_cnt + 1;
                end
            end
            STOP: begin
                if (baud_tick) begin
                    if (c_baud_cnt == 15) begin
                        n_baud_cnt = 4'b0; 
                        n_state = IDLE;
                        if (rx_sync_ff2 == 1'b1) n_rx_done =1'b1;
                        else n_frame_error = 1'b1;
                    end else n_baud_cnt = c_baud_cnt + 1;
                end
            end
        endcase
    end
endmodule


