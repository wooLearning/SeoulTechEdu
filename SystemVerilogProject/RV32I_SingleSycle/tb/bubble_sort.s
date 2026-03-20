# bubble_sort.s
# Supported instruction subset only:
#   addi, lw, sw, blt, bne, beq
#
# Data memory layout:
#   base address = 64
#   word[16]..word[20] = 5 unsorted integers
#
# Register usage:
#   x1  = base address
#   x2  = outer loop remaining count
#   x3  = current element pointer
#   x4  = inner loop remaining count
#   x5  = current value
#   x6  = next value
#   x31 = completion flag

    addi x1,  x0, 64        # base = 64
    addi x2,  x0, 4         # outer_count = n - 1
    beq  x2,  x0, done

outer_loop:
    addi x3,  x1, 0         # ptr = base
    addi x4,  x2, 0         # inner_count = outer_count

inner_loop:
    lw   x5,  0(x3)         # a = mem[ptr]
    lw   x6,  4(x3)         # b = mem[ptr + 4]
    blt  x6,  x5, do_swap   # if (b < a) swap

after_swap:
    addi x3,  x3, 4         # ptr += 4
    addi x4,  x4, -1        # inner_count--
    bne  x4,  x0, inner_loop

    addi x2,  x2, -1        # outer_count--
    bne  x2,  x0, outer_loop

done:
    addi x31, x0, 1         # done flag
    beq  x0,  x0, done      # hold state

do_swap:
    sw   x6,  0(x3)
    sw   x5,  4(x3)
    beq  x0,  x0, after_swap
