`ifndef UART_PERI_BASE_TEST_SVH
`define UART_PERI_BASE_TEST_SVH

class UartPeriBaseTest;
    UartPeriConfig       m_cfg;
    UartPeriEnv          m_env;
    virtual uart_peri_if vif_uart_peri;
    int unsigned         m_local_failures;

    function new(virtual uart_peri_if vif_arg);
        vif_uart_peri = vif_arg;
        m_cfg = new();
        m_local_failures = 0;
    endfunction

    virtual task configure();
        m_cfg.set_baud_sel(vif_uart_peri.cfg_baud_sel);
        m_cfg.m_jitter_ns = m_cfg.m_bit_period_ns * vif_uart_peri.cfg_jitter_permille / 1000.0;
        m_cfg.m_verbose = !vif_uart_peri.cfg_quiet_mode;
    endtask

    virtual function void check_eq32(
        input logic [31:0] actual,
        input logic [31:0] expected,
        input string name
    );
        if (actual !== expected) begin
            m_local_failures++;
            `UART_TB_ERR($sformatf("%s mismatch got=0x%08h exp=0x%08h", name, actual, expected));
        end else begin
            `UART_TB_INFO($sformatf("%s matched 0x%08h", name, actual));
        end
    endfunction

    virtual function void check_eq8(
        input byte unsigned actual,
        input byte unsigned expected,
        input string name
    );
        if (actual !== expected) begin
            m_local_failures++;
            `UART_TB_ERR($sformatf("%s mismatch got=0x%02h exp=0x%02h", name, actual, expected));
        end else begin
            `UART_TB_INFO($sformatf("%s matched 0x%02h", name, actual));
        end
    endfunction

    virtual function void check_true(input bit condition, input string name);
        if (!condition) begin
            m_local_failures++;
            `UART_TB_ERR($sformatf("%s expected true", name));
        end else begin
            `UART_TB_INFO($sformatf("%s observed", name));
        end
    endfunction

    virtual task read_apb_checked(
        input logic [7:0] addr,
        output logic [31:0] data,
        input string name
    );
        bit slverr;
        m_env.m_driver.apb_read(addr, data, slverr);
        if (slverr) begin
            m_local_failures++;
            `UART_TB_ERR($sformatf("%s read returned PSLVERR", name));
        end
    endtask

    virtual task write_apb_checked(
        input logic [7:0] addr,
        input logic [31:0] data,
        input string name
    );
        bit slverr;
        m_env.m_driver.apb_write(addr, data, slverr);
        if (slverr) begin
            m_local_failures++;
            `UART_TB_ERR($sformatf("%s write returned PSLVERR", name));
        end
    endtask

    virtual task wait_status(
        input logic [31:0] mask,
        input logic [31:0] expected,
        output logic [31:0] status
    );
        m_env.m_driver.wait_status(mask, expected, status);
    endtask

    virtual task run_body();
        `UART_TB_FATAL("Base test body must be overridden");
    endtask

    virtual task run();
        configure();
        m_env = new(vif_uart_peri, m_cfg);
        vif_uart_peri.i_baud_sel = m_cfg.m_baud_sel[3:0];
        fork
            m_env.run();
        join_none
        wait (vif_uart_peri.presetn === 1'b1);
        run_body();
        repeat (100) @(posedge vif_uart_peri.pclk);
        m_env.m_scoreboard.check_pending_empty();
    endtask

    virtual function bit has_failures();
        return (m_local_failures != 0) || m_env.has_failures();
    endfunction
endclass

`endif
