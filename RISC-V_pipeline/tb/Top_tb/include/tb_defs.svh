`ifndef TOP_TB_DEFS_SVH
`define TOP_TB_DEFS_SVH

`define TB_INFO(MSG) $display("[%0t][TB][INFO] %s", $time, MSG)
`define TB_WARN(MSG) $display("[%0t][TB][WARN] %s", $time, MSG)
`define TB_ERR(MSG)  $error("[%0t][TB][ERR ] %s", $time, MSG)

`endif
