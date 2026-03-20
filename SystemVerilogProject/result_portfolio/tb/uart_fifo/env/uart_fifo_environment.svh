class uart_fifo_environment;
  virtual uart_fifo_if vif;
  uart_fifo_generator  gen;
  uart_fifo_driver     drv;
  uart_fifo_monitor    mon;
  uart_fifo_scoreboard scb;

  mailbox #(uart_fifo_transaction) gen2drv_mbox;
  mailbox #(uart_fifo_transaction) exp_mbox;
  mailbox #(uart_fifo_transaction) mon2scb_mbox;
  event gen_next_ev;
  event scb_done_ev;

  function new(virtual uart_fifo_if vif);
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
      drv.run(run_count);
      mon.run();
      scb.run(run_count);
    join_none
    @(scb_done_ev);
    disable fork;
    $display("[UART-FIFO][ENV] run finished");
  endtask
endclass
