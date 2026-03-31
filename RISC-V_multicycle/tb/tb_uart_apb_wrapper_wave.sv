`timescale 1ns / 1ps

/*
[TB_INFO_START]
Name: tb_uart_apb_wrapper_wave
Target: uart_apb_wrapper
Role: Simple waveform-oriented UART APB testbench focused on BAUDCFG and basic TX/RX activity
Scenario:
  - Measure the oversampling baud tick interval at the default switch-selected baud
  - Switch the active baud through APB BAUDCFG and confirm the tick interval changes
  - Send one APB TX byte and inject one RX byte at the new baud
CheckPoint:
  - Verify DUT reset and BAUDCFG default state first
  - Compare baud tick spacing before and after APB baud selection
  - Add explicit expected-value checks for auto-judgement
[TB_INFO_END]
*/

module tb_uart_apb_wrapper_wave;

    logic        pclk;
    logic        presetn;
    logic [7:0]  paddr;
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [31:0] pwdata;
    logic [3:0]  pstrb;
    logic        pready;
    logic [31:0] prdata;
    logic        pslverr;
    logic [3:0]  i_baud_sel;
    logic        i_uart_rx;
    logic        o_uart_tx;

    localparam realtime BIT_PERIOD_115200_NS = 8680.556;
    localparam realtime BIT_PERIOD_460800_NS = 2170.139;

    uart_apb_wrapper U_DUT (
        .pclk     (pclk),
        .presetn  (presetn),
        .paddr    (paddr),
        .psel     (psel),
        .penable  (penable),
        .pwrite   (pwrite),
        .pwdata   (pwdata),
        .pstrb    (pstrb),
        .pready   (pready),
        .prdata   (prdata),
        .pslverr  (pslverr),
        .i_baud_sel(i_baud_sel),
        .i_uart_rx(i_uart_rx),
        .o_uart_tx(o_uart_tx)
    );

    always #5 pclk = ~pclk;

    task automatic apb_idle();
        paddr   = 8'h00;
        psel    = 1'b0;
        penable = 1'b0;
        pwrite  = 1'b0;
        pwdata  = 32'h0000_0000;
        pstrb   = 4'h0;
    endtask

    task automatic apb_write(
        input logic [7:0] addr,
        input logic [31:0] data,
        input logic [3:0] strb,
        output logic slverr
    );
        @(posedge pclk);
        paddr   <= addr;
        pwrite  <= 1'b1;
        psel    <= 1'b1;
        penable <= 1'b0;
        pwdata  <= data;
        pstrb   <= strb;

        @(posedge pclk);
        penable <= 1'b1;

        @(posedge pclk);
        @(posedge pclk);
        slverr = pslverr;
        $display("[%0t][UART_WAVE_TB] WRITE addr=%02h data=%08h slverr=%0d active_sel=%0d phase_inc=%0d",
                 $time, addr, data, slverr, U_DUT.w_uart_baud_sel, U_DUT.U_UART_CORE.U_UART.U_BAUD_TICK_16.phase_inc);
        apb_idle();
    endtask

    task automatic apb_read(
        input logic [7:0] addr,
        output logic [31:0] data,
        output logic slverr
    );
        @(posedge pclk);
        paddr   <= addr;
        pwrite  <= 1'b0;
        psel    <= 1'b1;
        penable <= 1'b0;
        pwdata  <= 32'h0000_0000;
        pstrb   <= 4'h0;

        @(posedge pclk);
        penable <= 1'b1;

        @(posedge pclk);
        @(posedge pclk);
        data   = prdata;
        slverr = pslverr;
        $display("[%0t][UART_WAVE_TB] READ  addr=%02h data=%08h slverr=%0d active_sel=%0d phase_inc=%0d",
                 $time, addr, data, slverr, U_DUT.w_uart_baud_sel, U_DUT.U_UART_CORE.U_UART.U_BAUD_TICK_16.phase_inc);
        apb_idle();
    endtask

    task automatic apb_read_rxdata(
        output logic [31:0] data,
        output logic slverr
    );
        @(posedge pclk);
        paddr   <= 8'h0C;
        pwrite  <= 1'b0;
        psel    <= 1'b1;
        penable <= 1'b0;
        pwdata  <= 32'h0000_0000;
        pstrb   <= 4'h0;

        @(posedge pclk);
        penable <= 1'b1;

        #1;
        data   = prdata;
        slverr = pslverr;
        $display("[%0t][UART_WAVE_TB] READ  addr=0c data=%08h slverr=%0d active_sel=%0d phase_inc=%0d",
                 $time, data, slverr, U_DUT.w_uart_baud_sel, U_DUT.U_UART_CORE.U_UART.U_BAUD_TICK_16.phase_inc);

        @(posedge pclk);
        apb_idle();
    endtask

    task automatic measure_tick_cycles(
        input string label,
        input int sample_count,
        output int avg_cycles
    );
        int sample_idx;
        int cycles;
        int sum_cycles;
        begin
            sum_cycles = 0;
            do begin
                @(posedge pclk);
            end while (!U_DUT.U_UART_CORE.U_UART.w_b_tick);

            for (sample_idx = 0; sample_idx < sample_count; sample_idx = sample_idx + 1) begin
                cycles = 0;
                do begin
                    @(posedge pclk);
                    cycles = cycles + 1;
                end while (!U_DUT.U_UART_CORE.U_UART.w_b_tick);
                sum_cycles = sum_cycles + cycles;
            end

            avg_cycles = sum_cycles / sample_count;
            $display("[%0t][UART_WAVE_TB] %s avg_tick_cycles=%0d", $time, label, avg_cycles);
        end
    endtask

    task automatic send_uart_rx_frame(
        input byte unsigned data,
        input realtime bit_period_ns
    );
        i_uart_rx = 1'b1;
        #(bit_period_ns);
        i_uart_rx = 1'b0;
        #(bit_period_ns);

        for (int idx = 0; idx < 8; idx = idx + 1) begin
            i_uart_rx = data[idx];
            #(bit_period_ns);
        end

        i_uart_rx = 1'b1;
        #(bit_period_ns);
        i_uart_rx = 1'b1;
    endtask

    task automatic capture_uart_tx_byte(
        output byte unsigned data,
        output bit stop_ok,
        input realtime bit_period_ns
    );
        @(negedge o_uart_tx);
        #(bit_period_ns * 1.5);
        for (int idx = 0; idx < 8; idx = idx + 1) begin
            data[idx] = o_uart_tx;
            #(bit_period_ns);
        end
        stop_ok = (o_uart_tx === 1'b1);
        #(bit_period_ns);
    endtask

    task automatic wait_rx_not_empty();
        int          timeout_cycles;
        logic [31:0] status_data;
        logic        status_slverr;
        begin
            timeout_cycles = 0;
            status_data = 32'h0000_0008;
            while ((timeout_cycles < 200000) && (status_data[3] !== 1'b0)) begin
                apb_read(8'h04, status_data, status_slverr);
                if (status_slverr) $fatal(1, "UART STATUS read failed while waiting for RX");
                timeout_cycles = timeout_cycles + 1;
            end
            if (status_data[3] !== 1'b0) $fatal(1, "UART RX did not become non-empty");
        end
    endtask

    initial begin
        logic [31:0] rdata;
        logic        slverr;
        int          avg_115200;
        int          avg_460800;
        byte unsigned tx_byte;
        byte unsigned rx_byte;
        bit          stop_ok;

        pclk     = 1'b0;
        presetn  = 1'b0;
        i_baud_sel = 4'd5;
        i_uart_rx = 1'b1;
        apb_idle();

        repeat (4) @(posedge pclk);
        presetn = 1'b1;

        apb_read(8'h14, rdata, slverr);
        if (slverr || (rdata[11:8] !== 4'd5)) $fatal(1, "UART BAUDCFG reset mismatch");

        measure_tick_cycles("switch_115200", 32, avg_115200);

        apb_write(8'h14, 32'h0000_0017, 4'h1, slverr);
        if (slverr) $fatal(1, "UART BAUDCFG write failed");

        apb_read(8'h14, rdata, slverr);
        if (slverr || (rdata[11:8] !== 4'd7)) $fatal(1, "UART BAUDCFG active select mismatch");

        measure_tick_cycles("apb_460800", 32, avg_460800);
        if (avg_460800 >= avg_115200) $fatal(1, "UART baud tick did not get faster after BAUDCFG update");

        fork
            begin
                capture_uart_tx_byte(tx_byte, stop_ok, BIT_PERIOD_460800_NS);
                if (!stop_ok || (tx_byte !== 8'hA5)) $fatal(1, "UART TX byte mismatch");
                $display("[%0t][UART_WAVE_TB] TX byte observed = 0x%02h", $time, tx_byte);
            end
        join_none

        apb_write(8'h08, 32'h0000_00A5, 4'h1, slverr);
        if (slverr) $fatal(1, "UART TXDATA write failed");

        send_uart_rx_frame(8'h3C, BIT_PERIOD_460800_NS);
        wait_rx_not_empty();
        apb_read_rxdata(rdata, slverr);
        rx_byte = rdata[7:0];
        if (slverr || (rx_byte !== 8'h3C)) $fatal(1, "UART RX byte mismatch");

        $display("tb_uart_apb_wrapper_wave finished");
        $finish;
    end

    initial begin
        #2000000;
        $fatal(1, "tb_uart_apb_wrapper_wave timeout");
    end

endmodule
