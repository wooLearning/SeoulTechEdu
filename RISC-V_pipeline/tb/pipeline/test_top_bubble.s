# Active bubble-sort program for `tb_top_bubble` / `src/InstrRom.sv`
# Initial data image comes from the TB, not from the ROM:
#   word[16] = 9, word[17] = 3, word[18] = 7, word[19] = 1, word[20] = 5

addi x1, x0, 64                 # PC=0: x1 = base address 64
addi x2, x0, 4                  # PC=4: x2 = outer loop count = 4

outer_loop:
beq  x2, x0, done               # PC=8: if x2 == 0, sorting is finished
addi x3, x1, 0                  # PC=12: x3 = current element address
addi x4, x2, 0                  # PC=16: x4 = inner loop remaining count

inner_loop:
lw   x5, 0(x3)                  # PC=20: x5 = current value
lw   x6, 4(x3)                  # PC=24: x6 = next value
blt  x6, x5, do_swap            # PC=28: if next < current, branch to swap

after_swap:
addi x3, x3, 4                  # PC=32: advance to next pair
addi x4, x4, -1                 # PC=36: decrement inner loop counter
bne  x4, x0, inner_loop         # PC=40: loop while x4 != 0
addi x2, x2, -1                 # PC=44: decrement outer loop counter
bne  x2, x0, outer_loop         # PC=48: next outer pass if x2 != 0

done:
addi x31, x0, 1                 # PC=52: completion flag = 1
beq  x0, x0, done               # PC=56: stay here forever after completion

do_swap:
sw   x6, 0(x3)                  # PC=60: write smaller value first
sw   x5, 4(x3)                  # PC=64: write larger value second
beq  x0, x0, after_swap         # PC=68: unconditional branch back to common path

# Golden Summary
# Final data memory:
#   word[16] = 1
#   word[17] = 3
#   word[18] = 5
#   word[19] = 7
#   word[20] = 9
# Final registers:
#   x2  = 0
#   x31 = 1
