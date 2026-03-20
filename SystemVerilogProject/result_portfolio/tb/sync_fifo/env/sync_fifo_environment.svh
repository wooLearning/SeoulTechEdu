// Top-level TB object connecting sync FIFO TB components.
class sync_fifo_environment;
  virtual sync_fifo_if vif;

  sync_fifo_generator  gen;
  sync_fifo_driver     drv;
  sync_fifo_monitor    mon;
  sync_fifo_scoreboard scb;

  mailbox #(sync_fifo_transaction) gen2drv_mbox;
  mailbox #(sync_fifo_transaction) mon2scb_mbox;
  event gen_next_ev;
  event scb_done_ev;

  function new(virtual sync_fifo_if vif, int depth);
    this.vif = vif;

    gen2drv_mbox = new();
    mon2scb_mbox = new();

    gen = new(gen2drv_mbox, gen_next_ev);
    drv = new(gen2drv_mbox, vif);
    mon = new(mon2scb_mbox, vif);
    scb = new(mon2scb_mbox, gen_next_ev, scb_done_ev, depth);
  endfunction

  task run(int run_count);
    // Hold reset and initialize interface outputs before the parallel threads start.
    drv.preset();

    fork
      gen.run(run_count);
      drv.run();
      mon.run();
      scb.run(run_count);
    join_none

    // Scoreboard owns the end-of-test decision because it knows the target sample count.
    @(scb_done_ev);
    disable fork;
    $display("[ENV] run finished");
  endtask
endclass
