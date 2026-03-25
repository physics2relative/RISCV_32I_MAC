module DE1_top (
      input              CLOCK_50,
      input       [3:0]  KEY,  // KEY[0]: Reset
      input       [9:0]  SW,
      output      [9:0]  LEDR, // LEDR driven by MMIO
      output      [6:0]  HEX0, HEX1, HEX2, HEX3, HEX4, HEX5,

      // SDRAM Interface (Unused)
      output      [12:0] DRAM_ADDR,
      output      [1:0]  DRAM_BA,
      output             DRAM_CAS_N,
      output             DRAM_CKE,
      output             DRAM_CLK,
      output             DRAM_CS_N,
      inout       [15:0] DRAM_DQ,
      output             DRAM_LDQM,
      output             DRAM_UDQM,
      output             DRAM_RAS_N,
      output             DRAM_WE_N,

      // VGA Interface
      output      [7:0]  VGA_R,
      output      [7:0]  VGA_G,
      output      [7:0]  VGA_B,
      output             VGA_HS,
      output             VGA_VS,
      output             VGA_CLK,
      output             VGA_BLANK_N,
      output             VGA_SYNC_N,

      // UART Interface
      input              UART_RXD,
      output             UART_TXD
);

    wire clk_w = CLOCK_50;
    wire rst_w = ~KEY[0]; 

    System_Top #(
        // You can change FIRMWARE_FILE path in QSF if needed, or point defaults correctly:
        .FIRMWARE_FILE("Z:/user/choi.jw/PROJECT/RISCV/RISCV_32I_MAC/software/C_code/files/add/add.hex")
    ) u_RV32 (
        .clk         (clk_w),
        .rst         (rst_w),        
        .core_result (),
        .pc_stall    (),
        
        .KEY         (KEY),
        .SW          (SW),
        .LEDR        (LEDR),
        .HEX0        (HEX0),
        .HEX1        (HEX1),
        .HEX2        (HEX2),
        .HEX3        (HEX3),
        .HEX4        (HEX4),
        .HEX5        (HEX5),
        
        .VGA_R       (VGA_R),
        .VGA_G       (VGA_G),
        .VGA_B       (VGA_B),
        .VGA_HS      (VGA_HS),
        .VGA_VS      (VGA_VS),
        .VGA_CLK     (VGA_CLK),
        .VGA_BLANK_N (VGA_BLANK_N),
        .VGA_SYNC_N  (VGA_SYNC_N),

        .UART_RXD    (UART_RXD),
        .UART_TXD    (UART_TXD)
    );

    // Tie off unused SDRAM ports
    assign DRAM_ADDR  = 0;
    assign DRAM_BA    = 0;
    assign DRAM_CAS_N = 1;
    assign DRAM_CKE   = 0;
    assign DRAM_CLK   = 0;
    assign DRAM_CS_N  = 1;
    assign DRAM_LDQM  = 0;
    assign DRAM_UDQM  = 0;
    assign DRAM_RAS_N = 1;
    assign DRAM_WE_N  = 1;

endmodule
