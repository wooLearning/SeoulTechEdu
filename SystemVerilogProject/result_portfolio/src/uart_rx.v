/*
[MODULE_INFO_START]
Name: uart_rx
Role: UART Receiver (serial to parallel)
Summary:
  - Receives asynchronous serial data on `iRx`
  - Uses a 16x oversampling tick `iTick16x`
  - Verifies start/stop framing and shifts in 8 data bits LSB first
  - Raises `oValid` for one cycle when a valid byte is received
StateDescription:
  - IDLE: Wait for start bit
  - START: Confirm start bit near the bit center
  - DATA: Shift 8 data bits
  - STOP: Check stop bit and pulse valid
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module uart_rx (
  input  wire       iClk,
  input  wire       iRst,
  input  wire       iTick16x,
  input  wire       iRx,
  output wire [7:0] oData,
  output wire       oValid
);
  localparam [1:0] IDLE  = 2'b00;
  localparam [1:0] START = 2'b01;
  localparam [1:0] DATA  = 2'b10;
  localparam [1:0] STOP  = 2'b11;

  reg [1:0] rCurState;
  reg [1:0] rNxtState;
  reg [7:0] rData;
  reg [2:0] rBitCnt;
  reg [3:0] rTickCnt;
  reg       rValid;
  reg       rRxSync1;
  reg       rRxSync2;
  wire      wRxSynced;

  always @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      rRxSync1 <= 1'b1;
      rRxSync2 <= 1'b1;
    end
    else begin
      rRxSync1 <= iRx;
      rRxSync2 <= rRxSync1;
    end
  end

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
        if (wRxSynced == 1'b0) begin
          rNxtState = START;
        end
      end

      START: begin
        if (iTick16x && (rTickCnt == 4'd7)) begin
          if (wRxSynced == 1'b0) begin
            rNxtState = DATA;
          end
          else begin
            rNxtState = IDLE;
          end
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
      rData    <= 8'h00;
      rBitCnt  <= 3'd0;
      rTickCnt <= 4'd0;
      rValid   <= 1'b0;
    end
    else begin
      rValid <= 1'b0;
      case (rCurState)
        IDLE: begin
          rBitCnt  <= 3'd0;
          rTickCnt <= 4'd0;
        end

        START: begin
          if (iTick16x) begin
            if (rTickCnt == 4'd7) begin
              rTickCnt <= 4'd0;
            end
            else begin
              rTickCnt <= rTickCnt + 1'b1;
            end
          end
        end

        DATA: begin
          if (iTick16x) begin
            if (rTickCnt == 4'd15) begin
              rTickCnt <= 4'd0;
              rData    <= {wRxSynced, rData[7:1]};
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
          if (iTick16x) begin
            if (rTickCnt == 4'd15) begin
              rTickCnt <= 4'd0;
              if (wRxSynced == 1'b1) begin
                rValid <= 1'b1;
              end
            end
            else begin
              rTickCnt <= rTickCnt + 1'b1;
            end
          end
        end

        default: begin
          rBitCnt  <= 3'd0;
          rTickCnt <= 4'd0;
        end
      endcase
    end
  end

  assign wRxSynced = rRxSync2;
  assign oData     = rData;
  assign oValid    = rValid;
endmodule
