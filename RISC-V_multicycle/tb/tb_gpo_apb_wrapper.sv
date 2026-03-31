`timescale 1ns / 1ps

/*
[TB_INFO_START]
Name: tb_gpo_apb_wrapper
Target: gpo_apb_wrapper
Role: Simple waveform-oriented APB testbench for the GPO wrapper
Scenario:
  - Write GPO control and output data through APB
  - Read back registers and observe driven output pins
  - Exercise one invalid APB access for waveform/log visibility
CheckPoint:
  - Verify reset defaults first
  - Confirm APB write/read behavior and visible output drive
  - Add explicit expected-value checks for auto-judgement
[TB_INFO_END]
*/

module tb_gpo_apb_wrapper;

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
    logic [15:0] io_gpo;

    gpo_apb_wrapper U_DUT (
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
        .io_gpo  (io_gpo)
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
        input logic [3:0] strb,
        output logic slverr
    );
        @(posedge pclk);
        paddr   <= addr;
        pwrite  <= 1'b1;
        psel    <= 1'b1;
        penable <= 1'b0;
        pwdata  <= data;
        pstrb   <= strb;

        @(posedge pclk);
        penable <= 1'b1;

        @(posedge pclk);
        @(posedge pclk);
        slverr = pslverr;
        $display("[%0t][GPO_TB] WRITE addr=%02h data=%08h slverr=%0d io_gpo=%h",
                 $time, addr, data, slverr, io_gpo);
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
        $display("[%0t][GPO_TB] READ  addr=%02h data=%08h slverr=%0d io_gpo=%h",
                 $time, addr, data, slverr, io_gpo);
        apb_idle();
    endtask

    initial begin
        logic [31:0] rdata;
        logic        slverr;

        pclk    = 1'b0;
        presetn = 1'b0;
        apb_idle();

        repeat (4) @(posedge pclk);
        presetn = 1'b1;

        apb_read(8'h00, rdata, slverr);
        if (slverr || (rdata[15:0] !== 16'h0000)) $fatal(1, "GPO CTL reset mismatch");

        apb_write(8'h00, 32'h0000_00FF, 4'h3, slverr);
        if (slverr) $fatal(1, "GPO CTL write failed");

        apb_write(8'h04, 32'h0000_00A5, 4'h3, slverr);
        if (slverr) $fatal(1, "GPO ODATA write failed");

        apb_read(8'h00, rdata, slverr);
        if (slverr || (rdata[15:0] !== 16'h00FF)) $fatal(1, "GPO CTL readback mismatch");

        apb_read(8'h04, rdata, slverr);
        if (slverr || (rdata[15:0] !== 16'h00A5)) $fatal(1, "GPO ODATA readback mismatch");

        if (io_gpo[7:0] !== 8'hA5) $fatal(1, "GPO low-byte drive mismatch");
        if (io_gpo[15:8] !== 8'hzz) $fatal(1, "GPO high-byte should be high-Z");

        apb_write(8'h08, 32'h0000_1234, 4'h3, slverr);
        if (!slverr) $fatal(1, "Expected PSLVERR on invalid GPO write");

        $display("tb_gpo_apb_wrapper finished");
        $finish;
    end

    initial begin
        #5000;
        $fatal(1, "tb_gpo_apb_wrapper timeout");
    end

endmodule
