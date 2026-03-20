# 1. Boot / Init
addi x1, x0, 15                 # PC=0: x1 = 15
addi x2, x0, 3                  # PC=4: x2 = 3
addi x3, x0, -16                # PC=8: x3 = -16 (0xFFFFFFF0)

# 2. R-type ALU Test
add x4, x1, x2                  # PC=12: 15 + 3 = 18
sub x5, x1, x2                  # PC=16: 15 - 3 = 12
sll x6, x1, x2                  # PC=20: 15 << 3 = 120
slt x7, x3, x1                  # PC=24: signed -16 < 15 -> 1
sltu x8, x3, x1                 # PC=28: unsigned 0xFFFFFFF0 < 15 -> 0
xor x9, x1, x2                  # PC=32: 15 ^ 3 = 12
srl x10, x1, x2                 # PC=36: 15 >> 3 = 1
sra x11, x3, x2                 # PC=40: -16 >>> 3 = -2
or x12, x1, x2                  # PC=44: 15 | 3 = 15
and x13, x1, x2                 # PC=48: 15 & 3 = 3

# 3. I-type ALU Test
addi x14, x1, 5                 # PC=52: 15 + 5 = 20
slti x15, x3, 0                 # PC=56: signed -16 < 0 -> 1
sltiu x16, x3, 1                # PC=60: unsigned 0xFFFFFFF0 < 1 -> 0
xori x17, x1, 3                 # PC=64: 15 ^ 3 = 12
ori x18, x1, 2                  # PC=68: 15 | 2 = 15
andi x19, x1, 7                 # PC=72: 15 & 7 = 7
slli x20, x2, 4                 # PC=76: 3 << 4 = 48
srli x21, x1, 1                 # PC=80: 15 >> 1 = 7
srai x22, x3, 2                 # PC=84: -16 >>> 2 = -4

# 4. Word Memory Access Test
addi x23, x0, 64                # PC=88: x23 = data base address 64
sw x14, 0(x23)                  # PC=92: Mem[64] = 20 (word index 16)
lw x24, 0(x23)                  # PC=96: x24 = Mem[64] = 20

# 5. Branch Taken / Not-Taken Test
addi x25, x0, 0     # PC=100: x25 = branch not-taken counter
addi x26, x0, 0     # PC=104: x26 = branch taken counter
beq x1, x2, +8      # PC=108: 15 == 3 -> not taken
addi x25, x25, 1    # PC=112: x25 = 1
beq x1, x1, +8      # PC=116: 15 == 15 -> taken, skip PC=120
addi x26, x26, 99   # PC=120: skipped
addi x26, x26, 1    # PC=124: x26 = 1
bne x1, x1, +8      # PC=128: 15 != 15 -> not taken
addi x25, x25, 1    # PC=132: x25 = 2
bne x1, x2, +8      # PC=136: 15 != 3 -> taken, skip PC=140
addi x26, x26, 99   # PC=140: skipped
addi x26, x26, 1    # PC=144: x26 = 2
blt x1, x2, +8      # PC=148: signed 15 < 3 -> not taken
addi x25, x25, 1    # PC=152: x25 = 3
blt x3, x1, +8      # PC=156: signed -16 < 15 -> taken, skip PC=160
addi x26, x26, 99   # PC=160: skipped
addi x26, x26, 1    # PC=164: x26 = 3
bge x2, x1, +8      # PC=168: signed 3 >= 15 -> not taken
addi x25, x25, 1    # PC=172: x25 = 4
bge x1, x2, +8      # PC=176: signed 15 >= 3 -> taken, skip PC=180
addi x26, x26, 99   # PC=180: skipped
addi x26, x26, 1    # PC=184: x26 = 4
bltu x1, x2, +8     # PC=188: unsigned 15 < 3 -> not taken
addi x25, x25, 1    # PC=192: x25 = 5
bltu x2, x1, +8     # PC=196: unsigned 3 < 15 -> taken, skip PC=200
addi x26, x26, 99   # PC=200: skipped
addi x26, x26, 1    # PC=204: x26 = 5
bgeu x2, x1, +8     # PC=208: unsigned 3 >= 15 -> not taken
addi x25, x25, 1    # PC=212: x25 = 6
bgeu x1, x2, +8     # PC=216: unsigned 15 >= 3 -> taken, skip PC=220
addi x26, x26, 99   # PC=220: skipped
addi x26, x26, 1    # PC=224: x26 = 6

# 6. Backward Branch / Loop Test
addi x27, x0, 2   # PC=228: x27 = loop counter = 2
addi x28, x0, 0   # PC=232: x28 = loop exit flag = 0
addi x27, x27, -1 # PC=236: 1st pass x27 = 1, 2nd pass x27 = 0
bne x27, x0, -4   # PC=240: 1st pass taken to PC=236, 2nd pass not taken
addi x28, x28, 1  # PC=244: x28 = 1 after loop exits

# 7. Byte / Halfword Memory Access Test
addi x23, x0, 68  # PC=248: x23 = byte/halfword test base
addi x1, x0, 128  # PC=252: x1 = 0x80
sb x1, 0(x23)     # PC=256: Mem[68] byte0 = 0x80
addi x2, x0, 127  # PC=260: x2 = 0x7F
sb x2, 1(x23)     # PC=264: Mem[69] byte1 = 0x7F
addi x2, x0, -14  # PC=268: x2 = 0xFFFFFFF2
slli x2, x2, 8    # PC=272: x2 = 0xFFFFF200
addi x2, x2, 52   # PC=276: x2 = 0xFFFFF234 (-3532)
sh x2, 2(x23)     # PC=280: Mem[70:71] = 0xF234, word = 0xF2347F80
lb x30, 0(x23)    # PC=284: x30 = sign-extend(0x80) = -128
lbu x31, 0(x23)   # PC=288: x31 = zero-extend(0x80) = 128
lh x1, 2(x23)     # PC=292: x1 = sign-extend(0xF234) = -3532
lhu x2, 2(x23)    # PC=296: x2 = zero-extend(0xF234) = 62004

# 8. Illegal Instruction Safety Test
illegal opcode                   # PC=300: unsupported instruction, should not update reg/mem state

# 9. Jump Test
jal  x3, +8                      # PC=304: x3 = 308, jump target = PC=312
addi x29, x0, 111                # PC=308: skipped by jal
addi x23, x0, 321                # PC=312: x23 = 321
jalr x23, x23, 0                 # PC=316: x23 = 320, target = (321 + 0) & ~1 = 320

# 10. U-type Test
lui x3, 0x12345                  # PC=320: x3 = 0x12345000
auipc x23, 0x1                   # PC=324: x23 = 324 + 0x1000 = 4420 (0x1144)

# 11. Finish
addi x29, x0, 77                 # PC=328: completion flag = 77
