`timescale 1ns / 1ps

/*
[MODULE_INFO_START]
Name: fnd_apb_wrapper
Role: APB wrapper for the 4-digit FND counter peripheral
Summary:
  - Exposes a single MMIO run/stop register for the FND counter
  - Keeps the FND peripheral focused on the minimum control surface
StateDescription:
  - APB write updates the run register only
  - FND_RUN[0] = 0 stops the counter, FND_RUN[0] = 1 runs the counter
[MODULE_INFO_END]
*/

module fnd_apb_wrapper #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer COUNT_TICK_CYCLES = 1_000_000
) (
    input  logic        pclk,
    input  logic        presetn,
    input  logic [7:0]  paddr,
    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    input  logic [31:0] pwdata,
    input  logic [3:0]  pstrb,
    output logic        pready,
    output logic [31:0] prdata,
    output logic        pslverr,
    output logic [6:0]  o_fnd_seg,
    output logic        o_fnd_dp,
    output logic [3:0]  o_fnd_an
);

    localparam [7:0] ADDR_RUN = 8'h00;

    logic w_apb_access;
    logic w_wr_en;
    logic r_run;

    assign w_apb_access = psel & penable;
    assign w_wr_en      = w_apb_access & pwrite;
    assign pready       = 1'b1;

    always_ff @(posedge pclk) begin
        if (!presetn) begin
            r_run <= 1'b0;
        end else if (w_wr_en && (paddr == ADDR_RUN) && pstrb[0]) begin
            r_run <= pwdata[0];
        end
    end

    fnd_counter_core #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .COUNT_TICK_CYCLES(COUNT_TICK_CYCLES)
    ) U_FND_CORE (
        .clk  (pclk),
        .rst  (~presetn),
        .i_run(r_run),
        .o_seg(o_fnd_seg),
        .o_dp (o_fnd_dp),
        .o_an (o_fnd_an)
    );

    always_comb begin
        prdata  = 32'h0000_0000;
        pslverr = 1'b0;

        if (w_apb_access && (paddr != ADDR_RUN)) begin
            pslverr = 1'b1;
        end else begin
            prdata[0] = r_run;
        end
    end

endmodule
