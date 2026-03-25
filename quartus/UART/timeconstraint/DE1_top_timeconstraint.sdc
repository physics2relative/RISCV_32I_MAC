create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]
derive_pll_clocks
derive_clock_uncertainty

create_generated_clock -name vga_pixel_clk \
    -source [get_ports {CLOCK_50}] \
    -divide_by 2 \
    [get_registers {*|vga_pixel_clk}]