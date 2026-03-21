class uart_fifo_monitor;
  uart_fifo_transaction tr;
  mailbox #(uart_fifo_transaction) mon2scb_mbox;
  virtual uart_fifo_if vif;

  function new(mailbox #(uart_fifo_transaction) mon2scb_mbox, virtual uart_fifo_if vif);
    this.mon2scb_mbox = mon2scb_mbox;
    this.vif          = vif;
  endfunction

  task run();
    forever begin
      @(posedge vif.iClk);
      if (vif.oPopValid) begin
        tr = new();
        tr.data = vif.oPopData;
        tr.scenario_id = vif.tbScenarioId;
        mon2scb_mbox.put(tr);
        $display("[UART-FIFO][MON] popped byte=%0h full=%0b empty=%0b t=%0t",
          tr.data, vif.oFull, vif.oEmpty, $time);
      end
    end
  endtask
endclass
