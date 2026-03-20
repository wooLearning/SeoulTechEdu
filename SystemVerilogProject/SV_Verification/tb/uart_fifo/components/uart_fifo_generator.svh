class uart_fifo_generator;
  mailbox #(uart_fifo_transaction) gen2drv_mbox;
  mailbox #(uart_fifo_transaction) exp_mbox;
  event gen_next_ev;

  function new(
    mailbox #(uart_fifo_transaction) gen2drv_mbox,
    mailbox #(uart_fifo_transaction) exp_mbox,
    event gen_next_ev
  );
    this.gen2drv_mbox = gen2drv_mbox;
    this.exp_mbox     = exp_mbox;
    this.gen_next_ev  = gen_next_ev;
  endfunction

  function automatic int unsigned pick_scenario(int iter, int run_count);
    int phase_len;
    phase_len = (run_count < 3) ? 1 : (run_count / 3);
    if (iter < phase_len) return uart_fifo_transaction::SC_FILL_THEN_DRAIN;
    if (iter < (phase_len * 2)) return uart_fifo_transaction::SC_BALANCED;
    return uart_fifo_transaction::SC_BURST_DRAIN;
  endfunction

  task run(int run_count);
    uart_fifo_transaction tr;
    uart_fifo_transaction drv_tr;
    uart_fifo_transaction exp_tr;

    for (int i = 0; i < run_count; i++) begin
      tr = new();
      if (!tr.randomize()) begin
        $fatal(1, "[UART-FIFO][GEN] randomization failed");
      end

      tr.scenario_id = pick_scenario(i, run_count);
      case (tr.scenario_id)
        uart_fifo_transaction::SC_FILL_THEN_DRAIN: begin
          tr.pop_count_after_send = ((i % 4) == 3) ? 4 : 0;
        end
        uart_fifo_transaction::SC_BALANCED: begin
          tr.pop_count_after_send = 1;
        end
        uart_fifo_transaction::SC_BURST_DRAIN: begin
          tr.pop_count_after_send = ((i % 2) == 1) ? 2 : 0;
        end
        default: tr.pop_count_after_send = 1;
      endcase

      tr.data = tr.data ^ (8'h5A + i[7:0]) ^ {5'b0, tr.scenario_id[2:0]};

      drv_tr = new();
      exp_tr = new();
      drv_tr.data = tr.data;
      drv_tr.scenario_id = tr.scenario_id;
      drv_tr.pop_count_after_send = tr.pop_count_after_send;
      exp_tr.data = tr.data;
      exp_tr.scenario_id = tr.scenario_id;
      exp_tr.pop_count_after_send = tr.pop_count_after_send;
      gen2drv_mbox.put(drv_tr);
      exp_mbox.put(exp_tr);
      @(gen_next_ev);
    end
    $display("[UART-FIFO][GEN] finished run_count=%0d", run_count);
  endtask
endclass
