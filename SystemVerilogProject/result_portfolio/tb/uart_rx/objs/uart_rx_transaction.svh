typedef enum int {
  UART_RX_SC_VALID = 1,
  UART_RX_SC_INVALID_STOP = 2
} uart_rx_scn_e;

class uart_rx_transaction;
  rand bit [7:0] data;
  uart_rx_scn_e  scenario_id;
  bit            expect_valid;
  int unsigned   low_hold_ticks16x;
  int unsigned   observe_ticks16x;

  static function string scenario_name_by_id(int unsigned id);
    case (id)
      UART_RX_SC_VALID:        return "valid_frame";
      UART_RX_SC_INVALID_STOP: return "invalid_stop";
      default:                 return "unknown";
    endcase
  endfunction

  function string get_scenario_name();
    return scenario_name_by_id(scenario_id);
  endfunction
endclass
