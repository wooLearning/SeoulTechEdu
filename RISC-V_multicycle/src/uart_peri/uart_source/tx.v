`timescale 1ns / 1ps

module tx (
    input        clk,
    input        reset,
    input  [7:0] i_tx_data,
    input        baud_tick,
    input        i_tx_start,
    output       o_tx_data,
    output       o_tx_done,
    output       o_tx_busy

);

    parameter IDLE=2'b00, START = 2'b01, DATA=2'b10, STOP=2'b11;

    reg [1:0] c_state, n_state;

    // 출력값을 CL아니라 SL을 통해서 내보기 위한 reg변수 선언과 연속 할당문.
    reg c_tx_out, n_tx_out;
    assign o_tx_data = c_tx_out;

    // bit_counter 
    reg [2:0] c_bit_counter, n_bit_counter;

    // Tx로 들어오는 값은 Start신호가 들어 왔을 때 Buf에 입력데이터 저장.
    reg [7:0] c_tx_buf, n_tx_buf;

    // Busy: 데이터 전송 값 1 ; 데이터를 전송 중에 있으므로 데이터 입력하지 말 것.
    // Done: Stop bit까지 데이터 전송이 끝나고 1; 데이터 한 frame의 전송을 완료했다는 신호
    // 처음 START 신호가 들어오면 BUSY가 켜지고 DONE이 켜지면 BUSY가 꺼진다. 
    reg c_tx_busy, n_busy;
    reg c_tx_done, n_done;
    // 외부 포트로 출력시켜야할 신호라서.
    assign o_tx_done = c_tx_done;
    assign o_tx_busy = c_tx_busy;

    // baud_counter
    // 16배 빨라진 baud_tick 신호 들어오는데 통신 속도는 여전히 9600 bps로 할 것이기 때문에 16카운터 필요함. 
    // 아래의 모든 동작이 tick신호의 16번마다 동작하도록 바꿔줌
    // 그리고 c_baud_cnt == 15 가 되면 카운터 값을 0으로 초기화 해주는 것도 잊지 말고.
    reg [3:0] c_baud_cnt, n_baud_cnt;


    //SL
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state       <= IDLE;
            c_tx_out      <= 1'b1;
            c_bit_counter <= 3'b0;
            c_tx_buf      <= 8'h00;
            c_tx_done        <= 1'b0;
            c_tx_busy        <= 1'b0;
            c_baud_cnt    <= 4'b0;
        end else begin
            c_state       <= n_state;
            c_tx_out      <= n_tx_out;
            c_bit_counter <= n_bit_counter;
            c_tx_buf      <= n_tx_buf;
            c_tx_done        <= n_done;
            c_tx_busy        <= n_busy;
            c_baud_cnt    <= n_baud_cnt;
        end
    end

    //Next CL
    always @(*) begin
        //full case 처리
        n_state       = c_state;
        n_tx_out      = c_tx_out;
        n_bit_counter = c_bit_counter;
        n_tx_buf      = c_tx_buf;
        n_done        = c_tx_done;
        n_busy        = c_tx_busy;
        n_baud_cnt    = c_baud_cnt;
        case (c_state)
            IDLE: begin
                n_tx_out = 1'b1;
                n_bit_counter = 3'b0;
                n_done = 1'b0;
                if (i_tx_start) begin
                    n_state  = START;
                    n_tx_buf = i_tx_data;
                    n_busy   = 1'b1;  
                    n_tx_out = 1'b0;
                    //상대 tx 의 baud tick과 내 rx의 baud tick에는 관계가 없어
                    // 또한 내 상대 tx는 start bit를 16tick(104.167 us) 동안 보내는 게 맞는데 
                end
            end
            //start uart frame 
            START: begin
                if (baud_tick) begin
                    if (c_baud_cnt == 15) begin
                        n_state  = DATA;
                        n_tx_out = n_tx_buf[c_bit_counter];
                        n_baud_cnt = 4'b0;
                    end else n_baud_cnt = c_baud_cnt + 1;
                end
            end
            DATA: begin
                if (baud_tick) begin
                    if (c_baud_cnt == 15) begin
                        n_baud_cnt = 4'b0;
                        if (c_bit_counter == 7) begin
                            n_state = STOP;
                            n_tx_out = 1'b1; // STOP bit는 high를 출력하므로 이렇게 수정. 
                        end else begin
                            n_bit_counter = c_bit_counter + 1;
                            n_state = DATA;
                            n_tx_out = n_tx_buf[c_bit_counter +1]; // 다음 스테이트로 업데이트 하면서 즉시 그에 맞는 값을 출력할 수 있도록.
                        end
                    end else n_baud_cnt = c_baud_cnt + 1;
                end
            end
            STOP: begin
                n_tx_out = 1'b1;
                if (baud_tick) begin
                    if(c_baud_cnt == 15) begin
                        n_baud_cnt = 4'b0;
                        n_state = IDLE;
                        n_tx_out = 1'b1; // IDLE 상태는 high가 기본 출력이기 때문에 다음 업데이트 때 IDLE 되면서 바로 1출력. 
                        n_done = 1'b1;
                        n_busy = 1'b0;  // DONE 신호가 들어와서 꺼짐.
                    end else n_baud_cnt =c_baud_cnt+1;
                end
            end
        endcase
    end


endmodule

