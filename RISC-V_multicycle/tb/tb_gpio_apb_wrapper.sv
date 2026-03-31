`timescale 1ns / 1ps

/*
[TB_INFO_START]
Name: tb_gpio_apb_wrapper
Target: gpio_apb_wrapper
Role: Simple waveform-oriented APB testbench for the bidirectional GPIO wrapper
Scenario:
  - Configure some GPIO bits as outputs and some as inputs
  - Observe APB-visible input data and external bus drive behavior
  - Change direction/output settings once to make waveforms easy to inspect
CheckPoint:
  - Verify reset defaults first
  - Confirm direction control affects both driven bus value and input sampling
  - Add explicit expected-value checks for auto-judgement
[TB_INFO_END]
*/

module tb_gpio_apb_wrapper;

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
    tri   [15:0] io_gpio;
    logic [15:0] r_gpio_drv;
    logic [15:0] r_gpio_oe;

    genvar idx;
    generate
        for (idx = 0; idx < 16; idx = idx + 1) begin
            assign io_gpio[idx] = r_gpio_oe[idx] ? r_gpio_drv[idx] : 1'bz;
        end
    endgenerate

    gpio_apb_wrapper U_DUT (
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
        .io_gpio (io_gpio)
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
        $display("[%0t][GPIO_TB] WRITE addr=%02h data=%08h slverr=%0d io_gpio=%h",
                 $time, addr, data, slverr, io_gpio);
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
        $display("[%0t][GPIO_TB] READ  addr=%02h data=%08h slverr=%0d io_gpio=%h",
                 $time, addr, data, slverr, io_gpio);
        apb_idle();
    endtask

    initial begin
        logic [31:0] rdata;
        logic        slverr;

        pclk      = 1'b0;
        presetn   = 1'b0;
        r_gpio_drv = 16'h00A0;
        r_gpio_oe  = 16'h00F0;
        apb_idle();

        repeat (4) @(posedge pclk);
        presetn = 1'b1;

        apb_write(8'h00, 32'h0000_000F, slverr);
        if (slverr) $fatal(1, "GPIO CTL write phase-1 failed");

        apb_write(8'h04, 32'h0000_0005, slverr);
        if (slverr) $fatal(1, "GPIO ODATA write phase-1 failed");

        apb_read(8'h08, rdata, slverr);
        if (slverr || (rdata[7:0] !== 8'hA0)) $fatal(1, "GPIO IDATA phase-1 mismatch");
        if (io_gpio[3:0] !== 4'h5) $fatal(1, "GPIO output nibble phase-1 mismatch");

        // Release the external bus first so the DUT can switch direction without contention.
        r_gpio_drv = 16'h0000;
        r_gpio_oe  = 16'h0000;
        apb_write(8'h00, 32'h0000_00F0, slverr);
        if (slverr) $fatal(1, "GPIO CTL write phase-2 failed");

        apb_write(8'h04, 32'h0000_00C0, slverr);
        if (slverr) $fatal(1, "GPIO ODATA write phase-2 failed");

        r_gpio_drv = 16'h0003;
        r_gpio_oe  = 16'h000F;
        repeat (2) @(posedge pclk);

        apb_read(8'h08, rdata, slverr);
        if (slverr || (rdata[3:0] !== 4'h3)) $fatal(1, "GPIO IDATA phase-2 mismatch");
        if (io_gpio[7:4] !== 4'hC) $fatal(1, "GPIO output nibble phase-2 mismatch");

        $display("tb_gpio_apb_wrapper finished");
        $finish;
    end

    initial begin
        #6000;
        $fatal(1, "tb_gpio_apb_wrapper timeout");
    end

endmodule
