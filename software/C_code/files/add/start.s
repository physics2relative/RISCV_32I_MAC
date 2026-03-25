.section    .start
.global     _start

_start:
    li      sp, 0x00003FF0
    jal     main
