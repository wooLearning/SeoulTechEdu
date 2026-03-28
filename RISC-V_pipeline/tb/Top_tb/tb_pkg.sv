package Top_tb_pkg;
    import spike_trace_pkg::*;

    `include "include/tb_defs.svh"

    `include "objs/transaction.svh"
    `include "objs/config.svh"

    `include "components/monitor.svh"

    `include "env/scoreboard.svh"
    `include "env/coverage.svh"
    `include "env/environment.svh"

    `include "tests/base_test.svh"
    `include "tests/test_01.svh"
    `include "tests/test_02.svh"
endpackage
