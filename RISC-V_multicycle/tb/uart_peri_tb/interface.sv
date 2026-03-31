interface uart_peri_if(
    input logic pclk,
    input logic presetn
);
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

    logic        mon_timeout_hit;
    int unsigned cfg_baud_sel;
    int unsigned cfg_jitter_permille;
    bit          cfg_run_jitter_only;
    bit          cfg_quiet_mode;

    clocking drv_cb @(posedge pclk);
        default input #1step output #0;
        output paddr;
        output psel;
        output penable;
        output pwrite;
        output pwdata;
        output pstrb;
        output i_baud_sel;
        input  pready;
        input  prdata;
        input  pslverr;
    endclocking

    clocking mon_cb @(posedge pclk);
        default input #1step output #0;
        input paddr;
        input psel;
        input penable;
        input pwrite;
        input pwdata;
        input pstrb;
        input pready;
        input prdata;
        input pslverr;
        input i_baud_sel;
        input i_uart_rx;
        input o_uart_tx;
    endclocking

    task automatic apb_idle();
        paddr   <= 8'h00;
        psel    <= 1'b0;
        penable <= 1'b0;
        pwrite  <= 1'b0;
        pwdata  <= 32'h0000_0000;
        pstrb   <= 4'h0;
    endtask

    task automatic init_signals();
        apb_idle();
        i_uart_rx  <= 1'b1;
        i_baud_sel <= 4'd5;
        cfg_baud_sel = 4'd5;
        cfg_jitter_permille = 80;
        cfg_run_jitter_only = 1'b0;
        cfg_quiet_mode = 1'b0;
    endtask

    task automatic wait_line_interval(
        input realtime nominal_ns,
        input realtime jitter_ns,
        inout bit jitter_polarity
    );
        realtime delay_ns;
        delay_ns = nominal_ns;
        if (jitter_ns > 0.0) begin
            if (jitter_polarity) begin
                delay_ns = nominal_ns + jitter_ns;
            end else begin
                delay_ns = nominal_ns - jitter_ns;
            end
            jitter_polarity = ~jitter_polarity;
        end
        #(delay_ns);
    endtask

    task automatic send_uart_rx_frame(
        input byte unsigned data,
        input realtime bit_period_ns,
        input realtime jitter_ns,
        input bit bad_stop
    );
        bit jitter_polarity;
        jitter_polarity = 1'b0;

        i_uart_rx <= 1'b1;
        #(bit_period_ns);

        i_uart_rx <= 1'b0;
        wait_line_interval(bit_period_ns, jitter_ns, jitter_polarity);

        for (int idx = 0; idx < 8; idx++) begin
            i_uart_rx <= data[idx];
            wait_line_interval(bit_period_ns, jitter_ns, jitter_polarity);
        end

        i_uart_rx <= (bad_stop) ? 1'b0 : 1'b1;
        wait_line_interval(bit_period_ns, jitter_ns, jitter_polarity);

        i_uart_rx <= 1'b1;
        #(bit_period_ns);
    endtask

    task automatic capture_uart_tx_frame(
        output byte unsigned data,
        output bit stop_ok,
        input realtime bit_period_ns
    );
        bit prev_tx;

        data = 8'h00;
        stop_ok = 1'b1;
        do begin
            @(mon_cb);
        end while (mon_cb.o_uart_tx !== 1'b1);

        prev_tx = mon_cb.o_uart_tx;
        forever begin
            @(mon_cb);
            if ((prev_tx === 1'b1) && (mon_cb.o_uart_tx === 1'b0)) begin
                break;
            end
            prev_tx = mon_cb.o_uart_tx;
        end
        #(bit_period_ns * 1.5);
        for (int idx = 0; idx < 8; idx++) begin
            data[idx] = o_uart_tx;
            #(bit_period_ns);
        end
        stop_ok = (o_uart_tx === 1'b1);
    endtask
endinterface
