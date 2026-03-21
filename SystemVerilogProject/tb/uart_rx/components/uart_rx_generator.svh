class uart_rx_generator;
  mailbox #(uart_rx_transaction) gen2drv_mbox;
  mailbox #(uart_rx_transaction) exp_mbox;
  event gen_next_ev;

  function new(
    mailbox #(uart_rx_transaction) gen2drv_mbox,
    mailbox #(uart_rx_transaction) exp_mbox,
    event gen_next_ev
  );
    this.gen2drv_mbox = gen2drv_mbox;
    this.exp_mbox     = exp_mbox;
    this.gen_next_ev  = gen_next_ev;
  endfunction

  task run(int run_count);
    uart_rx_transaction tr;
    uart_rx_transaction drv_tr;
    uart_rx_transaction exp_tr;

    for (int i = 0; i < run_count; i++) begin
      tr = new();
      if (i == run_count - 1) begin
        tr.scenario_id       = UART_RX_SC_INVALID_STOP;
        tr.expect_valid      = 1'b0;
        tr.data              = 8'h3C;
        tr.low_hold_ticks16x = 16 * 4;
        tr.observe_ticks16x  = 16 * 12;
      end
      else begin
        tr.scenario_id       = UART_RX_SC_VALID;
        tr.expect_valid      = 1'b1;
        tr.low_hold_ticks16x = 0;
        tr.observe_ticks16x  = 0;
        if (i == 0)       tr.data = 8'h55;
        else if (i == 1)  tr.data = 8'hA3;
        else if (i == 2)  tr.data = 8'h00;
        else if (i == 3)  tr.data = 8'hFF;
        else if (!tr.randomize()) begin
          $fatal(1, "[UART-RX][GEN] randomization failed");
        end
      end

      drv_tr = new();
      exp_tr = new();
      drv_tr.data              = tr.data;
      drv_tr.scenario_id       = tr.scenario_id;
      drv_tr.expect_valid      = tr.expect_valid;
      drv_tr.low_hold_ticks16x = tr.low_hold_ticks16x;
      drv_tr.observe_ticks16x  = tr.observe_ticks16x;
      exp_tr.data              = tr.data;
      exp_tr.scenario_id       = tr.scenario_id;
      exp_tr.expect_valid      = tr.expect_valid;
      exp_tr.low_hold_ticks16x = tr.low_hold_ticks16x;
      exp_tr.observe_ticks16x  = tr.observe_ticks16x;

      gen2drv_mbox.put(drv_tr);
      exp_mbox.put(exp_tr);
      @(gen_next_ev);
    end
    $display("[UART-RX][GEN] finished run_count=%0d", run_count);
  endtask
endclass
