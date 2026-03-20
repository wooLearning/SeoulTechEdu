// Top-level TB object connecting async_fifo TB components.
class async_fifo_environment;
  virtual async_fifo_if vif;

  async_fifo_generator  gen;
  async_fifo_driver     drv;
  async_fifo_monitor    mon;
  async_fifo_scoreboard scb;

  mailbox #(async_fifo_transaction) gen2drv_mbox;
  mailbox #(async_fifo_transaction) mon2scb_mbox;
  event gen_next_ev;
  event scb_done_ev;

  function new(virtual async_fifo_if vif);
    this.vif = vif;

    gen2drv_mbox = new();
    mon2scb_mbox = new();

    gen = new(gen2drv_mbox, gen_next_ev);
    drv = new(gen2drv_mbox, vif, gen_next_ev);
    mon = new(mon2scb_mbox, vif);
    scb = new(mon2scb_mbox, scb_done_ev);
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
    $display("[ENV] run finished");
  endtask
endclass
