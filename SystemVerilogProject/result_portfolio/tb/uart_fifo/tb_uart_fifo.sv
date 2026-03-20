/*
[TB_INFO_START]
Name: tb_uart_fifo
Target: uart_rx_fifo_bridge
Role: Testbench for validating UART RX + FIFO bridge
Scenario:
  - Fill-then-drain traffic to build FIFO depth
  - Balanced traffic with immediate drain
  - Burst traffic with delayed pop
CheckPoint:
  - Verify serial RX bytes are stored and popped in order
  - Verify no X/Z on bridge outputs and no illegal full+empty combination
  - Print summary and coverage for auto-judgement
[TB_INFO_END]
*/

`timescale 1ns / 1ps

module tb_uart_fifo;
  import uart_fifo_tb_pkg::*;

  localparam int RUN_COUNT = 24;
  localparam int BAUD_RATE = 9600;
  localparam int FRAME_BITS = 10;
  localparam longint unsigned NS_PER_SEC = 64'd1_000_000_000;
  localparam longint unsigned FRAME_TIME_NS = (NS_PER_SEC * FRAME_BITS + BAUD_RATE - 1) / BAUD_RATE;
  localparam time WATCHDOG_NS = (RUN_COUNT + 12) * FRAME_TIME_NS * 3;

  uart_fifo_if uart_fifo_if_inst();
  uart_fifo_environment env;
  wire wTick16x;

  uart_rx_fifo_bridge #(
    .AW(4),
    .DW(8)
  ) dut (
    .iClk    (uart_fifo_if_inst.iClk),
    .iRst    (uart_fifo_if_inst.iRst),
    .iTick16x(wTick16x),
    .iRx     (uart_fifo_if_inst.iRx),
    .iPop    (uart_fifo_if_inst.iPop),
    .oPopData(uart_fifo_if_inst.oPopData),
    .oPopValid(uart_fifo_if_inst.oPopValid),
    .oFull   (uart_fifo_if_inst.oFull),
    .oEmpty  (uart_fifo_if_inst.oEmpty),
    .oRxData (uart_fifo_if_inst.oRxData),
    .oRxValid(uart_fifo_if_inst.oRxValid)
  );

  baud_rate_gen #(
    .CLK_FREQ (100_000_000),
    .BAUD_RATE(BAUD_RATE)
  ) u_baud_rate_gen (
    .iClk   (uart_fifo_if_inst.iClk),
    .iRst   (uart_fifo_if_inst.iRst),
    .oTick16x(wTick16x)
  );

  assign uart_fifo_if_inst.iTick16x = wTick16x;

  always #5 uart_fifo_if_inst.iClk = ~uart_fifo_if_inst.iClk;

  property p_tick_one_cycle;
    @(posedge uart_fifo_if_inst.iClk) disable iff (uart_fifo_if_inst.iRst)
      wTick16x |=> !wTick16x;
  endproperty
  a_tick_one_cycle: assert property (p_tick_one_cycle)
    else $fatal(1, "[TB-UART-FIFO] wTick16x width violation");

  always @(posedge uart_fifo_if_inst.iClk) begin
    assert (!(uart_fifo_if_inst.oFull && uart_fifo_if_inst.oEmpty))
      else $fatal(1, "[TB-UART-FIFO] full and empty both 1 t=%0t", $time);
    assert (!$isunknown(uart_fifo_if_inst.oPopValid))
      else $fatal(1, "[TB-UART-FIFO] oPopValid is X/Z t=%0t", $time);
    if (uart_fifo_if_inst.oPopValid) begin
      assert (!$isunknown(uart_fifo_if_inst.oPopData))
        else $fatal(1, "[TB-UART-FIFO] oPopData is X/Z when valid t=%0t", $time);
    end
  end

  initial begin
    $display("[TB] Starting UART+FIFO bridge verification");
    uart_fifo_if_inst.iClk = 1'b0;
    uart_fifo_if_inst.iRst = 1'b1;
    uart_fifo_if_inst.iRx  = 1'b1;
    uart_fifo_if_inst.iPop = 1'b0;
    env = new(uart_fifo_if_inst);
    env.run(RUN_COUNT);
    #20;
    $display("[TB] tb_uart_fifo finished");
    $finish;
  end

  initial begin
    #WATCHDOG_NS;
    $fatal(1, "[TB-UART-FIFO] Simulation Timeout watchdog_ns=%0d run_count=%0d", WATCHDOG_NS, RUN_COUNT);
  end
endmodule
