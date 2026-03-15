`timescale 1ns/1ps

module MMIO_Interconnect(
    // Interfaces to Core
    input [31:0] core_addr,
    input [31:0] core_wdata,
    input [2:0]  core_MemRW,     // Memory operation (Read/Write size)
    input [1:0]  core_WdLen,     // Load Size
    input        core_LoadEx,    // Signed/Unsigned Load
    output [31:0] core_rdata,

    // Interface to DMEM (Memory memory map starts at 0x0000_0000)
    output [31:0] dmem_addr,
    output [31:0] dmem_wdata,
    output [2:0]  dmem_MemRW,
    output [1:0]  dmem_WdLen,
    output        dmem_LoadEx,
    input  [31:0] dmem_rdata,

    // Interface to Peripheral 1 (Example GPIO memory map starts at 0x4000_0000)
    // output [31:0] gpio_addr,
    // output [31:0] gpio_wdata,
    // output [2:0]  gpio_MemRW,
    // input  [31:0] gpio_rdata

    // Interface to VMEM (VGA Text Buffer starts at 0x4000_0000)
    output        vmem_we,
    output [11:0] vmem_addr,
    output [7:0]  vmem_wdata
    );

    // Example Memory Map Definitions
    // 0x0000_0000 ~ 0x0000_FFFF: Data Memory (64KB max)
    // 0x4000_0000 ~ 0x4000_0FFF: User Peripherals (GPIO, UART, etc.)
    
    // Address decoder rules
    wire cs_dmem = (core_addr < 32'h2000_0000);
    // wire cs_gpio = (core_addr >= 32'h4000_0000 && core_addr < 32'h4000_1000);
    wire cs_vmem = (core_addr >= 32'h4000_0000 && core_addr < 32'h4000_1000); // 4KB Range

    // Output assignment to DMEM
    assign dmem_addr   = core_addr;
    assign dmem_wdata  = core_wdata;
    assign dmem_WdLen  = core_WdLen;
    assign dmem_LoadEx = core_LoadEx;
    
    // Pass write/read enable signal only when chip select is true.
    // MemRW behavior from DMEM: 0,1,2=Write, 3=Read Mode. 4=Idle
    assign dmem_MemRW  = cs_dmem ? core_MemRW : 3'd4; // 3'd4 is idle_mode in DMEM.v

    // Output assignment to GPIO Peripheral (Commented out for future use)
    // assign gpio_addr   = core_addr;
    // assign gpio_wdata  = core_wdata;
    // assign gpio_MemRW  = cs_gpio ? core_MemRW : 3'd4;

    // Output assignment to VMEM (Width Adapter)
    // core_MemRW: 0=SB/SW, 1=SH, 2=SW -> Any write operation triggers vmem_we
    assign vmem_we    = cs_vmem & (core_MemRW == 3'd0 || core_MemRW == 3'd1 || core_MemRW == 3'd2);
    assign vmem_addr  = core_addr[11:0]; // Extract bottom 12 bits for 4KB dual-port RAM
    assign vmem_wdata = core_wdata[7:0]; // Extract bottom 8 bits for ASCII char code

    // Multiplexer for Core Read Data
    assign core_rdata = cs_dmem ? dmem_rdata  : 
                        // cs_gpio ? gpio_rdata  : 
                        32'b0; // VMEM is Write-Only from the CPU's perspective

endmodule
