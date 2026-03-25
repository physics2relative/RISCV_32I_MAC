.section    .start
.global     _start

_start:
    li      sp, 0x000000F0
    jal     main
