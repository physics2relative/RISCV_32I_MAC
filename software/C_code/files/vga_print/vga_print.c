#include <stdint.h>

#define VGA_VRAM ((volatile char *)0x40000000)

void vga_print_safe(int row, int col) {
    volatile char *vram = VGA_VRAM;
    int offset = row * 80 + col;
    
    // Immediate-based assignment (avoiding strings in .rodata)
    vram[offset+0] = 'H';
    vram[offset+1] = 'I';
    vram[offset+2] = '!';
    vram[offset+3] = ' ';
    vram[offset+4] = 'V';
    vram[offset+5] = 'G';
    vram[offset+6] = 'A';
}

int main() {
    vga_print_safe(2, 5);
    while (1);
    return 0;
}
