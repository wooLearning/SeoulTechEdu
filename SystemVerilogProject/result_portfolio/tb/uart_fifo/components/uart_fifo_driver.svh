class uart_fifo_driver;
  uart_fifo_transaction tr;
  mailbox #(uart_fifo_transaction) gen2drv_mbox;
  virtual uart_fifo_if vif;
  event gen_next_ev;

  function new(
    mailbox #(uart_fifo_transaction) gen2drv_mbox,
    virtual uart_fifo_if vif,
    event gen_next_ev
  );
    this.gen2drv_mbox = gen2drv_mbox;
    this.vif          = vif;
    this.gen_next_ev  = gen_next_ev;
  endfunction

  task preset();
    vif.iRst <= 1'b1;
    vif.iRx  <= 1'b1;
    vif.iPop <= 1'b0;
    repeat (6) @(posedge vif.iClk);
    vif.iRst <= 1'b0;
    repeat (4) @(posedge vif.iClk);
    $display("[UART-FIFO][DRV] reset released");
  endtask

  task wait_16x_ticks(int n_ticks);
    int cnt;
    cnt = 0;
    while (cnt < n_ticks) begin
      @(posedge vif.iClk);
      if (vif.iTick16x) begin
        cnt++;
      end
    end
  endtask

  task send_uart_byte(logic [7:0] data);
    vif.iRx <= 1'b0;
    wait_16x_ticks(16);
    for (int bit_idx = 0; bit_idx < 8; bit_idx++) begin
      vif.iRx <= data[bit_idx];
      wait_16x_ticks(16);
    end
    vif.iRx <= 1'b1;
    wait_16x_ticks(16);
  endtask

  task automatic wait_fifo_has_data(int max_cycles, output bit ok);
    ok = 1'b0;
    for (int i = 0; i < max_cycles; i++) begin
      @(posedge vif.iClk);
      if (!vif.oEmpty) begin
        ok = 1'b1;
        break;
      end
    end
  endtask

  task automatic pop_once_if_available();
    bit ready;
    ready = 1'b0;
    if (vif.oEmpty) begin
      wait_fifo_has_data(4000, ready);
    end
    else begin
      ready = 1'b1;
    end

    if (ready) begin
      @(negedge vif.iClk);
      vif.iPop <= 1'b1;
      @(negedge vif.iClk);
      vif.iPop <= 1'b0;
    end
  endtask

  task run(int run_count);
    assert (vif != null) else $fatal(1, "[UART-FIFO][DRV] vif is null");
    for (int i = 0; i < run_count; i++) begin
      gen2drv_mbox.get(tr);
      vif.tbScenarioId = tr.scenario_id;
      send_uart_byte(tr.data);
      repeat (4) @(posedge vif.iClk);
      for (int pop_idx = 0; pop_idx < tr.pop_count_after_send; pop_idx++) begin
        pop_once_if_available();
      end
      $display("[UART-FIFO][DRV] sent byte=%0h scenario=%s pop_after=%0d t=%0t",
        tr.data, tr.get_scenario_name(), tr.pop_count_after_send, $time);
      -> gen_next_ev;
    end

    while (!vif.oEmpty) begin
      pop_once_if_available();
    end
    $display("[UART-FIFO][DRV] drained remaining FIFO content");
  endtask
endclass
