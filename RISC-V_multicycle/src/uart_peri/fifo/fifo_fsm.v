`timescale 1ns / 1ps

module fifo_uart_fsm (
    input        clk,
    input        reset,

    // FIFO 측 인터페이스
    input        i_fifo_empty,
    input  [7:0] i_fifo_pop_data,
    output       o_fifo_pop,

    // UART RX 측 인터페이스 (PC 키보드 에코용)
    input  [7:0] i_rx_data,
    input        i_rx_done,

    // UART TX 측 인터페이스
    input        i_tx_busy,
    output [7:0] o_tx_data,
    output       o_tx_start
);

    reg [1:0] fifo_tx_state;
    reg r_tx_start;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            fifo_tx_state <= 2'b00;
            r_tx_start <= 1'b0;
        end else begin
            case (fifo_tx_state)
                2'b00: begin
                    // FIFO에 보낼 데이터가 있고 UART가 한가할 때 전송 시작 (Pop & Tx_Start)
                    if (!i_fifo_empty && !i_tx_busy) begin
                        r_tx_start <= 1'b1;
                        fifo_tx_state <= 2'b01;
                    end
                end
                2'b01: begin
                    r_tx_start <= 1'b0; // 1클럭 펄스만 생성
                    // UART가 바빠지면 대기 상태로 이동
                    if (i_tx_busy) begin
                        fifo_tx_state <= 2'b10;
                    end
                end
                2'b10: begin
                    // UART 전송이 완전히 끝나면 다시 대기 상태로 복귀
                    if (!i_tx_busy) begin
                        fifo_tx_state <= 2'b00;
                    end
                end
                default: fifo_tx_state <= 2'b00;
            endcase
        end
    end

    // r_tx_start 펄스 발생 시점에 맞춰 FIFO에서도 데이터를 Pop
    assign o_fifo_pop = r_tx_start;

    // FIFO에서 전송 중일 때는 FIFO 데이터를, 평소에는 키보드 타이핑 에코(RX) 데이터를 전송
    wire w_fifo_active = (fifo_tx_state != 2'b00) || (!i_fifo_empty);
    assign o_tx_data  = (w_fifo_active) ? i_fifo_pop_data : i_rx_data;
    assign o_tx_start = (w_fifo_active) ? r_tx_start      : i_rx_done;

endmodule