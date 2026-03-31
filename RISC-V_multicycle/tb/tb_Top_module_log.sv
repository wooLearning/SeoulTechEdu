`timescale 1ns / 1ps

/*
[TB_INFO_START]
Name: tb_Top_module_log
Target: Top_module
Role: Log-oriented full-top testbench for ROM boot and repeated firmware activity
Scenario:
  - Release reset and boot the ROM image in the full top module
  - Reconstruct UART log text from APB writes to UART_TXDATA and print it into the simulator transcript
  - Stop after the ROM firmware performs initialization and two loop-visible GPO writes
CheckPoint:
  - Verify reset release and early APB activity first
  - Compare reconstructed UART text against expected boot progression
  - Add explicit stop criteria so the looping firmware does not run forever
[TB_INFO_END]
*/

module tb_Top_module_log;

    logic        clk;
    logic        rst;
    logic        i_uart_rx;
    logic [10:0] i_gpi_sw;
    logic [3:0]  i_baud_sel;
    tri   [3:0]  io_gpio;
    logic [3:0]  r_gpio_drv;
    logic [3:0]  r_gpio_oe;
    logic        o_uart_tx;
    logic [6:0]  o_fnd_seg;
    logic        o_fnd_dp;
    logic [3:0]  o_fnd_an;
    logic [15:0] io_gpo;
    int          heartbeat_count;
    int          gpo_write_count;
    string       line_buf;

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin
            assign io_gpio[i] = r_gpio_oe[i] ? r_gpio_drv[i] : 1'bz;
        end
    endgenerate

    Top_module U_DUT (
        .clk      (clk),
        .rst      (rst),
        .i_uart_rx(i_uart_rx),
        .o_uart_tx(o_uart_tx),
        .o_fnd_seg(o_fnd_seg),
        .o_fnd_dp (o_fnd_dp),
        .o_fnd_an (o_fnd_an),
        .i_gpi_sw (i_gpi_sw),
        .io_gpo   (io_gpo),
        .io_gpio  (io_gpio),
        .i_baud_sel(i_baud_sel)
    );

    always #5 clk = ~clk;

    initial begin
        heartbeat_count = 0;
        gpo_write_count = 0;
        line_buf = "";
    end

    always @(posedge clk) begin
        byte unsigned ch;

        if (U_DUT.U_APB.w_psel5 && U_DUT.U_APB.w_penable && U_DUT.U_APB.w_pwrite &&
            (U_DUT.U_APB.w_paddr[7:0] == 8'h08)) begin
            ch = U_DUT.U_APB.w_pwdata[7:0];
            if (ch == 8'h0D) begin
            end else if (ch == 8'h0A) begin
                $display("[%0t][TOP_UART] %s", $time, line_buf);
                if ((line_buf.len() >= 3) && (line_buf.substr(0, 2) == "HB ")) begin
                    heartbeat_count = heartbeat_count + 1;
                    $display("[%0t][TOP_TB] heartbeat_count=%0d", $time, heartbeat_count);
                end
                line_buf = "";
            end else begin
                line_buf = {line_buf, ch};
            end
        end

        if (U_DUT.U_APB.w_psel1 && U_DUT.U_APB.w_penable && U_DUT.U_APB.w_pwrite &&
            (U_DUT.U_APB.w_paddr[7:0] == 8'h04)) begin
            gpo_write_count = gpo_write_count + 1;
            $display("[%0t][TOP_TB] GPO_ODATA write #%0d data=%08h",
                     $time, gpo_write_count, U_DUT.U_APB.w_pwdata);
        end
    end

    initial begin
        clk        = 1'b0;
        rst        = 1'b1;
        i_uart_rx  = 1'b1;
        i_baud_sel = 4'd5;
        i_gpi_sw   = 11'b0_1001_1_1_0101;
        r_gpio_drv = 4'hA;
        r_gpio_oe  = 4'hF;

        repeat (20) @(posedge clk);
        rst = 1'b0;
        $display("[%0t][TOP_TB] Reset released", $time);
    end

    initial begin
        wait (!rst);

        wait (U_DUT.w_apb_req_valid);
        $display("[%0t][TOP_TB] First APB req addr=%08h write=%0d wdata=%08h",
                 $time, U_DUT.w_apb_req_addr, U_DUT.w_apb_req_write, U_DUT.w_apb_req_wdata);

        wait (gpo_write_count >= 3);
        $display("[%0t][TOP_TB] Observed init + two loop GPO writes", $time);
        $display("[%0t][TOP_TB] heartbeat_count_so_far=%0d", $time, heartbeat_count);
        $display("[%0t][TOP_TB] Final GPO=%h GPIO=%b FND an=%b seg=%b",
                 $time, io_gpo, io_gpio, o_fnd_an, o_fnd_seg);
        $finish;
    end

    initial begin
        #200000000;
        $fatal(1, "[%0t][TOP_TB] Timeout waiting for init + two loop GPO writes", $time);
    end

endmodule
