# start.s
# Minimal bare-metal startup code for the custom RV32IM core.
# Runs before main() - sets up the stack, zeros .bss, then calls main().

.section .text.start
.global _start
.global main

_start:
    la      sp, _stack_top

    la      t0, _bss_start
    la      t1, _bss_end

zero_bss_loop:
    bge     t0, t1, zero_bss_done
    sw      zero, 0(t0)
    addi    t0, t0, 4
    j       zero_bss_loop

zero_bss_done:
    call    main

halt:
    j       halt
