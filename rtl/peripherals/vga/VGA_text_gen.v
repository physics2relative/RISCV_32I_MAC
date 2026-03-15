module VGA_text_gen (    
    input         clk,
    input         rst_n,        
    input  [9:0]  pixel_x,    
    input  [9:0]  pixel_y,    
    output [7:0]  vga_r,      
    output [7:0]  vga_g,
    output [7:0]  vga_b,

    // Interface to External VMEM
    output reg [11:0] vmem_addr,
    input      [7:0]  char_code
);

    wire [6:0] grid_x = pixel_x[9:3]; 
    wire [4:0] grid_y = pixel_y[8:4];
    
    // Register vmem_addr by 1 cycle.
    // This compensates for the fact that VMEM (external dual-port BRAM)
    // has 1-cycle read latency -- the address must be presented one cycle
    // earlier so char_code comes back aligned with the correct grid cell.
    always @(posedge clk) begin
        vmem_addr <= (grid_y * 80) + grid_x;
    end

    wire [3:0] row_addr = pixel_y[3:0]; 
    wire [7:0] font_pixels;             

    font_rom u_font (
        .clk       (clk),
        .char_code (char_code[6:0]),  // font_rom port is 7-bit [6:0]
        .row_addr  (row_addr),    
        .row_data  (font_pixels) 
    );

    // Pipeline delay for sub-pixel X position.
    // Total latency from pixel_x to font_pixels output:
    //   Cycle 0: pixel_x → grid calculation (combinational)
    //   Cycle 1: vmem_addr registered (this always block above)
    //   Cycle 2: VMEM BRAM read → char_code valid
    //   Cycle 3: font_rom BRAM read → font_pixels valid
    // So sub_x must be delayed 3 cycles to match.
    reg [2:0] sub_x_d1, sub_x_d2, sub_x_d3;

    always @(posedge clk) begin
        sub_x_d1 <= pixel_x[2:0]; 
        sub_x_d2 <= sub_x_d1;
        sub_x_d3 <= sub_x_d2;
    end

    wire is_pixel_on = font_pixels[7 - sub_x_d3]; 

    assign vga_r = is_pixel_on ? 8'hFF : 8'h00;
    assign vga_g = is_pixel_on ? 8'hFF : 8'h00;
    assign vga_b = is_pixel_on ? 8'hFF : 8'h00;

endmodule

