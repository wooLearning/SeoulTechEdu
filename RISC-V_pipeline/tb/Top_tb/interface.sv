interface Top_if(input logic iClk, input logic iRstn);
    logic        tb_trace_retire_valid;
    logic        tb_trace_retire_illegal;
    logic [31:0] tb_trace_retire_pc;
    logic [31:0] tb_trace_retire_inst;
    logic        tb_trace_retire_reg_write;
    logic [4:0]  tb_trace_retire_rd_addr;
    logic [31:0] tb_trace_retire_rd_data;
    logic        tb_trace_retire_mem_write;
    logic [31:0] tb_trace_retire_mem_addr;
    logic [31:0] tb_trace_retire_mem_data;

    logic        tb_dbg_stall;
    logic        tb_dbg_redirect;
    logic [1:0]  tb_dbg_forward_a;
    logic [1:0]  tb_dbg_forward_b;

    logic [31:0] tb_gpr[0:31];
    logic [31:0] tb_mem_word0;
    logic [31:0] tb_mem_word1;
endinterface
