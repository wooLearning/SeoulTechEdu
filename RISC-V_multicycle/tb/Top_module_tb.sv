`timescale 1ns / 1ps

/*
[TB_INFO_START]
Name: tb_Top_module
Target: Top_module
Role: Smoke testbench for compiling and booting the full RV32I top module
Scenario:
  - Release reset and allow the ROM program to start issuing MMIO traffic
  - Observe early APB and UART activity without waiting for long software delays
CheckPoint:
  - Verify reset release and first CPU/APB activity
  - Keep the testbench aligned with the current top-level port list
[TB_INFO_END]
*/

module tb_Top_module;

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
        clk              = 1'b0;
        rst              = 1'b1;
        i_uart_rx        = 1'b1;
        i_gpi_sw         = 11'h155;
        i_baud_sel       = 4'h0;
        r_gpio_drv       = 4'hA;
        r_gpio_oe        = 4'hF;

        repeat (20) @(posedge clk);
        rst = 1'b0;
    end

    initial begin
        $display("[%0t] TB start", $time);

        wait (!rst);
        $display("[%0t] Reset released", $time);

        wait (U_DUT.w_cpu_mem_valid);
        $display("[%0t] CPU mem request addr=%08h write=%0d funct3=%0h",
                 $time,
                 U_DUT.w_cpu_mem_addr,
                 U_DUT.w_cpu_mem_write,
                 U_DUT.w_cpu_mem_funct3);

        wait (U_DUT.w_apb_req_valid);
        $display("[%0t] APB request addr=%08h write=%0d wdata=%08h",
                 $time,
                 U_DUT.w_apb_req_addr,
                 U_DUT.w_apb_req_write,
                 U_DUT.w_apb_req_wdata);

        wait ((U_DUT.U_APB.w_psel4 || U_DUT.U_APB.w_psel5) && U_DUT.U_APB.w_penable && U_DUT.U_APB.w_pwrite);
        $display("[%0t] Peripheral APB access paddr=%08h pwdata=%08h",
                 $time,
                 U_DUT.U_APB.w_paddr,
                 U_DUT.U_APB.w_pwdata);

        repeat (200000) @(posedge clk);
        $display("[%0t] TB done, FND an=%b seg=%b gpo=%h", $time, o_fnd_an, o_fnd_seg, io_gpo);
        $finish;
    end

    initial begin
        repeat (5000000) @(posedge clk);
        $fatal(1, "[%0t] Timeout waiting for CPU/APB activity", $time);
    end

endmodule
