`timescale 1ns / 1ps

module tb_top_bubble;
  localparam int LP_CLK_PERIOD = 10;
  localparam int LP_RAM_DEPTH  = 256;

  logic iClk;
  logic iRstn;
  integer rErrCnt;
  integer idxMemInit;

  Top #(
    .P_USE_BUBBLE_ROM(1'b1)
  ) uTop (
    .iClk  (iClk),
    .iRstn (iRstn)
  );

  always #(LP_CLK_PERIOD / 2) iClk = ~iClk;

  task automatic check_mem(
    input int          idx,
    input logic [31:0] exp,
    input string       name
  );
    begin
      if (uTop.uDataRam.rMemRam[idx] !== exp) begin
        $display("[FAIL] %s : got=%0d (0x%08h) exp=%0d (0x%08h)",
          name,
          $signed(uTop.uDataRam.rMemRam[idx]),
          uTop.uDataRam.rMemRam[idx],
          $signed(exp),
          exp
        );
        rErrCnt = rErrCnt + 1;
      end else begin
        $display("[PASS] %s", name);
      end
    end
  endtask

  initial begin : tb_main
    iClk    = 1'b0;
    iRstn   = 1'b0;
    rErrCnt = 0;

    for (idxMemInit = 0; idxMemInit < LP_RAM_DEPTH; idxMemInit = idxMemInit + 1) begin
      uTop.uDataRam.rMemRam[idxMemInit] = 32'd0;
    end

    // Unsorted array at base address 64 (word index 16)
    uTop.uDataRam.rMemRam[16] = 32'd9;
    uTop.uDataRam.rMemRam[17] = 32'd3;
    uTop.uDataRam.rMemRam[18] = 32'd7;
    uTop.uDataRam.rMemRam[19] = 32'd1;
    uTop.uDataRam.rMemRam[20] = 32'd5;

    repeat (2) @(posedge iClk);
    iRstn = 1'b1;

    begin : wait_for_completion
      repeat (200) begin
        @(posedge iClk);
        #1;
        if (uTop.uDatapath.uRegfile.rMemReg[31] == 32'd1) begin
          disable wait_for_completion;
        end
      end

      $display("[FAIL] Timeout waiting for bubble-sort completion");
      rErrCnt = rErrCnt + 1;
    end

    check_mem(16, 32'd1, "sorted word[16]");
    check_mem(17, 32'd3, "sorted word[17]");
    check_mem(18, 32'd5, "sorted word[18]");
    check_mem(19, 32'd7, "sorted word[19]");
    check_mem(20, 32'd9, "sorted word[20]");

    if (uTop.uDatapath.uRegfile.rMemReg[31] !== 32'd1) begin
      $display("[FAIL] completion flag x31");
      rErrCnt = rErrCnt + 1;
    end else begin
      $display("[PASS] completion flag x31");
    end

    if (uTop.uDatapath.uRegfile.rMemReg[2] !== 32'd0) begin
      $display("[FAIL] outer loop counter x2 final");
      rErrCnt = rErrCnt + 1;
    end else begin
      $display("[PASS] outer loop counter x2 final");
    end

    if (rErrCnt != 0) begin
      $display("tb_top_bubble FAILED with %0d error(s)", rErrCnt);
      $fatal(1, "tb_top_bubble failed");
      disable tb_main;
    end

    $display("tb_top_bubble PASSED");
    $finish;
  end

endmodule
