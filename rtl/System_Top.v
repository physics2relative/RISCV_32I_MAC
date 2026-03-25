`timescale 1ns/1ps

module System_Top #(
    parameter FIRMWARE_FILE = "Z:/user/choi.jw/PROJECT/RISCV/RISCV_32I_MAC/software/C_code/files/add/add.hex"
)(
    input clk,
    input rst,

    // MAC interface exposed to the top
    output [31:0] core_result,
    output pc_stall,

    // DE1-SoC GPIO Physical Pins
    input  [3:0]  KEY,
    input  [9:0]  SW,
    output [9:0]  LEDR,
    output [6:0]  HEX0,
    output [6:0]  HEX1,
    output [6:0]  HEX2,
    output [6:0]  HEX3,
    output [6:0]  HEX4,
    output [6:0]  HEX5,

    // VGA Physical Pins
    output [7:0]  VGA_R,       
    output [7:0]  VGA_G,       
    output [7:0]  VGA_B,       
    output        VGA_HS,      
    output        VGA_VS,      
    output        VGA_CLK,     
    output        VGA_BLANK_N,  
    output        VGA_SYNC_N,

    // UART Physical Pins
    input         UART_RXD,
    output        UART_TXD
    );

    // ==========================================
    // Core <--> IMEM Signals (Instruction Fetch)
    // ==========================================
    wire [31:0] imem_addr;
    wire [31:0] inst;

    // ==========================================
    // Core <--> Interconnect Signals (Data Memory)
    // ==========================================
    wire [31:0] core_dmem_addr;
    wire [31:0] core_dmem_wdata;
    wire [31:0] core_dmem_rdata;
    wire [1:0]  core_WdLen;
    wire [2:0]  core_MemRW;
    wire        core_LoadEx;

    // ==========================================
    // Interconnect <--> DMEM Signals
    // ==========================================
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [31:0] dmem_rdata;
    wire [1:0]  dmem_WdLen;
    wire [2:0]  dmem_MemRW;
    wire        dmem_LoadEx;

    // ==========================================
    // Interconnect <--> GPIO Signals
    // ==========================================
    wire [31:0] gpio_addr;
    wire [31:0] gpio_wdata;
    wire [31:0] gpio_rdata;
    wire [2:0]  gpio_MemRW;

    // ==========================================
    // Interconnect <--> VMEM Signals (VGA)
    // ==========================================
    wire [11:0] vmem_addr;
    wire [7:0]  vmem_wdata;
    wire [2:0]  vmem_MemRW;

    // ==========================================
    // Interconnect <--> Timer Signals
    // ==========================================
    wire [31:0] timer_addr;
    wire [31:0] timer_wdata;
    wire [31:0] timer_rdata;
    wire [2:0]  timer_MemRW;

    // ==========================================
    // Interconnect <--> UART Signals
    // ==========================================
    wire [31:0] uart_addr;
    wire [31:0] uart_wdata;
    wire [31:0] uart_rdata;
    wire [2:0]  uart_MemRW;
    wire        cs_uart;

    // ==========================================
    // Chip Select Signals from Interconnect
    // ==========================================
    wire cs_dmem;
    wire cs_gpio;
    wire cs_vmem;
    wire cs_timer;

    // ==========================================
    // 1. Processor Core Integration
    // ==========================================
    RV32I_Core u_core (
        .clk(clk),
        .rst(rst),
        
        // IMEM Interface
        .imem_addr(imem_addr),
        .inst(inst),

        // DMEM Interface
        .dmem_addr(core_dmem_addr),
        .dmem_data_w(core_dmem_wdata),
        .dmem_data_r(core_dmem_rdata),
        .WdLen(core_WdLen),
        .MemRW(core_MemRW),
        .LoadEx(core_LoadEx),
        
        // MAC Ports
        .result(core_result),
        .pc_stall(pc_stall)
    );

    // ==========================================
    // 2. Memory Logic (IMEM)
    // ==========================================
    IMEM #(
        .FIRMWARE_FILE(FIRMWARE_FILE)
    ) u_imem (
        .addr(imem_addr),
        .data_o(inst)
    );

    // ==========================================
    // 3. System Interconnect (Bus/MMIO Decoder)
    // ==========================================
    MMIO_Interconnect u_interconnect (
        // From Core
        .core_addr(core_dmem_addr),
        .core_wdata(core_dmem_wdata),
        .core_MemRW(core_MemRW),
        .core_WdLen(core_WdLen),
        .core_LoadEx(core_LoadEx),
        .core_rdata(core_dmem_rdata),

        // Chip Select Outputs
        .cs_dmem(cs_dmem),
        .cs_gpio(cs_gpio),
        .cs_vmem(cs_vmem),

        // To Data Memory
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_MemRW(dmem_MemRW),
        .dmem_WdLen(dmem_WdLen),
        .dmem_LoadEx(dmem_LoadEx),
        .dmem_rdata(dmem_rdata),

        // To GPIO
        .gpio_addr(gpio_addr),
        .gpio_wdata(gpio_wdata),
        .gpio_MemRW(gpio_MemRW),
        .gpio_rdata(gpio_rdata),

        // To VMEM (VGA Text Buffer)
        .vmem_addr(vmem_addr),
        .vmem_wdata(vmem_wdata),
        .vmem_MemRW(vmem_MemRW),

        // To Timer
        .cs_timer(cs_timer),
        .timer_addr(timer_addr),
        .timer_wdata(timer_wdata),
        .timer_MemRW(timer_MemRW),
        .timer_rdata(timer_rdata),

        // To UART
        .cs_uart(cs_uart),
        .uart_addr(uart_addr),
        .uart_wdata(uart_wdata),
        .uart_MemRW(uart_MemRW),
        .uart_rdata(uart_rdata)
    );

    // ==========================================
    // 4. Memory Base (DMEM)
    // ==========================================
    DMEM u_dmem (
        .clk(clk),
        .cs(cs_dmem),
        .Addr(dmem_addr),
        .DataW(dmem_wdata),
        .WdLen(dmem_WdLen),
        .MemRW(dmem_MemRW),
        .LoadEx(dmem_LoadEx),
        .DataO(dmem_rdata)
    );

    // ==========================================
    // 5. GPIO Peripheral
    // ==========================================
    GPIO u_gpio (
        .clk(clk),
        .rst(rst),

        // MMIO Interface
        .cs(cs_gpio),
        .MemRW(gpio_MemRW),
        .addr(gpio_addr),
        .wdata(gpio_wdata),
        .rdata(gpio_rdata),

        // DE1-SoC Physical Pins
        .KEY(KEY),
        .SW(SW),
        .LEDR(LEDR),
        .HEX0(HEX0),
        .HEX1(HEX1),
        .HEX2(HEX2),
        .HEX3(HEX3),
        .HEX4(HEX4),
        .HEX5(HEX5)
    );

    // ==========================================
    // 6. VGA Subsystem (MMIO Peripheral)
    // ==========================================
    VGA_Subsystem u_vga (
        .clk(clk),
        .rst_n(~rst),
        
        // MMIO CPU Interface
        .cs(cs_vmem),
        .MemRW(vmem_MemRW),
        .vmem_addr(vmem_addr),
        .vmem_wdata(vmem_wdata),
        
        // VGA External Pins
        .VGA_R(VGA_R),
        .VGA_G(VGA_G),
        .VGA_B(VGA_B),
        .VGA_HS(VGA_HS),
        .VGA_VS(VGA_VS),
        .VGA_CLK(VGA_CLK),
        .VGA_BLANK_N(VGA_BLANK_N),
        .VGA_SYNC_N(VGA_SYNC_N)
    );

    // ==========================================
    // 7. Timer Peripheral
    // ==========================================
    Timer u_timer (
        .clk(clk),
        .rst(rst),

        // MMIO Interface
        .cs(cs_timer),
        .MemRW(timer_MemRW),
        .addr(timer_addr),
        .wdata(timer_wdata),
        .rdata(timer_rdata)
    );

    // ==========================================
    // 8. UART Peripheral (MMIO Wrapper)
    // ==========================================
    UART_MMIO u_uart (
        .clk(clk),
        .rst(rst),

        // MMIO Interface
        .cs(cs_uart),
        .MemRW(uart_MemRW),
        .addr(uart_addr),
        .wdata(uart_wdata),
        .rdata(uart_rdata),

        // Physical Interface
        .rx_serial(UART_RXD),
        .tx_serial(UART_TXD)
    );

endmodule
