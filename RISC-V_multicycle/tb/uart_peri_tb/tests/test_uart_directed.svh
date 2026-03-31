`ifndef UART_PERI_DIRECTED_TEST_SVH
`define UART_PERI_DIRECTED_TEST_SVH

class UartPeriDirectedTest extends UartPeriBaseTest;
    function new(virtual uart_peri_if vif_arg);
        super.new(vif_arg);
    endfunction

    virtual task check_reset_and_id();
        logic [31:0] status;
        logic [31:0] id_reg;
        logic [31:0] baudcfg;

        read_apb_checked(8'h00, id_reg, "UART_ID");
        check_eq32(id_reg, 32'h5541_5254, "UART_ID");

        read_apb_checked(8'h04, status, "UART_STATUS(reset)");
        check_eq32(status[6:0], 7'b0001010, "UART_STATUS reset bits");

        m_env.m_driver.read_baudcfg(baudcfg);
        check_eq32(baudcfg[4:0], 5'h05, "BAUDCFG reset source/register bits");
        check_eq32(baudcfg[11:8], vif_uart_peri.i_baud_sel, "BAUDCFG reset active baud follows switch");
    endtask

    virtual task check_tx_path();
        byte unsigned tx_bytes[$];

        tx_bytes.push_back(8'h55);
        tx_bytes.push_back(8'hA3);
        tx_bytes.push_back(8'h0D);

        foreach (tx_bytes[idx]) begin
            m_env.m_scoreboard.expect_tx_byte(tx_bytes[idx]);
            m_env.m_driver.write_txdata(tx_bytes[idx]);
        end

        m_env.m_driver.wait_tx_idle();
    endtask

    virtual task check_rx_path();
        logic [31:0] status;
        byte unsigned rx_data;

        m_env.m_driver.uart_send_byte(8'h3C);
        m_env.m_driver.wait_rx_not_empty();
        m_env.m_driver.read_rxdata(rx_data);
        check_eq8(rx_data, 8'h3C, "RX normal byte");

        read_apb_checked(8'h04, status, "UART_STATUS(after RX pop)");
        check_true(status[3], "RX empty after RXDATA read");
    endtask

    virtual task check_jitter_tolerance();
        byte unsigned rx_data;

        `UART_TB_INFO($sformatf(
            "Jitter test baud=%0d bit_period_ns=%0.3f jitter_ns=%0.3f jitter_pct=%0.3f",
            m_cfg.m_baud_rate,
            m_cfg.m_bit_period_ns,
            m_cfg.m_jitter_ns,
            (m_cfg.m_jitter_ns * 100.0) / m_cfg.m_bit_period_ns
        ));
        m_env.m_driver.uart_send_byte_jittered(8'hA6, m_cfg.m_jitter_ns);
        m_env.m_driver.wait_rx_not_empty();
        m_env.m_driver.read_rxdata(rx_data);
        check_eq8(rx_data, 8'hA6, "RX jittered byte");
    endtask

    virtual task check_apb_baud_select();
        logic [31:0] baudcfg;
        byte unsigned rx_data;
        realtime apb_bit_period_ns;

        vif_uart_peri.i_baud_sel = 4'd0;
        m_env.m_driver.write_baudcfg(1'b1, 4'd7);
        m_env.m_driver.read_baudcfg(baudcfg);
        check_eq32(baudcfg[4:0], 5'h17, "BAUDCFG APB source/register bits");
        check_eq32(baudcfg[11:8], 4'd7, "BAUDCFG active baud switches to APB setting");

        apb_bit_period_ns = 1_000_000_000.0 / 460800.0;
        m_env.m_driver.uart_send_byte_with_period(8'h69, apb_bit_period_ns);
        m_env.m_driver.wait_rx_not_empty();
        m_env.m_driver.read_rxdata(rx_data);
        check_eq8(rx_data, 8'h69, "RX byte with APB-selected baud");

        m_env.m_driver.write_baudcfg(1'b0, 4'd7);
        m_env.m_driver.read_baudcfg(baudcfg);
        check_eq32(baudcfg[4:0], 5'h07, "BAUDCFG returns to switch source");
        check_eq32(baudcfg[11:8], vif_uart_peri.i_baud_sel, "BAUDCFG active baud returns to switch setting");
        vif_uart_peri.i_baud_sel = m_cfg.m_baud_sel[3:0];
    endtask

    virtual task check_frame_error();
        logic [31:0] status;

        m_env.m_driver.uart_send_byte(8'hF0, 1'b1);
        wait_status(32'h0000_0040, 32'h0000_0040, status);
        check_true(status[6], "Frame error sticky flag set");

        m_env.m_driver.clear_frame_error();
        read_apb_checked(8'h04, status, "UART_STATUS(after frame clear)");
        check_true(!status[6], "Frame error cleared");
    endtask

    virtual task check_rx_overflow();
        logic [31:0] status;
        byte unsigned rx_data;
        int unsigned idx;

        for (idx = 0; idx < 32; idx++) begin
            m_env.m_driver.uart_send_byte(idx[7:0]);
        end
        m_env.m_driver.uart_send_byte(8'hFF);

        wait_status(32'h0000_0020, 32'h0000_0020, status);
        check_true(status[5], "RX overflow sticky flag set");

        for (idx = 0; idx < 32; idx++) begin
            m_env.m_driver.wait_rx_not_empty();
            m_env.m_driver.read_rxdata(rx_data);
            check_eq8(rx_data, idx[7:0], $sformatf("RX overflow drain[%0d]", idx));
        end

        m_env.m_driver.clear_overflow();
        read_apb_checked(8'h04, status, "UART_STATUS(after overflow clear)");
        check_true(!status[5], "RX overflow cleared");
        check_true(status[3], "RX empty after overflow drain");
    endtask

    virtual task run_body();
        bit jitter_only_mode;

        jitter_only_mode = (vif_uart_peri.cfg_run_jitter_only == 1'b1);
        `UART_TB_INFO("Directed UART peripheral test start");
        `UART_TB_INFO($sformatf("Run mode jitter_only=%0d", jitter_only_mode));
        check_reset_and_id();
        if (!jitter_only_mode) begin
            check_tx_path();
            check_rx_path();
            check_apb_baud_select();
        end
        check_jitter_tolerance();
        if (!jitter_only_mode) begin
            check_frame_error();
            check_rx_overflow();
        end
        `UART_TB_INFO("Directed UART peripheral test finished");
    endtask
endclass

`endif
