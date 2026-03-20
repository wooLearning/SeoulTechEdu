// Package that bundles all sync FIFO verification classes.
package sync_fifo_tb_pkg;
  `include "objs/sync_fifo_transaction.svh"
  `include "components/sync_fifo_generator.svh"
  `include "components/sync_fifo_driver.svh"
  `include "components/sync_fifo_monitor.svh"
  `include "components/sync_fifo_coverage.svh"
  `include "components/sync_fifo_scoreboard.svh"
  `include "env/sync_fifo_environment.svh"
endpackage
