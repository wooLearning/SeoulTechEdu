`timescale 1ns / 1ps

module data_memory (
    input  logic        clk,
    input  logic        i_req_valid,
    input  logic        i_req_write,
    input  logic [31:0] i_addr,
    input  logic [31:0] i_wdata,
    input  logic [ 2:0] i_funct3,
    input  logic [ 7:0] i_dbg_word_idx,
    output logic        o_rsp_valid,
    output logic [31:0] o_rdata,
    output logic [31:0] o_dbg_word
);

    localparam logic [31:0] DATA_BASE = 32'h1000_0000;
    localparam integer RAM_DEPTH = 1024;
    localparam integer RAM_BYTES = RAM_DEPTH * 4;

    logic [31:0] ram [0:RAM_DEPTH-1];
    logic        w_hit;
    logic [31:0] w_local;
    logic [31:0] w_word_addr;
    logic [ 1:0] w_addr_lsb;
    logic        r_hit_q;
    logic [ 2:0] r_funct3_q;
    logic [ 1:0] r_addr_lsb_q;
    logic [31:0] r_word_q;
    logic [31:0] r_dbg_word_q;
    logic [31:0] w_aligned_data;
    logic [ 3:0] w_byte_we;
    integer i;

    assign w_hit = (i_addr >= DATA_BASE) && (i_addr < DATA_BASE + RAM_BYTES);
    assign w_local = i_addr - DATA_BASE;
    assign w_word_addr = w_local >> 2;
    assign w_addr_lsb = w_local[1:0];

    initial begin
        for (i = 0; i < RAM_DEPTH; i = i + 1) begin
            ram[i] = 32'h0000_0000;
        end
    end

    always_comb begin
        w_aligned_data = 32'b0;
        w_byte_we      = 4'b0000;

        if (i_req_valid && i_req_write && w_hit) begin
            case (i_funct3)
                3'b000: begin
                    w_aligned_data = {i_wdata[7:0], i_wdata[7:0], i_wdata[7:0], i_wdata[7:0]};
                    case (w_addr_lsb)
                        2'b00: w_byte_we = 4'b0001;
                        2'b01: w_byte_we = 4'b0010;
                        2'b10: w_byte_we = 4'b0100;
                        default: w_byte_we = 4'b1000;
                    endcase
                end
                3'b001: begin
                    w_aligned_data = {i_wdata[15:0], i_wdata[15:0]};
                    if (w_addr_lsb[1] == 1'b0) w_byte_we = 4'b0011;
                    else                       w_byte_we = 4'b1100;
                end
                3'b010: begin
                    w_aligned_data = i_wdata;
                    w_byte_we = 4'b1111;
                end
                default: begin
                    w_aligned_data = 32'b0;
                    w_byte_we = 4'b0000;
                end
            endcase
        end
    end

    always_ff @(posedge clk) begin
        r_hit_q      <= i_req_valid && w_hit;
        r_funct3_q   <= i_funct3;
        r_addr_lsb_q <= w_addr_lsb;

        if (i_req_valid && w_hit) begin
            if (i_req_write) begin
                if (w_byte_we[0]) ram[w_word_addr][7:0]   <= w_aligned_data[7:0];
                if (w_byte_we[1]) ram[w_word_addr][15:8]  <= w_aligned_data[15:8];
                if (w_byte_we[2]) ram[w_word_addr][23:16] <= w_aligned_data[23:16];
                if (w_byte_we[3]) ram[w_word_addr][31:24] <= w_aligned_data[31:24];
                r_word_q <= ram[w_word_addr];
            end else begin
                r_word_q <= ram[w_word_addr];
            end
        end else begin
            r_word_q <= 32'h0000_0000;
        end

        r_dbg_word_q <= ram[i_dbg_word_idx];
    end

    always_comb begin
        o_rdata = 32'h0000_0000;
        case (r_funct3_q)
            3'b000: begin
                case (r_addr_lsb_q)
                    2'b00: o_rdata = {{24{r_word_q[7]}}, r_word_q[7:0]};
                    2'b01: o_rdata = {{24{r_word_q[15]}}, r_word_q[15:8]};
                    2'b10: o_rdata = {{24{r_word_q[23]}}, r_word_q[23:16]};
                    default: o_rdata = {{24{r_word_q[31]}}, r_word_q[31:24]};
                endcase
            end
            3'b001: begin
                if (r_addr_lsb_q[1] == 1'b0) o_rdata = {{16{r_word_q[15]}}, r_word_q[15:0]};
                else                         o_rdata = {{16{r_word_q[31]}}, r_word_q[31:16]};
            end
            3'b010: o_rdata = r_word_q;
            3'b100: begin
                case (r_addr_lsb_q)
                    2'b00: o_rdata = {24'b0, r_word_q[7:0]};
                    2'b01: o_rdata = {24'b0, r_word_q[15:8]};
                    2'b10: o_rdata = {24'b0, r_word_q[23:16]};
                    default: o_rdata = {24'b0, r_word_q[31:24]};
                endcase
            end
            3'b101: begin
                if (r_addr_lsb_q[1] == 1'b0) o_rdata = {16'b0, r_word_q[15:0]};
                else                         o_rdata = {16'b0, r_word_q[31:16]};
            end
            default: o_rdata = r_word_q;
        endcase
    end

    assign o_rsp_valid = r_hit_q;
    assign o_dbg_word  = r_dbg_word_q;

endmodule
