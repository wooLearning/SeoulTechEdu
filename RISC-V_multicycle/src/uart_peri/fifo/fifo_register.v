`timescale 1ns / 1ps

// 데이터는 8bit 고정 ( Width = 8)
// Depth만 조절
// Memory size = Addres Depth * Width 
//             = 2^(addr Width) * Data Width
// Simple dual port 구조 
// Distributted Ram(LUTRAM) 사용. ; 조합로직/레지스터 파일 

// 메모리는 rst 포트가 없다. 
module fifo_register#(
parameter Data_Width = 8,
Address_Depth  = 4
)(
    input clk,
    input we,
    input [$clog2(Address_Depth)-1:0] write_addr,
    input [$clog2(Address_Depth)-1:0] read_addr,
    input [Data_Width-1:0] i_data,
    output [Data_Width-1:0] o_data
    );

    // 메모리 셀 설정
    reg [Data_Width-1:0] r_memory [0:Address_Depth-1];

    always @ (posedge clk) begin
        if(we) begin
            r_memory[write_addr] <= i_data;
        end
    end
    assign o_data = r_memory[read_addr] ;
    
endmodule
