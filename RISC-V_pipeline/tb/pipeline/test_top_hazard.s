# Active mixed hazard program for `tb_top_hazard` / `src/InstrRom.sv`
# Initial data memory is all zero.
# This file is intentionally comment-heavy so the forwarding/stall/flush points are obvious.

# 1. Boot / Forwarding Chain
addi x20, x0, 64                # PC=0:  x20 = base address 64
addi x21, x0, 68                # PC=4:  x21 = secondary base 68
addi x18, x0, 55                # PC=8:  x18 = preserved value for illegal no-side-effect check
addi x1,  x0, 5                 # PC=12: x1 = 5
addi x2,  x0, 7                 # PC=16: x2 = 7
add  x3,  x1, x2                # PC=20: x3 = 12
add  x4,  x3, x1                # PC=24: x4 = 17, EX/MEM forward from x3 required
addi x30, x0, 1                 # PC=28: x30 = 1, inserts one-cycle gap before MEM/WB case
sub  x5,  x4, x2                # PC=32: x5 = 10, MEM/WB forward from x4 required
add  x6,  x5, x3                # PC=36: x6 = 22, EX/MEM forward from x5 required

# 2. Store / Load / Load-Use Mixed Path
sw   x6,  0(x20)                # PC=40: Mem[64] = 22, store data uses forwarded x6
lw   x7,  0(x20)                # PC=44: x7 = 22, store->load roundtrip
addi x8,  x7, 1                 # PC=48: x8 = 23, classic load-use stall required
add  x9,  x8, x6                # PC=52: x9 = 45
addi x22, x20, 8                # PC=56: x22 = 72
sw   x9,  0(x22)                # PC=60: Mem[72] = 45, store address/data path exercised

# 3. Not-Taken Branch With Branch Operand Forwarding
addi x10, x0, 1                 # PC=64: x10 = 1
beq  x10, x0, +8                # PC=68: not taken, branch compare needs forwarded x10
addi x11, x0, 11                # PC=72: x11 = 11, must execute because branch was not taken

# 4. Load -> Branch Mixed Hazard
lw   x12, 0(x20)                # PC=76: x12 = 22
beq  x12, x6, +8                # PC=80: taken, but only after a load-to-branch stall
addi x13, x0, 99                # PC=84: must be flushed by taken branch
addi x13, x0, 13                # PC=88: x13 = 13, taken target

# 5. Back-to-Back Branch / Jump (Not-Taken Branch Followed By JAL)
addi x14, x0, 1                 # PC=92: x14 = 1
beq  x14, x0, +8                # PC=96: not taken
jal  x15, +8                    # PC=100: x15 = 104, redirect to PC=108
addi x16, x0, 99                # PC=104: must be flushed by jal
addi x16, x0, 16                # PC=108: x16 = 16, jal target

# 6. JALR Flush Path
addi x17, x0, 124               # PC=112: x17 = 124, jalr base
jalr x19, x17, 0                # PC=116: x19 = 120, redirect target = 124
addi x23, x0, 111               # PC=120: must be flushed by jalr
addi x23, x0, 23                # PC=124: x23 = 23, jalr target

# 7. Taken Branch Flushing An Immediately Following JAL
addi x24, x0, 1                 # PC=128: x24 = 1
bne  x24, x0, +8                # PC=132: taken, branch compare uses forwarded x24
jal  x25, +8                    # PC=136: must be flushed by taken branch
addi x25, x0, 25                # PC=140: x25 = 25, taken branch target

# 8. Illegal / Finish
.word 0xFFFFFFFF                # PC=144: illegal opcode, must not update architectural state
addi x31, x0, 1                 # PC=148: completion flag = 1

# Golden Summary
# Registers:
#   x3  = 12
#   x4  = 17
#   x5  = 10
#   x6  = 22
#   x7  = 22
#   x8  = 23
#   x9  = 45
#   x10 = 1
#   x11 = 11
#   x12 = 22
#   x13 = 13
#   x14 = 1
#   x15 = 104
#   x16 = 16
#   x17 = 124
#   x18 = 55
#   x19 = 120
#   x20 = 64
#   x21 = 68
#   x22 = 72
#   x23 = 23
#   x24 = 1
#   x25 = 25
#   x30 = 1
#   x31 = 1
# Memory:
#   word[16] = 22
#   word[18] = 45
