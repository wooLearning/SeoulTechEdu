`ifndef UART_PERI_DRIVER_SVH
`define UART_PERI_DRIVER_SVH

class UartPeriDriver;
    UartPeriConfig            m_cfg;
    virtual uart_peri_if      vif_uart_peri;

    function new(
        virtual uart_peri_if vif_arg,
        UartPeriConfig cfg
    );
        vif_uart_peri = vif_arg;
        m_cfg = cfg;
    endfunction

    virtual task run();
        vif_uart_peri.apb_idle();
        vif_uart_peri.i_uart_rx <= 1'b1;
        wait (vif_uart_peri.presetn === 1'b1);
    endtask

    virtual task apb_write(
        input logic [7:0] addr,
        input logic [31:0] data,
        output bit slverr,
        input logic [3:0] strb = 4'h1
    );
        @(vif_uart_peri.drv_cb);
        vif_uart_peri.paddr   <= addr;
        vif_uart_peri.pwrite  <= 1'b1;
        vif_uart_peri.psel    <= 1'b1;
        vif_uart_peri.penable <= 1'b0;
        vif_uart_peri.pwdata  <= data;
        vif_uart_peri.pstrb   <= strb;

        @(vif_uart_peri.drv_cb);
        vif_uart_peri.penable <= 1'b1;

        @(vif_uart_peri.mon_cb);
        slverr = vif_uart_peri.pslverr;
        vif_uart_peri.apb_idle();
    endtask

    virtual task apb_read(
        input logic [7:0] addr,
        output logic [31:0] data,
        output bit slverr
    );
        @(vif_uart_peri.drv_cb);
        vif_uart_peri.paddr   <= addr;
        vif_uart_peri.pwrite  <= 1'b0;
        vif_uart_peri.psel    <= 1'b1;
        vif_uart_peri.penable <= 1'b0;
        vif_uart_peri.pwdata  <= 32'h0000_0000;
        vif_uart_peri.pstrb   <= 4'h0;

        @(vif_uart_peri.drv_cb);
        vif_uart_peri.penable <= 1'b1;

        @(vif_uart_peri.mon_cb);
        data   = vif_uart_peri.prdata;
        slverr = vif_uart_peri.pslverr;
        vif_uart_peri.apb_idle();
    endtask

    virtual task read_status(output logic [31:0] status);
        bit slverr;
        apb_read(8'h04, status, slverr);
        if (slverr) begin
            `UART_TB_FATAL("STATUS read returned PSLVERR");
        end
    endtask

    virtual task write_txdata(input byte unsigned data);
        bit slverr;
        apb_write(8'h08, {24'h0, data}, slverr);
        if (slverr) begin
            `UART_TB_FATAL($sformatf("TXDATA write failed for 0x%02h", data));
        end
    endtask

    virtual task read_rxdata(output byte unsigned data);
        logic [31:0] rdata;
        bit          slverr;
        apb_read(8'h0C, rdata, slverr);
        if (slverr) begin
            `UART_TB_FATAL("RXDATA read returned PSLVERR");
        end
        data = rdata[7:0];
    endtask

    virtual task clear_overflow();
        bit slverr;
        apb_write(8'h10, 32'h0000_0001, slverr);
        if (slverr) begin
            `UART_TB_FATAL("Failed to clear overflow flag");
        end
        apb_write(8'h10, 32'h0000_0000, slverr);
        if (slverr) begin
            `UART_TB_FATAL("Failed to release CONTROL after clearing overflow");
        end
    endtask

    virtual task clear_frame_error();
        bit slverr;
        apb_write(8'h10, 32'h0000_0002, slverr);
        if (slverr) begin
            `UART_TB_FATAL("Failed to clear frame error flag");
        end
        apb_write(8'h10, 32'h0000_0000, slverr);
        if (slverr) begin
            `UART_TB_FATAL("Failed to release CONTROL after clearing frame error");
        end
    endtask

    virtual task write_baudcfg(
        input bit use_apb_baud,
        input logic [3:0] baud_sel
    );
        bit slverr;
        apb_write(8'h14, {27'h0, use_apb_baud, baud_sel}, slverr);
        if (slverr) begin
            `UART_TB_FATAL("Failed to write BAUDCFG");
        end
    endtask

    virtual task read_baudcfg(output logic [31:0] baudcfg);
        bit slverr;
        apb_read(8'h14, baudcfg, slverr);
        if (slverr) begin
            `UART_TB_FATAL("BAUDCFG read returned PSLVERR");
        end
    endtask

    virtual task wait_status(
        input logic [31:0] mask,
        input logic [31:0] expected,
        output logic [31:0] status
    );
        int unsigned timeout_cycles;
        timeout_cycles = 0;
        while (timeout_cycles < m_cfg.m_apb_timeout_cycles) begin
            read_status(status);
            if ((status & mask) == expected) begin
                return;
            end
            timeout_cycles++;
        end
        `UART_TB_FATAL($sformatf(
            "Timed out waiting for status mask=0x%08h expected=0x%08h last=0x%08h",
            mask,
            expected,
            status
        ));
    endtask

    virtual task wait_tx_idle();
        logic [31:0] status;
        wait_status(32'h0000_0012, 32'h0000_0002, status);
    endtask

    virtual task wait_rx_not_empty();
        logic [31:0] status;
        wait_status(32'h0000_0008, 32'h0000_0000, status);
    endtask

    virtual task uart_send_byte(
        input byte unsigned data,
        input bit bad_stop = 1'b0
    );
        vif_uart_peri.send_uart_rx_frame(data, m_cfg.m_bit_period_ns, 0.0, bad_stop);
    endtask

    virtual task uart_send_byte_jittered(
        input byte unsigned data,
        input realtime jitter_ns,
        input bit bad_stop = 1'b0
    );
        vif_uart_peri.send_uart_rx_frame(data, m_cfg.m_bit_period_ns, jitter_ns, bad_stop);
    endtask

    virtual task uart_send_byte_with_period(
        input byte unsigned data,
        input realtime bit_period_ns,
        input bit bad_stop = 1'b0
    );
        vif_uart_peri.send_uart_rx_frame(data, bit_period_ns, 0.0, bad_stop);
    endtask
endclass

`endif
