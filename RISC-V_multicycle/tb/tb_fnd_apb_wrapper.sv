`timescale 1ns / 1ps

/*
[TB_INFO_START]
Name: tb_fnd_apb_wrapper
Target: fnd_apb_wrapper
Role: Simple waveform-oriented APB testbench for the FND wrapper
Scenario:
  - Read the reset run bit
  - Start the FND counter through APB and observe the internal count increment
  - Stop the counter and confirm the count holds
CheckPoint:
  - Verify DUT reset and default outputs first
  - Compare APB-visible run state and internal counter behavior
  - Add explicit expected-value checks for auto-judgement
[TB_INFO_END]
*/

module tb_fnd_apb_wrapper;

    logic        pclk;
    logic        presetn;
    logic [7:0]  paddr;
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [31:0] pwdata;
    logic [3:0]  pstrb;
    logic        pready;
    logic [31:0] prdata;
    logic        pslverr;
    logic [6:0]  o_fnd_seg;
    logic        o_fnd_dp;
    logic [3:0]  o_fnd_an;

    fnd_apb_wrapper #(
        .CLK_FREQ_HZ(100),
        .COUNT_TICK_CYCLES(4)
    ) U_DUT (
        .pclk    (pclk),
        .presetn (presetn),
        .paddr   (paddr),
        .psel    (psel),
        .penable (penable),
        .pwrite  (pwrite),
        .pwdata  (pwdata),
        .pstrb   (pstrb),
        .pready  (pready),
        .prdata  (prdata),
        .pslverr (pslverr),
        .o_fnd_seg(o_fnd_seg),
        .o_fnd_dp (o_fnd_dp),
        .o_fnd_an (o_fnd_an)
    );

    always #5 pclk = ~pclk;

    task automatic apb_idle();
        paddr   = 8'h00;
        psel    = 1'b0;
        penable = 1'b0;
        pwrite  = 1'b0;
        pwdata  = 32'h0000_0000;
        pstrb   = 4'h0;
    endtask

    task automatic apb_write(
        input logic [7:0] addr,
        input logic [31:0] data,
        output logic slverr
    );
        @(posedge pclk);
        paddr   <= addr;
        pwrite  <= 1'b1;
        psel    <= 1'b1;
        penable <= 1'b0;
        pwdata  <= data;
        pstrb   <= 4'h1;

        @(posedge pclk);
        penable <= 1'b1;

        @(posedge pclk);
        @(posedge pclk);
        slverr = pslverr;
        $display("[%0t][FND_TB] WRITE addr=%02h data=%08h slverr=%0d run=%0d count=%0d an=%b seg=%b",
                 $time, addr, data, slverr, U_DUT.r_run, U_DUT.U_FND_CORE.r_count, o_fnd_an, o_fnd_seg);
        apb_idle();
    endtask

    task automatic apb_read(
        input logic [7:0] addr,
        output logic [31:0] data,
        output logic slverr
    );
        @(posedge pclk);
        paddr   <= addr;
        pwrite  <= 1'b0;
        psel    <= 1'b1;
        penable <= 1'b0;
        pwdata  <= 32'h0000_0000;
        pstrb   <= 4'h0;

        @(posedge pclk);
        penable <= 1'b1;

        @(posedge pclk);
        @(posedge pclk);
        data   = prdata;
        slverr = pslverr;
        $display("[%0t][FND_TB] READ  addr=%02h data=%08h slverr=%0d run=%0d count=%0d an=%b seg=%b",
                 $time, addr, data, slverr, U_DUT.r_run, U_DUT.U_FND_CORE.r_count, o_fnd_an, o_fnd_seg);
        apb_idle();
    endtask

    initial begin
        logic [31:0] rdata;
        logic        slverr;
        int unsigned count_hold;

        pclk    = 1'b0;
        presetn = 1'b0;
        apb_idle();

        repeat (4) @(posedge pclk);
        presetn = 1'b1;

        apb_read(8'h00, rdata, slverr);
        if (slverr || (rdata[0] !== 1'b0)) $fatal(1, "FND run reset mismatch");

        apb_write(8'h00, 32'h0000_0001, slverr);
        if (slverr) $fatal(1, "FND run write failed");

        repeat (20) @(posedge pclk);
        if (U_DUT.U_FND_CORE.r_count < 3) $fatal(1, "FND counter did not advance enough");

        apb_write(8'h00, 32'h0000_0000, slverr);
        if (slverr) $fatal(1, "FND stop write failed");

        count_hold = U_DUT.U_FND_CORE.r_count;
        repeat (10) @(posedge pclk);
        if (U_DUT.U_FND_CORE.r_count !== count_hold) $fatal(1, "FND counter did not hold when stopped");

        apb_read(8'h04, rdata, slverr);
        if (!slverr) $fatal(1, "Expected PSLVERR on invalid FND read");

        $display("tb_fnd_apb_wrapper finished");
        $finish;
    end

    initial begin
        #8000;
        $fatal(1, "tb_fnd_apb_wrapper timeout");
    end

endmodule
