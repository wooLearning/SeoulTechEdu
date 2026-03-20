/*
[TB_INFO_START]
Name: tb_uart_async_fifo
Target: uart_rx_async_fifo_bridge
Role: Testbench for validating UART RX + async FIFO bridge
Scenario:
  - Fill, balanced, and drain phases across independent write/read clocks
CheckPoint:
  - Verify UART RX bytes survive asynchronous buffering in order
  - Check boundary flags and X/Z-free pop data
[TB_INFO_END]
*/

`timescale 1ns / 1ps

module tb_uart_async_fifo;
  import uart_async_fifo_tb_pkg::*;
  localparam int RUN_COUNT = 18;
  localparam int BAUD_RATE = 9600;
  localparam int FRAME_BITS = 10;
  localparam longint unsigned NS_PER_SEC = 64'd1_000_000_000;
  localparam longint unsigned FRAME_TIME_NS = (NS_PER_SEC * FRAME_BITS + BAUD_RATE - 1) / BAUD_RATE;
  localparam time WATCHDOG_NS = (RUN_COUNT + 12) * FRAME_TIME_NS * 4;

  uart_async_fifo_if uart_async_fifo_if_inst();
  uart_async_fifo_environment env;
  wire wTick16x;

  uart_rx_async_fifo_bridge dut (
    .iWrClk(uart_async_fifo_if_inst.iWrClk),
    .iRdClk(uart_async_fifo_if_inst.iRdClk),
    .iRst(uart_async_fifo_if_inst.iRst),
    .iTick16x(wTick16x),
    .iRx(uart_async_fifo_if_inst.iRx),
    .iPop(uart_async_fifo_if_inst.iPop),
    .oPopData(uart_async_fifo_if_inst.oPopData),
    .oPopValid(uart_async_fifo_if_inst.oPopValid),
    .oFull(uart_async_fifo_if_inst.oFull),
    .oEmpty(uart_async_fifo_if_inst.oEmpty),
    .oRxData(uart_async_fifo_if_inst.oRxData),
    .oRxValid(uart_async_fifo_if_inst.oRxValid)
  );

  baud_rate_gen #(
    .CLK_FREQ(100_000_000),
    .BAUD_RATE(BAUD_RATE)
  ) u_baud_rate_gen (
    .iClk(uart_async_fifo_if_inst.iWrClk),
    .iRst(uart_async_fifo_if_inst.iRst),
    .oTick16x(wTick16x)
  );

  assign uart_async_fifo_if_inst.iTick16x = wTick16x;
  always #5 uart_async_fifo_if_inst.iWrClk = ~uart_async_fifo_if_inst.iWrClk;
  always #7 uart_async_fifo_if_inst.iRdClk = ~uart_async_fifo_if_inst.iRdClk;

  property p_tick_one_cycle;
    @(posedge uart_async_fifo_if_inst.iWrClk) disable iff (uart_async_fifo_if_inst.iRst)
      wTick16x |=> !wTick16x;
  endproperty
  a_tick_one_cycle: assert property (p_tick_one_cycle)
    else $fatal(1, "[TB-UART-AF] wTick16x width violation");

  always @(posedge uart_async_fifo_if_inst.iRdClk) begin
    assert (!(uart_async_fifo_if_inst.oFull && uart_async_fifo_if_inst.oEmpty))
      else $fatal(1, "[TB-UART-AF] full and empty both 1 t=%0t", $time);
    if (uart_async_fifo_if_inst.oPopValid) begin
      assert (!$isunknown(uart_async_fifo_if_inst.oPopData))
        else $fatal(1, "[TB-UART-AF] oPopData is X/Z when valid t=%0t", $time);
    end
  end

  initial begin
    $display("[TB] Starting UART+async FIFO verification");
    uart_async_fifo_if_inst.iWrClk = 1'b0;
    uart_async_fifo_if_inst.iRdClk = 1'b0;
    uart_async_fifo_if_inst.iRst = 1'b1;
    uart_async_fifo_if_inst.iRx = 1'b1;
    uart_async_fifo_if_inst.iPop = 1'b0;
    env = new(uart_async_fifo_if_inst);
    env.run(RUN_COUNT);
    #20;
    $display("[TB] tb_uart_async_fifo finished");
    $finish;
  end

  initial begin
    #WATCHDOG_NS;
    $fatal(1, "[TB-UART-AF] Simulation Timeout watchdog_ns=%0d run_count=%0d", WATCHDOG_NS, RUN_COUNT);
  end
endmodule
