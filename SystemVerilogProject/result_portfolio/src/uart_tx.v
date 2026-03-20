/*
[MODULE_INFO_START]
Name: uart_tx
Role: UART Transmitter (parallel to serial)
Summary:
  - Serializes `iData` to `oTx` using start bit, 8 data bits, and stop bit
  - Uses a 16x oversampling tick `iTick16x`
  - Accepts a one-cycle `iValid` strobe while idle
  - Keeps `oBusy` high while transmission is in progress
StateDescription:
  - IDLE: Wait for transmit request
  - START: Drive start bit low
  - DATA: Shift 8 data bits LSB first
  - STOP: Drive stop bit high
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module uart_tx (
  input  wire       iClk,
  input  wire       iRst,
  input  wire       iTick16x,
  input  wire [7:0] iData,
  input  wire       iValid,
  output wire       oTx,
  output wire       oBusy
);
  localparam [1:0] IDLE  = 2'b00;
  localparam [1:0] START = 2'b01;
  localparam [1:0] DATA  = 2'b10;
  localparam [1:0] STOP  = 2'b11;

  reg [1:0] rCurState;
  reg [1:0] rNxtState;
  reg [7:0] rShiftReg;
  reg [2:0] rBitCnt;
  reg [3:0] rTickCnt;
  reg       rTx;

  always @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      rCurState <= IDLE;
    end
    else begin
      rCurState <= rNxtState;
    end
  end

  always @(*) begin
    rNxtState = rCurState;
    case (rCurState)
      IDLE: begin
        if (iValid) begin
          rNxtState = START;
        end
      end

      START: begin
        if (iTick16x && (rTickCnt == 4'd15)) begin
          rNxtState = DATA;
        end
      end

      DATA: begin
        if (iTick16x && (rTickCnt == 4'd15) && (rBitCnt == 3'd7)) begin
          rNxtState = STOP;
        end
      end

      STOP: begin
        if (iTick16x && (rTickCnt == 4'd15)) begin
          rNxtState = IDLE;
        end
      end

      default: rNxtState = IDLE;
    endcase
  end

  always @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      rShiftReg <= 8'h00;
      rBitCnt   <= 3'd0;
      rTickCnt  <= 4'd0;
      rTx       <= 1'b1;
    end
    else begin
      case (rCurState)
        IDLE: begin
          rTx      <= 1'b1;
          rBitCnt  <= 3'd0;
          rTickCnt <= 4'd0;
          if (iValid) begin
            rShiftReg <= iData;
          end
        end

        START: begin
          rTx <= 1'b0;
          if (iTick16x) begin
            if (rTickCnt == 4'd15) begin
              rTickCnt <= 4'd0;
            end
            else begin
              rTickCnt <= rTickCnt + 1'b1;
            end
          end
        end

        DATA: begin
          rTx <= rShiftReg[0];
          if (iTick16x) begin
            if (rTickCnt == 4'd15) begin
              rTickCnt  <= 4'd0;
              rShiftReg <= {1'b0, rShiftReg[7:1]};
              if (rBitCnt != 3'd7) begin
                rBitCnt <= rBitCnt + 1'b1;
              end
            end
            else begin
              rTickCnt <= rTickCnt + 1'b1;
            end
          end
        end

        STOP: begin
          rTx <= 1'b1;
          if (iTick16x) begin
            if (rTickCnt == 4'd15) begin
              rTickCnt <= 4'd0;
            end
            else begin
              rTickCnt <= rTickCnt + 1'b1;
            end
          end
        end

        default: begin
          rTx <= 1'b1;
        end
      endcase
    end
  end

  assign oTx   = rTx;
  assign oBusy = (rCurState != IDLE);
endmodule
