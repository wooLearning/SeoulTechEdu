#!/usr/bin/env python3
"""
Build the active RV32I verification artifacts from a Spike CSV trace.

Outputs:
  - tb/spike_trace_pkg.sv
  - src/mem/InstructionSpikeTop.mem

The generated files keep the current testbenches unchanged.
"""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
from pathlib import Path


NOP_INST = 0x00000013


@dataclass
class TraceRow:
    step: int
    pc: int
    inst: int
    gpr: list[int]


def sign_extend(value: int, bits: int) -> int:
    sign_bit = 1 << (bits - 1)
    return (value & (sign_bit - 1)) - (value & sign_bit)


def decode_i_imm(inst: int) -> int:
    return sign_extend((inst >> 20) & 0xFFF, 12)


def decode_s_imm(inst: int) -> int:
    imm = ((inst >> 7) & 0x1F) | (((inst >> 25) & 0x7F) << 5)
    return sign_extend(imm, 12)


def get_rs1(inst: int) -> int:
    return (inst >> 15) & 0x1F


def get_rs2(inst: int) -> int:
    return (inst >> 20) & 0x1F


def get_rd(inst: int) -> int:
    return (inst >> 7) & 0x1F


def get_funct3(inst: int) -> int:
    return (inst >> 12) & 0x7


def parse_hex(value: str) -> int:
    return int(value, 16)


def parse_word_check(text: str) -> tuple[int, int]:
    if "=" not in text:
        raise argparse.ArgumentTypeError("word check must be ADDR=VALUE")
    addr_s, value_s = text.split("=", 1)
    return parse_hex(addr_s), parse_hex(value_s)


def load_trace(csv_path: Path) -> list[TraceRow]:
    rows: list[TraceRow] = []
    with csv_path.open("r", encoding="utf-8", newline="") as fp:
        reader = csv.DictReader(fp)
        for row in reader:
            gpr = [parse_hex(row[f"x{i}"]) for i in range(32)]
            rows.append(
                TraceRow(
                    step=int(row["step"]),
                    pc=parse_hex(row["pc"]),
                    inst=parse_hex(row["inst"]),
                    gpr=gpr,
                )
            )
    if not rows:
        raise SystemExit(f"No trace rows found in {csv_path}")
    return rows


def split_boot_main(rows: list[TraceRow]) -> tuple[list[TraceRow], list[TraceRow]]:
    first_main_idx = None
    for idx, row in enumerate(rows):
        if row.pc >= 0x80000000:
            first_main_idx = idx
            break
    if first_main_idx is None:
        return [], rows
    return rows[:first_main_idx], rows[first_main_idx:]


def build_mem_image(main_rows: list[TraceRow]) -> tuple[list[int], int, int]:
    pc_to_inst: dict[int, int] = {}
    for row in main_rows:
        prev = pc_to_inst.get(row.pc)
        if prev is not None and prev != row.inst:
            raise SystemExit(
                f"Conflicting instructions for PC 0x{row.pc:08X}: "
                f"0x{prev:08X} vs 0x{row.inst:08X}"
            )
        pc_to_inst[row.pc] = row.inst

    unique_pcs = sorted(pc_to_inst)
    if not unique_pcs:
        raise SystemExit("No main-program PCs found in trace")

    min_pc = unique_pcs[0]
    max_pc = unique_pcs[-1]
    image: list[int] = []
    fill_count = 0
    for pc in range(min_pc, max_pc + 4, 4):
        inst = pc_to_inst.get(pc, NOP_INST)
        if pc not in pc_to_inst:
            fill_count += 1
        image.append(inst)
    return image, min_pc, fill_count


def word_from_bytes(byte_map: dict[int, int], word_addr: int) -> int:
    value = 0
    for ofs in range(4):
        value |= (byte_map.get(word_addr + ofs, 0) & 0xFF) << (8 * ofs)
    return value


def reconstruct_initial_memory(
    boot_rows: list[TraceRow],
    main_rows: list[TraceRow],
) -> tuple[list[tuple[int, int]], list[tuple[int, int]]]:
    initial_bytes: dict[int, int] = {}
    current_bytes: dict[int, int] = {}

    prev_gpr = boot_rows[-1].gpr[:] if boot_rows else [0] * 32

    for row in main_rows:
        inst = row.inst
        opcode = inst & 0x7F
        funct3 = get_funct3(inst)

        if opcode == 0x03:
            rs1 = get_rs1(inst)
            rd = get_rd(inst)
            addr = (prev_gpr[rs1] + decode_i_imm(inst)) & 0xFFFFFFFF
            load_val = row.gpr[rd] if rd != 0 else 0

            if funct3 in (0x0, 0x4):
                byte_val = load_val & 0xFF
                if addr in current_bytes and current_bytes[addr] != byte_val:
                    raise SystemExit(
                        f"Load byte conflict at 0x{addr:08X}: "
                        f"{current_bytes[addr]:02X} vs {byte_val:02X}"
                    )
                current_bytes[addr] = byte_val
                initial_bytes.setdefault(addr, byte_val)
            elif funct3 in (0x1, 0x5):
                for ofs in range(2):
                    byte_val = (load_val >> (8 * ofs)) & 0xFF
                    byte_addr = addr + ofs
                    if byte_addr in current_bytes and current_bytes[byte_addr] != byte_val:
                        raise SystemExit(
                            f"Load half conflict at 0x{byte_addr:08X}: "
                            f"{current_bytes[byte_addr]:02X} vs {byte_val:02X}"
                        )
                    current_bytes[byte_addr] = byte_val
                    initial_bytes.setdefault(byte_addr, byte_val)
            elif funct3 == 0x2:
                for ofs in range(4):
                    byte_val = (load_val >> (8 * ofs)) & 0xFF
                    byte_addr = addr + ofs
                    if byte_addr in current_bytes and current_bytes[byte_addr] != byte_val:
                        raise SystemExit(
                            f"Load word conflict at 0x{byte_addr:08X}: "
                            f"{current_bytes[byte_addr]:02X} vs {byte_val:02X}"
                        )
                    current_bytes[byte_addr] = byte_val
                    initial_bytes.setdefault(byte_addr, byte_val)
        elif opcode == 0x23:
            rs1 = get_rs1(inst)
            rs2 = get_rs2(inst)
            addr = (prev_gpr[rs1] + decode_s_imm(inst)) & 0xFFFFFFFF
            store_val = prev_gpr[rs2]
            width = {0x0: 1, 0x1: 2, 0x2: 4}.get(funct3)
            if width is not None:
                for ofs in range(width):
                    current_bytes[addr + ofs] = (store_val >> (8 * ofs)) & 0xFF

        prev_gpr = row.gpr[:]

    init_words = sorted({addr & ~0x3 for addr in initial_bytes})
    final_words = sorted({addr & ~0x3 for addr in current_bytes})
    initial_word_data = [(addr, word_from_bytes(initial_bytes, addr)) for addr in init_words]
    final_word_data = [(addr, word_from_bytes(current_bytes, addr)) for addr in final_words]
    return initial_word_data, final_word_data


def sv_hex(value: int, width: int = 32) -> str:
    digits = max(1, width // 4)
    return f"{width}'h{value:0{digits}X}"


def format_int_array(values: list[int], width: int, indent: str = "    ") -> str:
    lines: list[str] = []
    row_size = 8
    for idx in range(0, len(values), row_size):
        chunk = values[idx:idx + row_size]
        lines.append(indent + ", ".join(sv_hex(value, width) for value in chunk))
    return ",\n".join(lines)


def format_gpr_array(rows: list[TraceRow], indent: str = "    ") -> str:
    lines: list[str] = []
    for row in rows:
        values = ", ".join(sv_hex(value, 32) for value in row.gpr)
        lines.append(f"{indent}'{{{values}}}")
    return ",\n".join(lines)


def write_mem(mem_path: Path, image: list[int]) -> None:
    mem_path.parent.mkdir(parents=True, exist_ok=True)
    mem_path.write_text("\n".join(f"{inst:08X}" for inst in image) + "\n", encoding="utf-8")


def write_pkg(
    pkg_path: Path,
    boot_rows: list[TraceRow],
    main_rows: list[TraceRow],
    base_pc: int,
    word_checks: list[tuple[int, int]],
    preload_words: list[tuple[int, int]],
) -> None:
    preload_gpr = boot_rows[-1].gpr if boot_rows else [0] * 32
    check_final_mem = 1 if word_checks else 0
    word0_addr, word0_exp = word_checks[0] if len(word_checks) >= 1 else (0, 0)
    word1_addr, word1_exp = word_checks[1] if len(word_checks) >= 2 else (0, 0)
    steps = [row.step for row in main_rows]
    pcs = [row.pc for row in main_rows]
    insts = [row.inst for row in main_rows]
    preload_addrs = [addr for addr, _ in preload_words]
    preload_data = [value for _, value in preload_words]

    pkg_text = f"""`timescale 1ns / 1ps

package spike_trace_pkg;

  typedef enum logic [3:0] {{
    TRACE_OP_ALUR   = 4'd0,
    TRACE_OP_ALUI   = 4'd1,
    TRACE_OP_LOAD   = 4'd2,
    TRACE_OP_STORE  = 4'd3,
    TRACE_OP_BRANCH = 4'd4,
    TRACE_OP_JAL    = 4'd5,
    TRACE_OP_JALR   = 4'd6,
    TRACE_OP_LUI    = 4'd7,
    TRACE_OP_AUIPC  = 4'd8,
    TRACE_OP_SYSTEM = 4'd9,
    TRACE_OP_OTHER  = 4'd15
  }} trace_opcode_kind_e;

  localparam int unsigned LP_SPIKE_TRACE_DEPTH = {len(main_rows)};
  localparam logic [31:0] LP_SPIKE_RESET_PC = {sv_hex(base_pc)};
  localparam logic [31:0] LP_SPIKE_INSTR_BASE_ADDR = {sv_hex(base_pc)};
  localparam bit LP_SPIKE_CHECK_FINAL_MEM = 1'b{check_final_mem};
  localparam logic [31:0] LP_SPIKE_DATA_WORD0_ADDR = {sv_hex(word0_addr)};
  localparam logic [31:0] LP_SPIKE_DATA_WORD1_ADDR = {sv_hex(word1_addr)};
  localparam logic [31:0] LP_SPIKE_DATA_WORD0_EXP  = {sv_hex(word0_exp)};
  localparam logic [31:0] LP_SPIKE_DATA_WORD1_EXP  = {sv_hex(word1_exp)};

  localparam logic [31:0] LP_SPIKE_PRELOAD_GPR [0:31] = '{{
{format_int_array(preload_gpr, 32, indent="    ")}
  }};

  localparam int unsigned LP_SPIKE_PRELOAD_MEM_COUNT = {len(preload_words)};
  localparam logic [31:0] LP_SPIKE_PRELOAD_MEM_ADDR [0:LP_SPIKE_PRELOAD_MEM_COUNT-1] = '{{
{format_int_array(preload_addrs, 32, indent="    ")}
  }};
  localparam logic [31:0] LP_SPIKE_PRELOAD_MEM_DATA [0:LP_SPIKE_PRELOAD_MEM_COUNT-1] = '{{
{format_int_array(preload_data, 32, indent="    ")}
  }};

  localparam int unsigned LP_SPIKE_TRACE_STEP [0:LP_SPIKE_TRACE_DEPTH-1] = '{{
{format_int_array(steps, 32, indent="    ")}
  }};

  localparam logic [31:0] LP_SPIKE_TRACE_PC [0:LP_SPIKE_TRACE_DEPTH-1] = '{{
{format_int_array(pcs, 32, indent="    ")}
  }};

  localparam logic [31:0] LP_SPIKE_TRACE_INST [0:LP_SPIKE_TRACE_DEPTH-1] = '{{
{format_int_array(insts, 32, indent="    ")}
  }};

  localparam logic [31:0] LP_SPIKE_TRACE_GPR [0:LP_SPIKE_TRACE_DEPTH-1][0:31] = '{{
{format_gpr_array(main_rows, indent="    ")}
  }};

  function automatic trace_opcode_kind_e trace_opcode_kind(input logic [31:0] iInst);
    unique case (iInst[6:0])
      7'b0110011: trace_opcode_kind = TRACE_OP_ALUR;
      7'b0010011: trace_opcode_kind = TRACE_OP_ALUI;
      7'b0000011: trace_opcode_kind = TRACE_OP_LOAD;
      7'b0100011: trace_opcode_kind = TRACE_OP_STORE;
      7'b1100011: trace_opcode_kind = TRACE_OP_BRANCH;
      7'b1101111: trace_opcode_kind = TRACE_OP_JAL;
      7'b1100111: trace_opcode_kind = TRACE_OP_JALR;
      7'b0110111: trace_opcode_kind = TRACE_OP_LUI;
      7'b0010111: trace_opcode_kind = TRACE_OP_AUIPC;
      7'b1110011: trace_opcode_kind = TRACE_OP_SYSTEM;
      default:    trace_opcode_kind = TRACE_OP_OTHER;
    endcase
  endfunction

  function automatic string trace_opcode_name(input logic [31:0] iInst);
    unique case (trace_opcode_kind(iInst))
      TRACE_OP_ALUR:   trace_opcode_name = "ALUR";
      TRACE_OP_ALUI:   trace_opcode_name = "ALUI";
      TRACE_OP_LOAD:   trace_opcode_name = "LOAD";
      TRACE_OP_STORE:  trace_opcode_name = "STORE";
      TRACE_OP_BRANCH: trace_opcode_name = "BRANCH";
      TRACE_OP_JAL:    trace_opcode_name = "JAL";
      TRACE_OP_JALR:   trace_opcode_name = "JALR";
      TRACE_OP_LUI:    trace_opcode_name = "LUI";
      TRACE_OP_AUIPC:  trace_opcode_name = "AUIPC";
      TRACE_OP_SYSTEM: trace_opcode_name = "SYSTEM";
      default:         trace_opcode_name = "OTHER";
    endcase
  endfunction
endpackage
"""
    pkg_path.parent.mkdir(parents=True, exist_ok=True)
    pkg_path.write_text(pkg_text, encoding="utf-8")


def main() -> None:
    project_root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description="Build active Spike artifacts from CSV")
    parser.add_argument(
        "--csv",
        default=str(project_root / "tb" / "spike_test_top.csv"),
        help="Input Spike CSV trace",
    )
    parser.add_argument(
        "--out-mem",
        default=str(project_root / "src" / "mem" / "InstructionSpikeTop.mem"),
        help="Output instruction mem path",
    )
    parser.add_argument(
        "--out-pkg",
        default=str(project_root / "tb" / "spike_trace_pkg.sv"),
        help="Output trace package path",
    )
    parser.add_argument(
        "--word-check",
        action="append",
        default=[],
        type=parse_word_check,
        help="Optional final memory expectation as ADDR=VALUE. May be given twice.",
    )
    args = parser.parse_args()

    csv_path = Path(args.csv)
    out_mem = Path(args.out_mem)
    out_pkg = Path(args.out_pkg)
    rows = load_trace(csv_path)
    boot_rows, main_rows = split_boot_main(rows)
    mem_image, base_pc, fill_count = build_mem_image(main_rows)
    preload_words, final_words = reconstruct_initial_memory(boot_rows, main_rows)
    write_mem(out_mem, mem_image)
    write_pkg(out_pkg, boot_rows, main_rows, base_pc, args.word_check[:2], preload_words)

    print(f"[INFO] csv       : {csv_path}")
    print(f"[INFO] out mem   : {out_mem}")
    print(f"[INFO] out pkg   : {out_pkg}")
    print(f"[INFO] boot rows : {len(boot_rows)}")
    print(f"[INFO] main rows : {len(main_rows)}")
    print(f"[INFO] base pc   : 0x{base_pc:08X}")
    print(f"[INFO] mem words : {len(mem_image)}")
    print(f"[INFO] nop fills : {fill_count}")
    print(f"[INFO] preload words : {len(preload_words)}")
    print(f"[INFO] final words   : {len(final_words)}")
    if args.word_check:
        for idx, (addr, value) in enumerate(args.word_check[:2]):
            print(f"[INFO] word{idx}    : 0x{addr:08X}=0x{value:08X}")
    else:
        print("[INFO] final memory check disabled")


if __name__ == "__main__":
    main()
