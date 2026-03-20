class uart_async_fifo_monitor;
  uart_async_fifo_transaction tr;
  mailbox #(uart_async_fifo_transaction) mon2scb_mbox;
  virtual uart_async_fifo_if vif;

  function new(mailbox #(uart_async_fifo_transaction) mon2scb_mbox, virtual uart_async_fifo_if vif);
    this.mon2scb_mbox = mon2scb_mbox;
    this.vif = vif;
  endfunction

  task run();
    forever begin
      @(posedge vif.iRdClk);
      if (vif.oPopValid) begin
        tr = new();
        tr.data = vif.oPopData;
        tr.scenario_id = vif.tbScenarioId;
        mon2scb_mbox.put(tr);
        $display("[UART-AF][MON] popped byte=%0h t=%0t", tr.data, $time);
      end
    end
  endtask
endclass
