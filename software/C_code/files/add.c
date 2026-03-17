#include <stdint.h>

void write_to_x31(int32_t value) { asm volatile("mv x31, %0" : : "r"(value)); }

int main(void) {
  int a = 0;
  int b = 10;
  int c = 5;

  a = b + c;

  // write to x31 register
  write_to_x31(a);

  // simulation end
  asm volatile(".word 0xDEADDEAD");

  while (1) {
  }
}
