// Top-level TB object connecting generator/driver/monitor/scoreboard for async FIFO.
class fifo_environment;
  virtual fifo_if vif;

  fifo_generator  gen;
  fifo_driver     drv;
  fifo_monitor    mon;
  fifo_scoreboard scb;

  mailbox #(fifo_transaction) gen2drv_mbox;
  mailbox #(fifo_transaction) mon2scb_mbox;
  event gen_next_ev;
  event scb_done_ev;

  function new(virtual fifo_if vif);
    this.vif = vif;

    gen2drv_mbox = new();
    mon2scb_mbox = new();

    gen = new(gen2drv_mbox, gen_next_ev);
    drv = new(gen2drv_mbox, vif, gen_next_ev);
    mon = new(mon2scb_mbox, vif);
    scb = new(mon2scb_mbox, scb_done_ev);
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
