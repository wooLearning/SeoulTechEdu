`timescale 1ns / 1ps

/*
[TB_INFO_START]
Name: tb_Top_module_peri_repeat_log
Target: Top_module
Role: Log-oriented full-top testbench for the CPU ROM peripheral repeat firmware
Scenario:
  - Release reset and let the ROM firmware repeatedly access all APB peripherals
  - Reconstruct UART text from UART_TXDATA writes and print readable log lines
  - Track one completed MMIO transaction per request/response and record the first PC for each peripheral access type
CheckPoint:
  - Verify the firmware reaches GPI, GPO, GPIO, FND, UART_BAUDCFG, and UART_TXDATA accesses
  - Stop only after at least one full loop-visible ITER log line is observed
  - Print a compact summary of the first PC that touched each MMIO endpoint
[TB_INFO_END]
*/

module tb_Top_module_peri_repeat_log;

    localparam logic [31:0] GPO_CTL_ADDR      = 32'h2000_0000;
    localparam logic [31:0] GPO_ODATA_ADDR    = 32'h2000_0004;
    localparam logic [31:0] GPI_CTL_ADDR      = 32'h2000_1000;
    localparam logic [31:0] GPI_IDATA_ADDR    = 32'h2000_1004;
    localparam logic [31:0] GPIO_CTL_ADDR     = 32'h2000_2000;
    localparam logic [31:0] GPIO_ODATA_ADDR   = 32'h2000_2004;
    localparam logic [31:0] GPIO_IDATA_ADDR   = 32'h2000_2008;
    localparam logic [31:0] FND_RUN_ADDR      = 32'h2000_3000;
    localparam logic [31:0] UART_STATUS_ADDR  = 32'h2000_4004;
    localparam logic [31:0] UART_TXDATA_ADDR  = 32'h2000_4008;
    localparam logic [31:0] UART_RXDATA_ADDR  = 32'h2000_400C;
    localparam logic [31:0] UART_CONTROL_ADDR = 32'h2000_4010;
    localparam logic [31:0] UART_BAUDCFG_ADDR = 32'h2000_4014;

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

    logic        r_req_pending;
    logic        r_pending_write;
    logic [31:0] r_pending_addr;
    logic [31:0] r_pending_wdata;
    logic [31:0] r_pending_pc;

    bit          r_seen_gpi_read;
    bit          r_seen_gpo_write;
    bit          r_seen_gpio_ctl_write;
    bit          r_seen_gpio_odata_write;
    bit          r_seen_gpio_idata_read;
    bit          r_seen_fnd_write;
    bit          r_seen_uart_baudcfg_write;
    bit          r_seen_uart_baudcfg_read;
    bit          r_seen_uart_tx_write;
    bit          r_seen_boot_banner;

    logic [31:0] r_pc_gpi_read;
    logic [31:0] r_pc_gpo_write;
    logic [31:0] r_pc_gpio_ctl_write;
    logic [31:0] r_pc_gpio_odata_write;
    logic [31:0] r_pc_gpio_idata_read;
    logic [31:0] r_pc_fnd_write;
    logic [31:0] r_pc_uart_baudcfg_write;
    logic [31:0] r_pc_uart_baudcfg_read;
    logic [31:0] r_pc_uart_tx_write;

    int          r_uart_line_count;
    int          r_iter_line_count;
    string       r_line_buf;

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin
            assign io_gpio[i] = r_gpio_oe[i] ? r_gpio_drv[i] : 1'bz;
        end
    endgenerate

    Top_module U_DUT (
        .clk       (clk),
        .rst       (rst),
        .i_uart_rx (i_uart_rx),
        .o_uart_tx (o_uart_tx),
        .o_fnd_seg (o_fnd_seg),
        .o_fnd_dp  (o_fnd_dp),
        .o_fnd_an  (o_fnd_an),
        .i_gpi_sw  (i_gpi_sw),
        .io_gpo    (io_gpo),
        .io_gpio   (io_gpio),
        .i_baud_sel(i_baud_sel)
    );

    always #5 clk = ~clk;

    task automatic log_completed_mmio;
        input logic        i_write;
        input logic [31:0] i_pc;
        input logic [31:0] i_addr;
        input logic [31:0] i_wdata;
        input logic [31:0] i_rdata;
        input logic        i_error;
        begin
            $display("[%0t][PERI_MMIO] pc=%08h %s addr=%08h wdata=%08h rdata=%08h err=%0d",
                     $time,
                     i_pc,
                     i_write ? "WR" : "RD",
                     i_addr,
                     i_wdata,
                     i_rdata,
                     i_error);
        end
    endtask

    always @(posedge clk) begin
        if (rst) begin
            r_req_pending <= 1'b0;
            r_pending_write <= 1'b0;
            r_pending_addr <= 32'd0;
            r_pending_wdata <= 32'd0;
            r_pending_pc <= 32'd0;
        end else begin
            if (U_DUT.w_apb_req_valid) begin
                r_req_pending <= 1'b1;
                r_pending_write <= U_DUT.w_apb_req_write;
                r_pending_addr <= U_DUT.w_apb_req_addr;
                r_pending_wdata <= U_DUT.w_apb_req_wdata;
                r_pending_pc <= U_DUT.w_pc_data;
            end

            if (r_req_pending && U_DUT.w_apb_rsp_valid) begin
                if ((r_pending_addr != UART_STATUS_ADDR) &&
                    (r_pending_addr != UART_RXDATA_ADDR) &&
                    (r_pending_addr != UART_TXDATA_ADDR)) begin
                    log_completed_mmio(
                        r_pending_write,
                        r_pending_pc,
                        r_pending_addr,
                        r_pending_wdata,
                        U_DUT.w_apb_rsp_rdata,
                        U_DUT.w_apb_rsp_error
                    );
                end

                case (r_pending_addr)
                    GPI_IDATA_ADDR: begin
                        if (!r_pending_write) begin
                            r_seen_gpi_read <= 1'b1;
                            if (r_pc_gpi_read == 32'd0) begin
                                r_pc_gpi_read <= r_pending_pc;
                            end
                        end
                    end
                    GPO_ODATA_ADDR: begin
                        if (r_pending_write) begin
                            r_seen_gpo_write <= 1'b1;
                            if (r_pc_gpo_write == 32'd0) begin
                                r_pc_gpo_write <= r_pending_pc;
                            end
                        end
                    end
                    GPIO_CTL_ADDR: begin
                        if (r_pending_write) begin
                            r_seen_gpio_ctl_write <= 1'b1;
                            if (r_pc_gpio_ctl_write == 32'd0) begin
                                r_pc_gpio_ctl_write <= r_pending_pc;
                            end
                        end
                    end
                    GPIO_ODATA_ADDR: begin
                        if (r_pending_write) begin
                            r_seen_gpio_odata_write <= 1'b1;
                            if (r_pc_gpio_odata_write == 32'd0) begin
                                r_pc_gpio_odata_write <= r_pending_pc;
                            end
                        end
                    end
                    GPIO_IDATA_ADDR: begin
                        if (!r_pending_write) begin
                            r_seen_gpio_idata_read <= 1'b1;
                            if (r_pc_gpio_idata_read == 32'd0) begin
                                r_pc_gpio_idata_read <= r_pending_pc;
                            end
                        end
                    end
                    FND_RUN_ADDR: begin
                        if (r_pending_write) begin
                            r_seen_fnd_write <= 1'b1;
                            if (r_pc_fnd_write == 32'd0) begin
                                r_pc_fnd_write <= r_pending_pc;
                            end
                        end
                    end
                    UART_BAUDCFG_ADDR: begin
                        if (r_pending_write) begin
                            r_seen_uart_baudcfg_write <= 1'b1;
                            if (r_pc_uart_baudcfg_write == 32'd0) begin
                                r_pc_uart_baudcfg_write <= r_pending_pc;
                            end
                        end else begin
                            r_seen_uart_baudcfg_read <= 1'b1;
                            if (r_pc_uart_baudcfg_read == 32'd0) begin
                                r_pc_uart_baudcfg_read <= r_pending_pc;
                            end
                        end
                    end
                    default: begin
                    end
                endcase

                r_req_pending <= 1'b0;
            end
        end
    end

    always @(posedge clk) begin
        byte unsigned ch;

        if (rst) begin
            r_uart_line_count <= 0;
            r_iter_line_count <= 0;
            r_line_buf = "";
            r_seen_boot_banner <= 1'b0;
        end else if (U_DUT.U_APB.w_psel5 && U_DUT.U_APB.w_penable && U_DUT.U_APB.w_pwrite &&
                     (U_DUT.U_APB.w_paddr[7:0] == 8'h08)) begin
            ch = U_DUT.U_APB.w_pwdata[7:0];

            r_seen_uart_tx_write <= 1'b1;
            if (r_pc_uart_tx_write == 32'd0) begin
                r_pc_uart_tx_write <= U_DUT.w_pc_data;
            end

            if (ch == 8'h0D) begin
            end else if (ch == 8'h0A) begin
                r_uart_line_count <= r_uart_line_count + 1;
                $display("[%0t][TOP_UART] %s", $time, r_line_buf);
                if ((r_line_buf.len() >= 4) && (r_line_buf.substr(0, 3) == "ITER")) begin
                    r_iter_line_count <= r_iter_line_count + 1;
                end
                if (r_line_buf == "CPU ROM peripheral repeat test boot") begin
                    r_seen_boot_banner <= 1'b1;
                end
                r_line_buf = "";
            end else begin
                r_line_buf = {r_line_buf, ch};
            end
        end
    end

    initial begin
        clk                   = 1'b0;
        rst                   = 1'b1;
        i_uart_rx             = 1'b1;
        i_baud_sel            = 4'd5;
        i_gpi_sw              = 11'b0_1001_1_1_0101;
        r_gpio_drv            = 4'hA;
        r_gpio_oe             = 4'hF;
        r_req_pending         = 1'b0;
        r_pending_write       = 1'b0;
        r_pending_addr        = 32'd0;
        r_pending_wdata       = 32'd0;
        r_pending_pc          = 32'd0;
        r_seen_gpi_read       = 1'b0;
        r_seen_gpo_write      = 1'b0;
        r_seen_gpio_ctl_write = 1'b0;
        r_seen_gpio_odata_write = 1'b0;
        r_seen_gpio_idata_read = 1'b0;
        r_seen_fnd_write      = 1'b0;
        r_seen_uart_baudcfg_write = 1'b0;
        r_seen_uart_baudcfg_read  = 1'b0;
        r_seen_uart_tx_write  = 1'b0;
        r_seen_boot_banner    = 1'b0;
        r_pc_gpi_read         = 32'd0;
        r_pc_gpo_write        = 32'd0;
        r_pc_gpio_ctl_write   = 32'd0;
        r_pc_gpio_odata_write = 32'd0;
        r_pc_gpio_idata_read  = 32'd0;
        r_pc_fnd_write        = 32'd0;
        r_pc_uart_baudcfg_write = 32'd0;
        r_pc_uart_baudcfg_read  = 32'd0;
        r_pc_uart_tx_write    = 32'd0;
        r_uart_line_count     = 0;
        r_iter_line_count     = 0;
        r_line_buf            = "";

        repeat (20) @(posedge clk);
        rst = 1'b0;
        $display("[%0t][TOP_TB] Reset released", $time);
    end

    initial begin
        wait (!rst);

        wait (
            r_seen_boot_banner &&
            r_seen_gpi_read &&
            r_seen_gpo_write &&
            r_seen_gpio_ctl_write &&
            r_seen_gpio_odata_write &&
            r_seen_gpio_idata_read &&
            r_seen_fnd_write &&
            r_seen_uart_baudcfg_write &&
            r_seen_uart_baudcfg_read &&
            r_seen_uart_tx_write &&
            (r_iter_line_count >= 1)
        );

        $display("[%0t][TOP_TB] Peripheral repeat loop observed successfully", $time);
        $display("[%0t][TOP_TB] first_pc GPI_IDATA    = %08h", $time, r_pc_gpi_read);
        $display("[%0t][TOP_TB] first_pc GPO_ODATA    = %08h", $time, r_pc_gpo_write);
        $display("[%0t][TOP_TB] first_pc GPIO_CTL     = %08h", $time, r_pc_gpio_ctl_write);
        $display("[%0t][TOP_TB] first_pc GPIO_ODATA   = %08h", $time, r_pc_gpio_odata_write);
        $display("[%0t][TOP_TB] first_pc GPIO_IDATA   = %08h", $time, r_pc_gpio_idata_read);
        $display("[%0t][TOP_TB] first_pc FND_RUN      = %08h", $time, r_pc_fnd_write);
        $display("[%0t][TOP_TB] first_pc UART_BAUDCFG_WR = %08h", $time, r_pc_uart_baudcfg_write);
        $display("[%0t][TOP_TB] first_pc UART_BAUDCFG_RD = %08h", $time, r_pc_uart_baudcfg_read);
        $display("[%0t][TOP_TB] first_pc UART_TXDATA  = %08h", $time, r_pc_uart_tx_write);
        $display("[%0t][TOP_TB] uart_line_count=%0d iter_line_count=%0d gpo=%h gpio=%b fnd_an=%b seg=%b",
                 $time, r_uart_line_count, r_iter_line_count, io_gpo, io_gpio, o_fnd_an, o_fnd_seg);
        $finish;
    end

    initial begin
        #1000000000;
        $fatal(1, "[%0t][TOP_TB] Timeout waiting for peripheral repeat loop evidence", $time);
    end

endmodule
