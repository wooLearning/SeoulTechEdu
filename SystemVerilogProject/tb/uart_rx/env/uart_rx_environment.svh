class uart_rx_environment;
  virtual uart_rx_if vif;
  uart_rx_generator  gen;
  uart_rx_driver     drv;
  uart_rx_monitor    mon;
  uart_rx_scoreboard scb;

  mailbox #(uart_rx_transaction) gen2drv_mbox;
  mailbox #(uart_rx_transaction) exp_mbox;
  mailbox #(uart_rx_transaction) mon2scb_mbox;
  event gen_next_ev;
  event scb_done_ev;

  function new(virtual uart_rx_if vif);
    this.vif = vif;
    gen2drv_mbox = new();
    exp_mbox     = new();
    mon2scb_mbox = new();
    gen = new(gen2drv_mbox, exp_mbox, gen_next_ev);
    drv = new(gen2drv_mbox, vif, gen_next_ev);
    mon = new(mon2scb_mbox, vif);
    scb = new(exp_mbox, mon2scb_mbox, vif, scb_done_ev);
  endfunction

  task run(int run_count);
    drv.preset();
    fork
      gen.run(run_count);
      drv.run();
      mon.run();
      scb.run(run_count);
    join_none
    @(scb_done_ev);
    disable fork;
    $display("[UART-RX][ENV] run finished");
  endtask
endclass
