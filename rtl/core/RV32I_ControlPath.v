`timescale 1ns/1ps


module RV32I_ControlPath(
    // Inputs from DataPath/Instruction
    input [31:0] inst,
    input BrEq,
    input BrLT,

    // Outputs to DataPath
    output PCSel, 
    output RegWEn, 
    output BrUn, 
    output ASel, 
    output ASel_LUI,
    output BSel, 
    output [2:0] ImmSel,
    output [3:0] ALUSel,
    output [1:0] WBSel,

    // Outputs to Data Memory Interface
    output [1:0] WdLen,
    output [2:0] MemRW,
    output LoadEx
    );

    // Instantiate existing Control block directly
    // This acts as a wrapper for consistent naming, or we can use Control.v directly.
    Control u_control(
        .inst(inst),
        .BrLT(BrLT),
        .BrEq(BrEq),
        .PCSel(PCSel),
        .ImmSel(ImmSel),
        .RegWEn(RegWEn),
        .BrUn(BrUn),
        .ASel(ASel),
        .ASel_LUI(ASel_LUI),
        .BSel(BSel),
        .ALUSel(ALUSel),
        .WdLen(WdLen),
        .MemRW(MemRW),
        .LoadEx(LoadEx),
        .WBSel(WBSel)
    );

endmodule
