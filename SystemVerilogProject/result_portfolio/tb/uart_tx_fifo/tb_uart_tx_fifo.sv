/*
[TB_INFO_START]
Name: tb_uart_tx_fifo
Target: uart_tx_fifo_bridge
Role: Testbench for validating UART TX + FIFO bridge
Scenario:
  - Queue fill, balanced enqueue, and burst enqueue
  - Observe FIFO-to-UART launch ordering and serial line health
CheckPoint:
  - Verify queued bytes are handed off from FIFO to UART TX in order
  - Check tick pulse, TX launch handshake, and X/Z-free serial activity
[TB_INFO_END]
*/

`timescale 1ns / 1ps

module tb_uart_tx_fifo;
  import uart_tx_fifo_tb_pkg::*;
  localparam int RUN_COUNT = 18;
  localparam int BAUD_RATE = 9600;
  localparam int FRAME_BITS = 10;
  localparam longint unsigned NS_PER_SEC = 64'd1_000_000_000;
  localparam longint unsigned FRAME_TIME_NS = (NS_PER_SEC * FRAME_BITS + BAUD_RATE - 1) / BAUD_RATE;
  localparam time WATCHDOG_NS = (RUN_COUNT + 12) * FRAME_TIME_NS * 4;

  uart_tx_fifo_if uart_tx_fifo_if_inst();
  uart_tx_fifo_environment env;
  wire wTick16x;

  uart_tx_fifo_bridge dut (
    .iClk(uart_tx_fifo_if_inst.iClk),
    .iRst(uart_tx_fifo_if_inst.iRst),
    .iTick16x(wTick16x),
    .iPush(uart_tx_fifo_if_inst.iPush),
    .iPushData(uart_tx_fifo_if_inst.iPushData),
    .oFull(uart_tx_fifo_if_inst.oFull),
    .oEmpty(uart_tx_fifo_if_inst.oEmpty),
    .oTx(uart_tx_fifo_if_inst.oTx),
    .oBusy(uart_tx_fifo_if_inst.oBusy),
    .oLaunchData(uart_tx_fifo_if_inst.oLaunchData),
    .oLaunchValid(uart_tx_fifo_if_inst.oLaunchValid)
  );

  uart_rx sink_rx (
    .iClk(uart_tx_fifo_if_inst.iClk),
    .iRst(uart_tx_fifo_if_inst.iRst),
    .iTick16x(wTick16x),
    .iRx(uart_tx_fifo_if_inst.oTx),
    .oData(uart_tx_fifo_if_inst.oSinkData),
    .oValid(uart_tx_fifo_if_inst.oSinkValid)
  );

  baud_rate_gen #(
    .CLK_FREQ(100_000_000),
    .BAUD_RATE(BAUD_RATE)
  ) u_baud_rate_gen (
    .iClk(uart_tx_fifo_if_inst.iClk),
    .iRst(uart_tx_fifo_if_inst.iRst),
    .oTick16x(wTick16x)
  );

  assign uart_tx_fifo_if_inst.iTick16x = wTick16x;
  always #5 uart_tx_fifo_if_inst.iClk = ~uart_tx_fifo_if_inst.iClk;

  property p_tick_one_cycle;
    @(posedge uart_tx_fifo_if_inst.iClk) disable iff (uart_tx_fifo_if_inst.iRst)
      wTick16x |=> !wTick16x;
  endproperty
  a_tick_one_cycle: assert property (p_tick_one_cycle)
    else $fatal(1, "[TB-UART-TXF] wTick16x width violation");

  always @(posedge uart_tx_fifo_if_inst.iClk) begin
    if (uart_tx_fifo_if_inst.oLaunchValid) begin
      assert (!$isunknown(uart_tx_fifo_if_inst.oLaunchData))
        else $fatal(1, "[TB-UART-TXF] launch data is X/Z t=%0t", $time);
    end
    if (uart_tx_fifo_if_inst.oBusy) begin
      assert (!$isunknown(uart_tx_fifo_if_inst.oTx))
        else $fatal(1, "[TB-UART-TXF] serial TX is X/Z while busy t=%0t", $time);
    end
  end

  initial begin
    $display("[TB] Starting UART TX+FIFO verification");
    uart_tx_fifo_if_inst.iClk = 1'b0;
    uart_tx_fifo_if_inst.iRst = 1'b1;
    uart_tx_fifo_if_inst.iPush = 1'b0;
    uart_tx_fifo_if_inst.iPushData = '0;
    env = new(uart_tx_fifo_if_inst);
    env.run(RUN_COUNT);
    #20;
    $display("[TB] tb_uart_tx_fifo finished");
    $finish;
  end

  initial begin
    #WATCHDOG_NS;
    $fatal(1, "[TB-UART-TXF] Simulation Timeout watchdog_ns=%0d run_count=%0d", WATCHDOG_NS, RUN_COUNT);
  end
endmodule
