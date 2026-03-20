/*
[TB_INFO_START]
Name: tb_uart_rx
Target: uart_rx
Role: Testbench for validating uart_rx
Scenario:
  - Directed valid frames for sanity patterns
  - Random valid frames for data diversity
  - Invalid frame with missing stop bit
CheckPoint:
  - Verify valid frames are received without mismatch
  - Verify malformed frame does not raise valid
  - Check tick pulse width and X/Z-free observable outputs
[TB_INFO_END]
*/

`timescale 1ns / 1ps

module tb_uart_rx;
  import uart_rx_tb_pkg::*;

  localparam int RUN_COUNT = 16;
  localparam int BAUD_RATE = 9600;
  localparam int FRAME_BITS = 10;
  localparam longint unsigned NS_PER_SEC = 64'd1_000_000_000;
  localparam longint unsigned FRAME_TIME_NS = (NS_PER_SEC * FRAME_BITS + BAUD_RATE - 1) / BAUD_RATE;
  localparam time WATCHDOG_NS = (RUN_COUNT + 8) * FRAME_TIME_NS * 2;

  uart_rx_if uart_rx_if_inst();
  uart_rx_environment env;
  wire wTick16x;

  uart_rx dut (
    .iClk    (uart_rx_if_inst.iClk),
    .iRst    (uart_rx_if_inst.iRst),
    .iTick16x(wTick16x),
    .iRx     (uart_rx_if_inst.iRx),
    .oData   (uart_rx_if_inst.oData),
    .oValid  (uart_rx_if_inst.oValid)
  );

  baud_rate_gen #(
    .CLK_FREQ (100_000_000),
    .BAUD_RATE(BAUD_RATE)
  ) u_baud_rate_gen (
    .iClk   (uart_rx_if_inst.iClk),
    .iRst   (uart_rx_if_inst.iRst),
    .oTick16x(wTick16x)
  );

  assign uart_rx_if_inst.iTick16x = wTick16x;

  always #5 uart_rx_if_inst.iClk = ~uart_rx_if_inst.iClk;

  property p_tick_one_cycle;
    @(posedge uart_rx_if_inst.iClk) disable iff (uart_rx_if_inst.iRst)
      wTick16x |=> !wTick16x;
  endproperty
  a_tick_one_cycle: assert property (p_tick_one_cycle)
    else $fatal(1, "[TB-UART-RX] wTick16x width violation");

  always @(posedge uart_rx_if_inst.iClk) begin
    assert (!$isunknown(uart_rx_if_inst.oValid))
      else $fatal(1, "[TB-UART-RX] oValid is X/Z t=%0t", $time);
    if (uart_rx_if_inst.oValid) begin
      assert (!$isunknown(uart_rx_if_inst.oData))
        else $fatal(1, "[TB-UART-RX] oData is X/Z when oValid=1 t=%0t", $time);
    end
  end

  initial begin
    $display("[TB] Starting UART RX verification");
    uart_rx_if_inst.iClk = 1'b0;
    uart_rx_if_inst.iRst = 1'b1;
    uart_rx_if_inst.iRx  = 1'b1;
    env = new(uart_rx_if_inst);
    env.run(RUN_COUNT);
    #20;
    $display("[TB] tb_uart_rx finished");
    $finish;
  end

  initial begin
    #WATCHDOG_NS;
    $fatal(1, "[TB-UART-RX] Simulation Timeout watchdog_ns=%0d run_count=%0d", WATCHDOG_NS, RUN_COUNT);
  end
endmodule
