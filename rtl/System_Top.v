`timescale 1ns/1ps

module System_Top(
    input clk,
    input rst,

    // MAC interface exposed to the top (kept for compatibility with original top)
    output [31:0] core_result,
    output pc_stall,

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
    // Interconnect <--> VMEM Signals (VGA)
    // ==========================================
    wire        vmem_we;
    wire [11:0] vmem_addr;
    wire [7:0]  vmem_wdata;

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
    IMEM u_imem (
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

        // To Data Memory
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_MemRW(dmem_MemRW),
        .dmem_WdLen(dmem_WdLen),
        .dmem_LoadEx(dmem_LoadEx),
        .dmem_rdata(dmem_rdata),

        // To VMEM (VGA Text Buffer)
        .vmem_we(vmem_we),
        .vmem_addr(vmem_addr),
        .vmem_wdata(vmem_wdata)
    );

    // ==========================================
    // 4. Memory Base (DMEM)
    // ==========================================
    DMEM u_dmem (
        .Addr(dmem_addr),
        .DataW(dmem_wdata),
        .WdLen(dmem_WdLen),
        .MemRW(dmem_MemRW),
        .LoadEx(dmem_LoadEx),
        .clk(clk),
        .DataO(dmem_rdata)
    );

    // ==========================================
    // 5. VGA Subsystem (MMIO Peripheral)
    // ==========================================
    VGA_Subsystem u_vga (
        .clk(clk),
        .rst_n(~rst), // rst is Active High in System_Top, VGA_Subsystem uses Active Low rst_n
        
        // MMIO CPU Interface
        .vmem_we(vmem_we),
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

endmodule
