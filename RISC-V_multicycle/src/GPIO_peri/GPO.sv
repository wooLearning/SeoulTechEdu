`timescale 1ns / 1ps

module GPO (
    input               PCLK,
    input               PRESET,
    input        [31:0] PADDR,
    input        [31:0] PWDATA,
    input               PWRITE,
    input               PENABLE,
    input               PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,

    output logic [15:0] GPO_OUT
);

    localparam [11:0] GPO_CTL_ADDR = 12'h000;
    localparam [11:0] GPO_ODATA_ADDR = 12'h004;

    logic [15:0] GPO_ODATA_REG, GPO_CTL_REG;

    assign PREADY = (PENABLE & PSEL) ? 1'b1 : 1'b0;

    assign PRDATA = (PADDR[11:0] == GPO_CTL_ADDR)   ? {16'h0000,GPO_CTL_REG}  : 
                    (PADDR[11:0] == GPO_ODATA_ADDR) ? {16'h0000,GPO_ODATA_REG}: 32'hxxxx_xxxx;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            GPO_CTL_REG   <= 16'h0000;
            GPO_ODATA_REG <= 16'h0000;
        end else begin
            if (PREADY & PWRITE) begin
                case (PADDR[11:0])
                    GPO_CTL_ADDR:   GPO_CTL_REG <= PWDATA[15:0];  // GPO CTL REG
                    GPO_ODATA_ADDR: GPO_ODATA_REG <= PWDATA[15:0];
                endcase
            end
        end
    end

    genvar i;
    generate
        for (i = 0; i < 16; i++) begin
            assign GPO_OUT[i] = (GPO_CTL_REG[i]) ? GPO_ODATA_REG[i] : 1'bz;
        end
    endgenerate

endmodule




/*
    logic we;

    assign we = PENABLE & PSEL & PWRITE;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            PREADY <= 1'b0;
        end else begin
            PREADY <= 1'b1;
        end
    end

    oreg U_OREG (
        .clk  (PCLK),
        .rst  (PRESET),
        .wdata(PWDATA[7:0]),
        .we   (we),
        .GPO0 (GPO0),
        .GPO1 (GPO1),
        .GPO2 (GPO2),
        .GPO3 (GPO3),
        .GPO4 (GPO4),
        .GPO5 (GPO5),
        .GPO6 (GPO6),
        .GPO7 (GPO7)
    );

endmodule

module oreg (
    input              clk,
    input              rst,
    input        [7:0] wdata,
    input              we,
    output logic       GPO0,
    output logic       GPO1,
    output logic       GPO2,
    output logic       GPO3,
    output logic       GPO4,
    output logic       GPO5,
    output logic       GPO6,
    output logic       GPO7
);

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            GPO0 <= 1'b0;
            GPO1 <= 1'b0;
            GPO2 <= 1'b0;
            GPO3 <= 1'b0;
            GPO4 <= 1'b0;
            GPO5 <= 1'b0;
            GPO6 <= 1'b0;
            GPO7 <= 1'b0;
        end else begin
            if (we) begin
                GPO0 <= wdata[0];
                GPO1 <= wdata[1];
                GPO2 <= wdata[2];
                GPO3 <= wdata[3];
                GPO4 <= wdata[4];
                GPO5 <= wdata[5];
                GPO6 <= wdata[6];
                GPO7 <= wdata[7];
            end
        end
    end

endmodule
*/
