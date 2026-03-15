`timescale 1ns/1ps

module VGA_Subsystem (
    input         clk,         // 50MHz System Clock
    input         rst_n,       // Active Low Reset
    
    // MMIO Interface (VMEM CPU Port)
    input         vmem_we,
    input  [11:0] vmem_addr,
    input  [7:0]  vmem_wdata,
    
    // VGA Physical Pins
    output [7:0]  VGA_R,       
    output [7:0]  VGA_G,       
    output [7:0]  VGA_B,       
    output        VGA_HS,      
    output        VGA_VS,      
    output        VGA_CLK,     
    output        VGA_BLANK_N,  
    output        VGA_SYNC_N   
);

    // ====================================================
    // 1. Clock Generation: 50MHz -> 25MHz via Clock Divider
    // ====================================================
    reg vga_pixel_clk_reg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            vga_pixel_clk_reg <= 1'b0;
        else
            vga_pixel_clk_reg <= ~vga_pixel_clk_reg;
    end
    
    wire vga_pixel_clk = vga_pixel_clk_reg;

    // VGA_CLK driven to the external DAC.
    // It is INVERTED (~vga_pixel_clk) so that the DAC latches data on the falling edge 
    // of the internal 25MHz clock, perfectly centering the latch point in the middle 
    // of the data valid window (data changes on the rising edge).
    // This physically prevents remaining hold/setup time noise (green lines).
    assign VGA_CLK = ~vga_pixel_clk;

    // ====================================================
    // 2. Internal Wires
    // ====================================================
    wire [9:0] pixel_x;
    wire [9:0] pixel_y;
    wire       video_on; // Display Enable (DE)
    
    wire [7:0] vga_r_w;
    wire [7:0] vga_g_w;
    wire [7:0] vga_b_w;
    wire       hs_w;
    wire       vs_w;
    
    wire [11:0] vga_read_addr;
    wire [7:0]  char_code_w;

    // ====================================================
    // 3. Video Memory (Dual-Port RAM)
    // ====================================================
    VMEM u_vmem (
        // Port A (CPU Write via MMIO)
        .clk_a   (clk),         // System clock for CPU
        .we_a    (vmem_we),
        .addr_a  (vmem_addr),
        .din_a   (vmem_wdata),
        
        // Port B (VGA Read)
        .clk_b   (vga_pixel_clk), // 25MHz Pixel Clock
        .addr_b  (vga_read_addr),
        .dout_b  (char_code_w)
    );

    // ====================================================
    // 4. VGA Sync Generator
    // ====================================================
    VGA_sync_gen u_sync (
        .clk        (vga_pixel_clk),
        .rst_n      (rst_n),
        .h_sync     (hs_w),
        .v_sync     (vs_w),
        .DE         (video_on),
        .pixel_x    (pixel_x),
        .pixel_y    (pixel_y)
    );

    // ====================================================
    // 5. VGA Text Generator (Pixel Renderer)
    // ====================================================
    VGA_text_gen u_text (
        .clk        (vga_pixel_clk),
        .rst_n      (rst_n),
        .pixel_x    (pixel_x),
        .pixel_y    (pixel_y),
        .vmem_addr  (vga_read_addr),
        .char_code  (char_code_w),
        .vga_r      (vga_r_w),
        .vga_g      (vga_g_w),
        .vga_b      (vga_b_w)
    );

    // ====================================================
    // 6. Pipeline Delay Compensation
    // ====================================================
    // Total latency: vmem_addr_reg(1) + VMEM_read(1) + font_rom_read(1) = 3 cycles
    // video_on must be delayed by the same 3 cycles to match RGB output.
    
    reg video_on_d1, video_on_d2, video_on_d3;
    always @(posedge vga_pixel_clk) begin
        if (!rst_n) begin
            video_on_d1 <= 1'b0;
            video_on_d2 <= 1'b0;
            video_on_d3 <= 1'b0;
        end else begin
            video_on_d1 <= video_on;
            video_on_d2 <= video_on_d1;
            video_on_d3 <= video_on_d2;
        end
    end
    
    assign VGA_R = video_on_d3 ? vga_r_w : 8'h00;
    assign VGA_G = video_on_d3 ? vga_g_w : 8'h00;
    assign VGA_B = video_on_d3 ? vga_b_w : 8'h00;
    
    // Sync signals must NOT be delayed, otherwise the monitor's 
    // active region shifts relative to the front/back porch, cropping the left edge.
    assign VGA_HS      = hs_w;
    assign VGA_VS      = vs_w;
    
    // ADV7123 requires BLANK_N to go low during blanking intervals
    assign VGA_BLANK_N = video_on_d3;
    
    // Tie SYNC_N to 0 to disable Sync-On-Green
    assign VGA_SYNC_N  = 1'b0;

endmodule
