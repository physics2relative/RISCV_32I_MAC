MEMORY
{
    imem (rx) : ORIGIN = 0x10000000, LENGTH = 4K
    dmem (rw) : ORIGIN = 0x00000000, LENGTH = 256
}

SECTIONS
{
    .text : {
        * (.start);
        * (.text);
        * (.rodata*);
    } > imem

    .data : {
        * (.sdata*);
        * (.data*);
    } > dmem

    .bss : {
        * (.sbss*);
        * (.bss*);
        * (COMMON);
    } > dmem
}
