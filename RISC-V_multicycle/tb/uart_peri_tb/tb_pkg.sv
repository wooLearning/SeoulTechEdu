package uart_peri_tb_pkg;
    `include "include/tb_defs.svh"

    `include "objs/config.svh"
    `include "objs/transaction.svh"

    `include "components/driver.svh"
    `include "components/monitor.svh"

    `include "env/scoreboard.svh"
    `include "env/environment.svh"

    `include "tests/base_test.svh"
    `include "tests/test_uart_directed.svh"
endpackage
