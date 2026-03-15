module font_rom ( 
    input              clk,
    input       [6:0]  char_code, // ASCII Code (0x00 ~ 0x7F)
    input       [3:0]  row_addr,  // Row (0 ~ 15)
    output reg  [7:0]  row_data   // Pixel Data
);

    reg [7:0] rom [0:2047];
    
    initial begin
        $readmemb("/user/choi.jw/PROJECT/VGA/VGA_ASCII/font_rom/font_rom.txt", rom);
    end

    wire [10:0] addr = {char_code, row_addr};

    always @(posedge clk) begin
        row_data <= rom[addr];
    end

endmodule
