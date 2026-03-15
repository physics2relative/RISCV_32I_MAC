`timescale 1ns/1ps

module VMEM (
    // Port A: CPU Interface (Write Only in typical MMIO, but usually standard RAM)
    input             clk_a,
    input             we_a,
    input      [11:0] addr_a, // 4KB address space (2400 bytes used for 80x30 text mode)
    input      [7:0]  din_a,
    
    // Port B: VGA Interface (Read Only)
    input             clk_b,
    input      [11:0] addr_b,
    output reg [7:0]  dout_b
);

    // 8-bit width, 4096 depth (fits in a standard block RAM)
    reg [7:0] vram [0:4095];
    
    // Initialize with spaces (ASCII 0x20)
    integer i;
    initial begin
        for (i = 0; i < 4096; i = i + 1) begin
            vram[i] = 8'h20; // Space character
        end
    end

    // Port A: CPU Write
    always @(posedge clk_a) begin
        if (we_a) begin
            vram[addr_a] <= din_a;
        end
    end

    // Port B: VGA Read
    always @(posedge clk_b) begin
        dout_b <= vram[addr_b];
    end

endmodule
