`timescale 1ns / 1ps

/*
[TB_INFO_START]
Name: tb_uart_apb_wrapper
Target: uart_apb_wrapper
Role: Class-based directed testbench for validating the UART APB peripheral
Scenario:
  - Check reset defaults and APB-visible ID and status registers
  - Verify APB TX writes serialize onto o_uart_tx with scoreboard checks
  - Verify external RX frame reception, jitter-tolerant RX, frame error, and RX overflow handling
CheckPoint:
  - Verify DUT reset and default outputs first
  - Compare UART TX serial output and APB RXDATA contents against expected bytes
  - Add explicit expected-value checks for auto-judgement
[TB_INFO_END]
*/

module tb_uart_apb_wrapper;
    import uart_peri_tb_pkg::*;

    localparam int unsigned LP_CLK_PERIOD_NS = 10;
    localparam string       LP_RUNTIME_CFG_PATH = "uart_jitter_runtime_cfg.txt";

    logic clk;
    logic rst;

    uart_peri_if uIf (
        .pclk   (clk),
        .presetn(~rst)
    );

    uart_apb_wrapper #(
        .CLK_FREQ_HZ(100_000_000),
        .BAUD_RATE  (9600)
    ) uDut (
        .pclk      (clk),
        .presetn   (~rst),
        .paddr     (uIf.paddr),
        .psel      (uIf.psel),
        .penable   (uIf.penable),
        .pwrite    (uIf.pwrite),
        .pwdata    (uIf.pwdata),
        .pstrb     (uIf.pstrb),
        .pready    (uIf.pready),
        .prdata    (uIf.prdata),
        .pslverr   (uIf.pslverr),
        .i_baud_sel(uIf.i_baud_sel),
        .i_uart_rx (uIf.i_uart_rx),
        .o_uart_tx (uIf.o_uart_tx)
    );

    initial begin
        clk = 1'b0;
        forever #(LP_CLK_PERIOD_NS / 2.0) clk = ~clk;
    end

    initial begin
        int runtime_cfg_fd;
        int runtime_cfg_rc;
        int runtime_baud_sel;
        int runtime_jitter_permille;
        int runtime_jitter_only;
        int runtime_quiet;

        rst = 1'b1;
        uIf.mon_timeout_hit = 1'b0;
        uIf.init_signals();
        if ($test$plusargs("UART_USE_RUNTIME_CFG")) begin
            runtime_cfg_fd = $fopen(LP_RUNTIME_CFG_PATH, "r");
            if (runtime_cfg_fd != 0) begin
                runtime_cfg_rc = $fscanf(
                    runtime_cfg_fd,
                    "%d %d %d %d",
                    runtime_baud_sel,
                    runtime_jitter_permille,
                    runtime_jitter_only,
                    runtime_quiet
                );
                $fclose(runtime_cfg_fd);
                if (runtime_cfg_rc == 4) begin
                    uIf.cfg_baud_sel = runtime_baud_sel;
                    uIf.cfg_jitter_permille = runtime_jitter_permille;
                    uIf.cfg_run_jitter_only = (runtime_jitter_only != 0);
                    uIf.cfg_quiet_mode = (runtime_quiet != 0);
                end else begin
                    $display(
                        "[%0t][UART_TB][WARN] runtime cfg parse failed rc=%0d path=%s",
                        $time,
                        runtime_cfg_rc,
                        LP_RUNTIME_CFG_PATH
                    );
                end
            end
        end
        if (!$value$plusargs("UART_BAUD_SEL=%d", uIf.cfg_baud_sel)) begin
            // Keep init/file configured value.
        end
        if (!$value$plusargs("UART_JITTER_PERMILLE=%d", uIf.cfg_jitter_permille)) begin
            // Keep init/file configured value.
        end
        if ($test$plusargs("UART_JITTER_ONLY")) begin
            uIf.cfg_run_jitter_only = 1'b1;
        end
        if ($test$plusargs("UART_QUIET")) begin
            uIf.cfg_quiet_mode = 1'b1;
        end
        repeat (10) @(posedge clk);
        rst = 1'b0;
    end

    property p_pready_always_high;
        @(posedge clk) uIf.pready === 1'b1;
    endproperty

    property p_tx_idle_during_reset;
        @(posedge clk) rst |-> (uIf.o_uart_tx === 1'b1);
    endproperty

    property p_apb_response_known;
        @(posedge clk)
        (uIf.psel && uIf.penable && !uIf.pwrite) |-> (!$isunknown(uIf.prdata) && !$isunknown(uIf.pslverr));
    endproperty

    a_pready_always_high: assert property (p_pready_always_high)
        else `UART_TB_FATAL("UART pready must stay high");

    a_tx_idle_during_reset: assert property (p_tx_idle_during_reset)
        else `UART_TB_FATAL("UART TX line must stay high during reset");

    a_apb_response_known: assert property (p_apb_response_known)
        else `UART_TB_FATAL("APB response contains X/Z during an active access");

    initial begin
        UartPeriDirectedTest tb_test;
        @(negedge rst);
        $display(
            "[%0t][UART_TB][CFG ] baud_sel=%0d jitter_permille=%0d jitter_only=%0d quiet=%0d",
            $time,
            uIf.cfg_baud_sel,
            uIf.cfg_jitter_permille,
            uIf.cfg_run_jitter_only,
            uIf.cfg_quiet_mode
        );
        tb_test = new(uIf);
        tb_test.run();
        if (tb_test.has_failures()) begin
            `UART_TB_FATAL("UART APB wrapper directed test failed");
        end
        $display("tb_uart_apb_wrapper PASSED");
        $finish;
    end

    initial begin
        repeat (1_000_000) @(posedge clk);
        uIf.mon_timeout_hit = 1'b1;
        `UART_TB_FATAL("Timeout waiting for UART peripheral test to complete");
    end
endmodule
