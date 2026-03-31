`timescale 1ns / 1ps

module fifo_control #(
    parameter Address_Depth = 4
) (
    input                            clk,
    input                            rst,
    input                            i_push,
    input                            i_pop,
    output [$clog2(Address_Depth):0] o_wptr,  // 주소비트+1  
    output [$clog2(Address_Depth):0] o_rptr,
    output                           o_full,
    output                           o_empty,
    output                           o_we
);

    reg [$clog2(Address_Depth):0] c_rptr, n_rptr;
    reg [$clog2(Address_Depth):0] c_wptr, n_wptr;

    assign o_wptr = c_wptr;
    assign o_rptr = c_rptr;

    // 데이터를 읽는 타이밍 : empty가 아니면서 pop 명령이 들어 올 때 
    // 단, push명령이 같이 들어온다면 pop 실행. 
    wire w_real_pop = (!o_empty | i_push) & (i_pop);
    
    // 데이터를 쓰는 타이밍 : full이 아니면서 push 명령이 들어 올 때. 
    // 단 pop 명령이 같이 들어온다면 push 실행.
    wire w_real_push = (!o_full | i_pop) & (i_push);
    assign o_we = w_real_push;

    // wptr, rptr 조절
    // 데이터를 쓸 때와 읽을 때는 동기신호에 맞춰서. 
    // 그리고 full empty 신호는 저장소가 꽉 차거나 비어있을 때 해당 사이클 내에 바로 보낼 수 있도록 조합 출력으로 구성.
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_wptr <= 0;
            c_rptr <= 0;
        end else begin
            // full 직전상황에서 push가 들어오는 순간 레지스터는 마지막셀(c_wptr)에 데이터를 바로 출력할테고 (셋업타임맞춰서 준비 시켜뒀을테니) 
            // 같은 타이밍에 이 컨트롤로직에 의해서 ptr도 업데이트. 그리고 아래 조합로직에 의해서 바로 출력
            // 그러면 full 신호가 sender(데이터를 보내는 모듈)에 도착할테고(셋업타임 지켜서) 근데 문제는 sender도 이미 셋업타임지켜서 fifo로 데이터 보내놨음
            // fifo는 내부적으로 full신호 띄워서 we핀을 비활성화 시켜놔서 이대로면 이 타이밍에 sender가 보낸 데이터가 씹힘. 
            // 즉 데이터가 무시되었으니 sender보고 한번 더 보내라는 컨트롤 로직이 필요함. 
            c_wptr <= n_wptr; 
            c_rptr <= n_rptr;
        end
    end
    always @(*) begin
        n_wptr=c_wptr;
        n_rptr=c_rptr;
        if (w_real_pop) n_rptr=c_rptr+1;
        if (w_real_push) n_wptr=c_wptr+1;
    end

    // full, empty 결정; 
    // 조합 출력. 레지스터파일이 LUTRAM으로 구현할거라서 같은 타이밍에 full empty 신호 출력될 수 있도록 
    wire w_wptr_MSB = o_wptr[$clog2(Address_Depth)];
    wire w_rptr_MSB = o_rptr[$clog2(Address_Depth)];

    wire [$clog2(Address_Depth)-1:0] w_wptr_LSBs = o_wptr[$clog2(Address_Depth)-1:0];
    wire [$clog2(Address_Depth)-1:0] w_rptr_LSBs = o_rptr[$clog2(Address_Depth)-1:0];

    assign o_full  = (w_wptr_MSB != w_rptr_MSB) & (w_wptr_LSBs == w_rptr_LSBs);
    assign o_empty = (w_wptr_MSB == w_rptr_MSB) & (w_wptr_LSBs == w_rptr_LSBs);


    // ptr의 업데이트는 다음 사이클에서 일어난다. 
    // full 직전인 상황에서 push가 들어오면 

endmodule
