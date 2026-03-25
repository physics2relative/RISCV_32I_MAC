#include <stdint.h>

#define GPIO_KEY     (*(volatile unsigned int *)0x10000000)
#define GPIO_SW      (*(volatile unsigned int *)0x10000004)
#define GPIO_LEDR    (*(volatile unsigned int *)0x10000008)

#define TIMER_COUNT   (*(volatile unsigned int *)0x20000000)
#define TIMER_CONTROL (*(volatile unsigned int *)0x20000004)
#define TIMER_SNAP    (*(volatile unsigned int *)0x20000008)

#define VGA_VRAM ((volatile char *)0x40000000)

// ---- Software math (compiler-rt) ----

int __mulsi3(unsigned int a, unsigned int b) {
  unsigned int res = 0;
  while (a) {
    if (a & 1) res += b;
    a >>= 1;
    b <<= 1;
  }
  return res;
}

// Fused unsigned divmod — one function handles both / and %
// GCC calls __udivsi3 for /, __umodsi3 for %
static unsigned int __udivmod(unsigned int n, unsigned int d, int want_rem) {
  if (d == 0) return 0;
  unsigned int q = 0, r = 0;
  for (int i = 31; i >= 0; i--) {
    r = (r << 1) | ((n >> i) & 1);
    if (r >= d) { r -= d; q |= (1U << i); }
  }
  return want_rem ? r : q;
}

unsigned int __udivsi3(unsigned int n, unsigned int d) { return __udivmod(n, d, 0); }
unsigned int __umodsi3(unsigned int n, unsigned int d) { return __udivmod(n, d, 1); }

// Signed wrappers (needed by vga_print_num for negative numbers)
int __divsi3(int n, int d) {
  int neg = 0;
  if (n < 0) { n = -n; neg = 1; }
  if (d < 0) { d = -d; neg ^= 1; }
  unsigned int q = __udivmod((unsigned)n, (unsigned)d, 0);
  return neg ? -(int)q : (int)q;
}

int __modsi3(int n, int d) {
  int neg = (n < 0);
  if (n < 0) n = -n;
  if (d < 0) d = -d;
  unsigned int r = __udivmod((unsigned)n, (unsigned)d, 1);
  return neg ? -(int)r : (int)r;
}

// ---- VGA Decimal Output ----

void vga_print_num(int row, int col, int num) {
  char buf[8];
  int i = 0, is_neg = 0;
  if (num < 0) { is_neg = 1; num = -num; }
  if (num == 0) buf[i++] = '0';
  while (num > 0) { buf[i++] = (num % 10) + '0'; num /= 10; }
  if (is_neg) buf[i++] = '-';

  volatile char *vram = VGA_VRAM;
  int off = row * 80 + col;
  int pad = 6 - i;
  while (pad-- > 0) vram[off++] = ' ';
  while (i > 0) { i--; vram[off++] = buf[i]; }
  vram[off] = ' ';
}

// ---- v2mac inline ----

static inline int32_t builtin_v2mac(int32_t rd, int32_t rs1, int32_t rs2) {
  int32_t res;
  asm volatile(".insn r 0x0b, 0, 0, %0, %1, %2"
               : "=r"(res) : "r"(rs1), "r"(rs2), "0"(rd));
  return res;
}

// ---- Convolution ----

#define N 4
#define M 4
int16_t X[N];
int16_t H[M];
int32_t Y[N + M - 1];

void print_arrays() {
  volatile char *vram = VGA_VRAM;
  vram[2*80+2] = 'X'; vram[2*80+3] = ':';
  for (int i = 0; i < N; i++) vga_print_num(2, 6+i*7, X[i]);

  vram[3*80+2] = 'H'; vram[3*80+3] = ':';
  for (int i = 0; i < M; i++) vga_print_num(3, 6+i*7, H[i]);

  vram[5*80+2] = 'Y'; vram[5*80+3] = ':';
  for (int i = 0; i < N+M-1; i++) vga_print_num(5, 6+i*7, Y[i]);
}

void print_status(char mode) {
  volatile char *vram = VGA_VRAM;
  int off = 8*80+2;
  vram[off++] = 'M'; vram[off++] = 'D'; vram[off++] = ':';
  vram[off++] = ' '; vram[off] = mode;
}

void conv_standard() {
  for (int i = 0; i < N+M-1; i++) {
    int32_t sum = 0;
    for (int j = 0; j < M; j++) {
      if (i-j >= 0 && i-j < N)
        sum += (int32_t)X[i-j] * (int32_t)H[j];
    }
    Y[i] = sum;
  }
}

void conv_v2mac() {
  for (int i = 0; i < N+M-1; i++) {
    int32_t sum = 0;
    for (int j = 0; j < M; j += 2) {
      int16_t x0 = (i-j >= 0 && i-j < N) ? X[i-j] : 0;
      int16_t x1 = (i-(j+1) >= 0 && i-(j+1) < N) ? X[i-(j+1)] : 0;
      int16_t h0 = H[j];
      int16_t h1 = (j+1 < M) ? H[j+1] : 0;
      uint32_t px = ((uint32_t)(uint16_t)x1 << 16) | (uint16_t)x0;
      uint32_t ph = ((uint32_t)(uint16_t)h1 << 16) | (uint16_t)h0;
      sum = builtin_v2mac(sum, (int32_t)px, (int32_t)ph);
    }
    Y[i] = sum;
  }
}

// ---- Main ----

int main() {
  // Clear VGA
  for (int i = 0; i < 4096; i++) VGA_VRAM[i] = ' ';

  // Init arrays
  for (int i = 0; i < N; i++) X[i] = i + 1;
  for (int i = 0; i < M; i++) H[i] = 1;

  print_arrays();
  print_status('W');

  unsigned int last_cycles = 0;

  while (1) {
    unsigned int sw_val = GPIO_SW;
    unsigned int key_val = GPIO_KEY;

    int new_x0 = (sw_val >> 4) & 0xF;
    if (X[0] != new_x0) {
      X[0] = new_x0;
      print_arrays();
      print_status('W');
    }

    GPIO_LEDR = sw_val;

    // Standard Conv (KEY[1])
    if ((key_val & 0x02) == 0) {
      print_status('S');
      TIMER_CONTROL = 0x03; TIMER_CONTROL = 0x01;
      conv_standard();
      TIMER_CONTROL = 0x05; TIMER_CONTROL = 0x01;
      last_cycles = TIMER_SNAP;
      vga_print_num(8, 12, last_cycles);
      print_arrays();
      while ((GPIO_KEY & 0x02) == 0);
    }

    // V2MAC Conv (KEY[2])
    if ((key_val & 0x04) == 0) {
      print_status('V');
      TIMER_CONTROL = 0x03; TIMER_CONTROL = 0x01;
      conv_v2mac();
      TIMER_CONTROL = 0x05; TIMER_CONTROL = 0x01;
      last_cycles = TIMER_SNAP;
      vga_print_num(8, 12, last_cycles);
      print_arrays();
      while ((GPIO_KEY & 0x04) == 0);
    }
  }
  return 0;
}
