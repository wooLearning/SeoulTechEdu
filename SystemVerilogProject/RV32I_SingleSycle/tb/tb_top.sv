`timescale 1ns / 1ps

module tb_top;
  localparam int LP_CLK_PERIOD = 10;
  localparam int LP_RAM_DEPTH  = 256;

  logic iClk;
  logic iRstn;
  logic wSawJalRedirect;
  logic wSawJalrRedirect;
  integer rErrCnt;
  integer idxMemInit;

  Top uTop (
    .iClk  (iClk),
    .iRstn (iRstn)
  );

  always #(LP_CLK_PERIOD / 2) iClk = ~iClk;

  task automatic check_reg(
    input int          idx,
    input logic [31:0] exp,
    input string       name
  );
    begin
      if (uTop.uDatapath.uRegfile.rMemReg[idx] !== exp) begin
        $display("[FAIL] %s : got=%0d (0x%08h) exp=%0d (0x%08h)",
          name,
          $signed(uTop.uDatapath.uRegfile.rMemReg[idx]),
          uTop.uDatapath.uRegfile.rMemReg[idx],
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
    iClk   = 1'b0;
    iRstn  = 1'b0;
    wSawJalRedirect  = 1'b0;
    wSawJalrRedirect = 1'b0;
    rErrCnt = 0;

    for (idxMemInit = 0; idxMemInit < LP_RAM_DEPTH; idxMemInit = idxMemInit + 1) begin
      uTop.uDataRam.rMemRam[idxMemInit] = 32'd0;
    end

    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);

    repeat (2) @(posedge iClk);
    iRstn = 1'b1;

    begin : wait_for_completion
      repeat (150) begin
        @(posedge iClk);
        #1;

        if (!wSawJalRedirect && (uTop.uPc.oPc == 32'd312)) begin
          wSawJalRedirect = 1'b1;
          $display("[PASS] jal redirect PC reached");
          check_reg(3,  32'd308, "jal link at redirect");
          check_reg(29, 32'd0,   "jal skipped sequential instruction");
        end

        if (!wSawJalrRedirect && (uTop.uPc.oPc == 32'd320)) begin
          wSawJalrRedirect = 1'b1;
          $display("[PASS] jalr redirect PC reached");
          check_reg(23, 32'd320, "jalr link at redirect");
          check_reg(29, 32'd0,   "jalr reached target before target executes");
        end

        if (uTop.uDatapath.uRegfile.rMemReg[29] == 32'd77) begin
          disable wait_for_completion;
        end
      end

      $display("[FAIL] Timeout waiting for program completion");
      rErrCnt = rErrCnt + 1;
    end

    if (!wSawJalRedirect) begin
      $display("[FAIL] jal redirect PC was never observed");
      rErrCnt = rErrCnt + 1;
    end

    if (!wSawJalrRedirect) begin
      $display("[FAIL] jalr redirect PC was never observed");
      rErrCnt = rErrCnt + 1;
    end

    if (uTop.uPc.oPc !== 32'd332) begin
      $display("[FAIL] PC final : got=%0d exp=332", uTop.uPc.oPc);
      rErrCnt = rErrCnt + 1;
    end else begin
      $display("[PASS] PC final");
    end

    check_reg(0,  32'd0,          "x0 hardwired zero");
    check_reg(4,  32'd18,         "R add");
    check_reg(5,  32'd12,         "R sub");
    check_reg(6,  32'd120,        "R sll");
    check_reg(7,  32'd1,          "R slt");
    check_reg(8,  32'd0,          "R sltu");
    check_reg(9,  32'd12,         "R xor");
    check_reg(10, 32'd1,          "R srl");
    check_reg(11, -32'sd2,        "R sra");
    check_reg(12, 32'd15,         "R or");
    check_reg(13, 32'd3,          "R and");
    check_reg(14, 32'd20,         "I addi");
    check_reg(15, 32'd1,          "I slti");
    check_reg(16, 32'd0,          "I sltiu");
    check_reg(17, 32'd12,         "I xori");
    check_reg(18, 32'd15,         "I ori");
    check_reg(19, 32'd7,          "I andi");
    check_reg(20, 32'd48,         "I slli");
    check_reg(21, 32'd7,          "I srli");
    check_reg(22, -32'sd4,        "I srai");
    check_reg(3,  32'h12345000,   "lui write-back");
    check_reg(23, 32'd4420,       "auipc write-back");
    check_reg(24, 32'd20,         "lw roundtrip");
    check_reg(25, 32'd6,          "branch not-taken count");
    check_reg(26, 32'd6,          "branch taken count");
    check_reg(27, 32'd0,          "backward branch loop counter");
    check_reg(28, 32'd1,          "backward branch exit flag");
    check_reg(1,  -32'sd3532,     "lh sign extension");
    check_reg(2,  32'd62004,      "lhu zero extension");
    check_reg(29, 32'd77,         "post-u-type execution");
    check_reg(30, -32'sd128,      "lb sign extension");
    check_reg(31, 32'd128,        "lbu / illegal no regwrite side effect");

    if (uTop.uDataRam.rMemRam[16] !== 32'd20) begin
      $display("[FAIL] Data memory word[16] : got=%0d exp=20", uTop.uDataRam.rMemRam[16]);
      rErrCnt = rErrCnt + 1;
    end else begin
      $display("[PASS] Data memory word[16]");
    end

    if (uTop.uDataRam.rMemRam[17] !== 32'hF2347F80) begin
      $display("[FAIL] Data memory word[17] : got=0x%08h exp=0xF2347F80", uTop.uDataRam.rMemRam[17]);
      rErrCnt = rErrCnt + 1;
    end else begin
      $display("[PASS] Data memory word[17]");
    end

    if (rErrCnt != 0) begin
      $display("tb_top FAILED with %0d error(s)", rErrCnt);
      $fatal(1, "tb_top failed");
      disable tb_main;
    end

    $display("tb_top PASSED");
    $finish;
  end

endmodule
