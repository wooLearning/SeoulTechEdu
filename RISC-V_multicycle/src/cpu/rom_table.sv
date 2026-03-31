`timescale 1ns / 1ps

module rom_table (
    input  logic        clk,
    input  logic        i_req_valid,
    input  logic [31:0] i_addr,
    input  logic [ 2:0] i_funct3,
    output logic        o_rsp_valid,
    output logic [31:0] o_rdata
);

    localparam logic [31:0] CODE_BASE = 32'h0000_0000;
    localparam integer ROM_DEPTH = 1024;

    logic [31:0] rom [0:ROM_DEPTH-1];
    logic        w_hit;
    logic [31:0] w_word_idx;
    logic [ 1:0] w_addr_lsb;
    logic        r_hit_q;
    logic [ 2:0] r_funct3_q;
    logic [ 1:0] r_addr_lsb_q;
    logic [31:0] r_data_q;
    integer i;

    assign w_hit = (i_addr >= CODE_BASE) && (i_addr < CODE_BASE + ROM_DEPTH * 4);
    assign w_word_idx = (i_addr - CODE_BASE) >> 2;
    assign w_addr_lsb = i_addr[1:0];

    initial begin
        for (i = 0; i < ROM_DEPTH; i = i + 1) begin
            rom[i] = 32'h0000_0013;
        end
        $readmemh("program.mem", rom);
    end

    always_ff @(posedge clk) begin
        r_hit_q <= i_req_valid && w_hit;
        r_funct3_q <= i_funct3;
        r_addr_lsb_q <= w_addr_lsb;
        if (i_req_valid && w_hit) begin
            r_data_q <= rom[w_word_idx];
        end else begin
            r_data_q <= 32'h0000_0013;
        end
    end

    assign o_rsp_valid = r_hit_q;

    always_comb begin
        o_rdata = 32'h0000_0013;
        case (r_funct3_q)
            3'b000: begin
                case (r_addr_lsb_q)
                    2'b00: o_rdata = {{24{r_data_q[7]}}, r_data_q[7:0]};
                    2'b01: o_rdata = {{24{r_data_q[15]}}, r_data_q[15:8]};
                    2'b10: o_rdata = {{24{r_data_q[23]}}, r_data_q[23:16]};
                    default: o_rdata = {{24{r_data_q[31]}}, r_data_q[31:24]};
                endcase
            end
            3'b001: begin
                if (r_addr_lsb_q[1] == 1'b0) o_rdata = {{16{r_data_q[15]}}, r_data_q[15:0]};
                else                         o_rdata = {{16{r_data_q[31]}}, r_data_q[31:16]};
            end
            3'b010: o_rdata = r_data_q;
            3'b100: begin
                case (r_addr_lsb_q)
                    2'b00: o_rdata = {24'b0, r_data_q[7:0]};
                    2'b01: o_rdata = {24'b0, r_data_q[15:8]};
                    2'b10: o_rdata = {24'b0, r_data_q[23:16]};
                    default: o_rdata = {24'b0, r_data_q[31:24]};
                endcase
            end
            3'b101: begin
                if (r_addr_lsb_q[1] == 1'b0) o_rdata = {16'b0, r_data_q[15:0]};
                else                         o_rdata = {16'b0, r_data_q[31:16]};
            end
            default: o_rdata = r_data_q;
        endcase
    end

endmodule
