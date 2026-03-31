`timescale 1ns / 1ps

/*
[TB_INFO_START]
Name: tb_gpi_apb_wrapper
Target: gpi_apb_wrapper
Role: Simple waveform-oriented APB testbench for the GPI wrapper
Scenario:
  - Program the GPI mask register and read masked input data
  - Change external input stimulus and observe APB-visible data updates
  - Exercise one invalid write path for waveform/log visibility
CheckPoint:
  - Verify reset defaults first
  - Confirm APB-visible masking behavior against external inputs
  - Add explicit expected-value checks for auto-judgement
[TB_INFO_END]
*/

module tb_gpi_apb_wrapper;

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
    logic [15:0] i_gpi;

    gpi_apb_wrapper U_DUT (
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
        .i_gpi   (i_gpi)
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
        pstrb   <= 4'h3;

        @(posedge pclk);
        penable <= 1'b1;

        @(posedge pclk);
        @(posedge pclk);
        slverr = pslverr;
        $display("[%0t][GPI_TB] WRITE addr=%02h data=%08h slverr=%0d i_gpi=%h",
                 $time, addr, data, slverr, i_gpi);
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
        $display("[%0t][GPI_TB] READ  addr=%02h data=%08h slverr=%0d i_gpi=%h",
                 $time, addr, data, slverr, i_gpi);
        apb_idle();
    endtask

    initial begin
        logic [31:0] rdata;
        logic        slverr;

        pclk    = 1'b0;
        presetn = 1'b0;
        i_gpi   = 16'hA55A;
        apb_idle();

        repeat (4) @(posedge pclk);
        presetn = 1'b1;

        apb_read(8'h00, rdata, slverr);
        if (slverr || (rdata[15:0] !== 16'h0000)) $fatal(1, "GPI CTL reset mismatch");

        apb_write(8'h00, 32'h0000_00FF, slverr);
        if (slverr) $fatal(1, "GPI CTL write failed");

        apb_read(8'h04, rdata, slverr);
        if (slverr || (rdata[15:0] !== 16'h005A)) $fatal(1, "GPI IDATA masked read mismatch");

        i_gpi = 16'h00A5;
        repeat (2) @(posedge pclk);
        apb_read(8'h04, rdata, slverr);
        if (slverr || (rdata[15:0] !== 16'h00A5)) $fatal(1, "GPI IDATA update mismatch");

        apb_write(8'h04, 32'h0000_FFFF, slverr);
        if (!slverr) $fatal(1, "Expected PSLVERR on GPI IDATA write");

        $display("tb_gpi_apb_wrapper finished");
        $finish;
    end

    initial begin
        #5000;
        $fatal(1, "tb_gpi_apb_wrapper timeout");
    end

endmodule
