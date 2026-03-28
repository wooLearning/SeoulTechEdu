`ifndef TOP_COVERAGE_SVH
`define TOP_COVERAGE_SVH

class TopCoverage;
    mailbox #(TopTx) mbx_mon2cov;
    trace_opcode_kind_e m_opcode_kind;
    bit m_reg_write;
    bit m_mem_write;
    bit m_illegal;
    bit m_redirect;
    bit m_stall;
    bit [1:0] m_forward_a;
    bit [1:0] m_forward_b;

    covergroup cg_Top_tx;
        option.per_instance = 1;

        cp_opcode: coverpoint m_opcode_kind {
            bins b_alur   = {TRACE_OP_ALUR};
            bins b_alui   = {TRACE_OP_ALUI};
            bins b_load   = {TRACE_OP_LOAD};
            bins b_store  = {TRACE_OP_STORE};
            bins b_branch = {TRACE_OP_BRANCH};
            bins b_jal    = {TRACE_OP_JAL};
            bins b_jalr   = {TRACE_OP_JALR};
            bins b_lui    = {TRACE_OP_LUI};
            bins b_auipc  = {TRACE_OP_AUIPC};
            bins b_other  = {TRACE_OP_OTHER};
        }

        cp_reg_write: coverpoint m_reg_write {
            bins b_no  = {0};
            bins b_yes = {1};
        }

        cp_mem_write: coverpoint m_mem_write {
            bins b_no  = {0};
            bins b_yes = {1};
        }

        cp_illegal: coverpoint m_illegal {
            bins b_no  = {0};
            bins b_yes = {1};
        }

        cp_redirect: coverpoint m_redirect {
            bins b_no  = {0};
            bins b_yes = {1};
        }

        cp_stall: coverpoint m_stall {
            bins b_no  = {0};
            bins b_yes = {1};
        }

        cp_forward_a: coverpoint m_forward_a {
            bins b_none = {2'b00};
            bins b_wb   = {2'b01};
            bins b_mem  = {2'b10};
        }

        cp_forward_b: coverpoint m_forward_b {
            bins b_none = {2'b00};
            bins b_wb   = {2'b01};
            bins b_mem  = {2'b10};
        }

        cx_opcode_regwrite: cross cp_opcode, cp_reg_write;
        cx_opcode_memwrite: cross cp_opcode, cp_mem_write;
        cx_opcode_redirect: cross cp_opcode, cp_redirect;
    endgroup

    function new(mailbox #(TopTx) mbx_mon2cov);
        this.mbx_mon2cov = mbx_mon2cov;
        this.m_opcode_kind = TRACE_OP_OTHER;
        this.m_reg_write = 1'b0;
        this.m_mem_write = 1'b0;
        this.m_illegal = 1'b0;
        this.m_redirect = 1'b0;
        this.m_stall = 1'b0;
        this.m_forward_a = '0;
        this.m_forward_b = '0;
        this.cg_Top_tx = new();
    endfunction

    virtual task run();
        TopTx m_tx_item;
        forever begin
            mbx_mon2cov.get(m_tx_item);
            m_opcode_kind = trace_opcode_kind(m_tx_item.m_inst);
            m_reg_write = m_tx_item.m_reg_write;
            m_mem_write = m_tx_item.m_mem_write;
            m_illegal = m_tx_item.m_illegal;
            m_redirect = m_tx_item.m_redirect;
            m_stall = m_tx_item.m_stall;
            m_forward_a = m_tx_item.m_forward_a;
            m_forward_b = m_tx_item.m_forward_b;
            cg_Top_tx.sample();
        end
    endtask

    virtual function real get_coverage();
        return cg_Top_tx.get_inst_coverage();
    endfunction

    virtual task report();
        `TB_INFO($sformatf("Coverage summary: %0.2f%%", get_coverage()));
    endtask
endclass

`endif
