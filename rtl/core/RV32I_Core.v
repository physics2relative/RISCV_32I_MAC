`timescale 1ns/1ps


module RV32I_Core(
    input clk,
    input rst,

    // IMEM Interface
    output [31:0] imem_addr,
    input  [31:0] inst,

    // DMEM Interface (goes to MMIO Interconnect)
    output [31:0] dmem_addr,
    output [31:0] dmem_data_w,
    input  [31:0] dmem_data_r,
    output [1:0] WdLen,
    output [2:0] MemRW,
    output LoadEx,

    // MAC Port (optional)
    output [31:0] result,
    output pc_stall
    );

    // Internal Connections between ControlPath and DataPath
    wire PCSel, RegWEn, BrUn, ASel, ASel_LUI, BSel;
    wire [2:0] ImmSel;
    wire [3:0] ALUSel;
    wire [1:0] WBSel;
    wire BrEq, BrLT;
    
    wire [31:0] DataA, DataB;
    wire mac_on, pc_en, wb_sel_mac, addr_sel_mac, reg_wen_mac;
    wire [31:0] mac_WB;
    wire [4:0] mac_rd;

    // Data Path
    RV32I_DataPath u_datapath(
        .clk(clk),
        .rst(rst),
        .inst(inst),
        .pc_out(imem_addr),
        .PCSel(PCSel),
        .RegWEn(RegWEn),
        .BrUn(BrUn),
        .ASel(ASel),
        .ASel_LUI(ASel_LUI),
        .BSel(BSel),
        .ImmSel(ImmSel),
        .ALUSel(ALUSel),
        .WBSel(WBSel),
        .BrEq(BrEq),
        .BrLT(BrLT),
        .DataA_out(DataA),
        .DataB_out(DataB),
        .dmem_addr(dmem_addr),
        .dmem_data_w(dmem_data_w),
        .dmem_data_r(dmem_data_r),
        .override_en(mac_on),
        .pc_en(pc_en),
        .wb_sel_mac(wb_sel_mac),
        .addr_sel_mac(addr_sel_mac),
        .mac_WB(mac_WB),
        .mac_rd(mac_rd),
        .reg_wen_mac(reg_wen_mac),
        .result(result),
        .pc_stall(pc_stall)
    );

    // Control Path (Instruction Decode & Setup)
    RV32I_ControlPath u_controlpath(
        .inst(inst),
        .BrEq(BrEq),
        .BrLT(BrLT),
        .PCSel(PCSel),
        .RegWEn(RegWEn),
        .BrUn(BrUn),
        .ASel(ASel),
        .ASel_LUI(ASel_LUI),
        .BSel(BSel),
        .ImmSel(ImmSel),
        .ALUSel(ALUSel),
        .WBSel(WBSel),
        .WdLen(WdLen),
        .MemRW(MemRW),
        .LoadEx(LoadEx)
    );

    MAC2_top u_MAC(
        .clk(clk),
        .rst(rst),
        .DataA(DataA),
        .DataB(DataB),
        .inst(inst),
        .mac_on(mac_on),
        .pc_en(pc_en),
        .wb_sel_mac(wb_sel_mac),
        .addr_sel_mac(addr_sel_mac),
        .reg_wen_mac(reg_wen_mac),
        .mac_WB(mac_WB),
        .mac_rd(mac_rd)
    );

endmodule
