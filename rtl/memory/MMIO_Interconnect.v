`timescale 1ns/1ps

module MMIO_Interconnect(
    // Interfaces to Core
    input [31:0] core_addr,
    input [31:0] core_wdata,
    input [2:0]  core_MemRW,     // Memory operation (Read/Write size)
    input [1:0]  core_WdLen,     // Load Size
    input        core_LoadEx,    // Signed/Unsigned Load
    output [31:0] core_rdata,

    // Chip Select Outputs
    output cs_dmem,
    output cs_gpio,
    output cs_vmem,
    output cs_timer,

    // Interface to DMEM
    output [31:0] dmem_addr,
    output [31:0] dmem_wdata,
    output [2:0]  dmem_MemRW,
    output [1:0]  dmem_WdLen,
    output        dmem_LoadEx,
    input  [31:0] dmem_rdata,

    // Interface to GPIO
    output [31:0] gpio_addr,
    output [31:0] gpio_wdata,
    output [2:0]  gpio_MemRW,
    input  [31:0] gpio_rdata,

    output [11:0] vmem_addr,
    output [7:0]  vmem_wdata,
    output [2:0]  vmem_MemRW,

    // Interface to Timer
    output [31:0] timer_addr,
    output [31:0] timer_wdata,
    output [2:0]  timer_MemRW,
    input  [31:0] timer_rdata,

    // Interface to UART
    output        cs_uart,
    output [31:0] uart_addr,
    output [31:0] uart_wdata,
    output [2:0]  uart_MemRW,
    input  [31:0] uart_rdata
    );

    // =========================================================
    // Memory Map
    // 0x0000_0000 ~ 0x1FFF_FFFF : Data Memory
    // 0x1000_0000 ~ 0x1000_00FF : GPIO (KEY, SW, LED, HEX)
    // 0x4000_0000 ~ 0x4000_0FFF : VMEM (VGA Text Buffer, 4KB)
    // =========================================================

    // Address Decoder - Chip Select Generation
    assign cs_dmem  = (core_addr < 32'h1000_0000);
    assign cs_gpio  = (core_addr >= 32'h1000_0000 && core_addr < 32'h1000_0100);
    assign cs_timer = (core_addr >= 32'h2000_0000 && core_addr < 32'h2000_0100);
    assign cs_uart  = (core_addr >= 32'h3000_0000 && core_addr < 32'h3000_0100);
    assign cs_vmem  = (core_addr >= 32'h4000_0000 && core_addr < 32'h4000_1000);

    // =========================================================
    // DMEM Interface: Pass-through with CS gating
    // =========================================================
    assign dmem_addr   = core_addr;
    assign dmem_wdata  = core_wdata;
    assign dmem_WdLen  = core_WdLen;
    assign dmem_LoadEx = core_LoadEx;
    assign dmem_MemRW  = core_MemRW;

    // =========================================================
    // GPIO Interface: Pass-through
    // =========================================================
    assign gpio_addr   = core_addr;
    assign gpio_wdata  = core_wdata;
    assign gpio_MemRW  = core_MemRW;

    // =========================================================
    // VMEM Interface: Width Adapter (32-bit -> 12-bit addr, 8-bit data)
    // =========================================================
    assign vmem_addr   = core_addr[11:0];
    assign vmem_wdata  = core_wdata[7:0];
    assign vmem_MemRW  = core_MemRW;

    // =========================================================
    // Timer Interface: Pass-through
    // =========================================================
    assign timer_addr  = core_addr;
    assign timer_wdata = core_wdata;
    assign timer_MemRW = core_MemRW;

    // =========================================================
    // UART Interface: Pass-through
    // =========================================================
    assign uart_addr   = core_addr;
    assign uart_wdata  = core_wdata;
    assign uart_MemRW  = core_MemRW;

    // =========================================================
    // Read Data Multiplexer
    // =========================================================
    assign core_rdata = cs_dmem  ? dmem_rdata  :
                        cs_gpio  ? gpio_rdata  :
                        cs_timer ? timer_rdata :
                        cs_uart  ? uart_rdata  :
                        // cs_vmem is write-only from CPU perspective
                        32'b0;

endmodule
