`timescale 1ns/1ps

module RV32I_DataPath(
    input clk,
    input rst,

    // Instruction and PC
    input [31:0] inst,
    output [31:0] pc_out,

    // Control Signals from ControlPath
    input PCSel, 
    input RegWEn, 
    input BrUn, 
    input ASel, 
    input ASel_LUI,
    input BSel, 
    input [2:0] ImmSel,
    input [3:0] ALUSel,
    input [1:0] WBSel,

    // Status Signals to ControlPath
    output BrEq,
    output BrLT,

    // Register File outputs for MAC Unit
    output [31:0] DataA_out,
    output [31:0] DataB_out,

    // Memory Interface (Data)
    output [31:0] dmem_addr,
    output [31:0] dmem_data_w,
    input  [31:0] dmem_data_r,

    // MAC Port (optional, kept from original RV32I_MAC_top)
    input override_en,
    input pc_en,
    input wb_sel_mac,
    input addr_sel_mac,
    input [31:0] mac_WB,
    input reg_wen_mac,
    input [4:0] mac_rd,
    output [31:0] result,
    output pc_stall
    );

// pc
reg [31:0] pc;
wire [31:0] pc_plus4 = pc + 32'd4;
wire [31:0] pc_next;

// Register file
wire [4:0] rs1 = inst[19:15];
wire [4:0] rs2 = inst[24:20];
wire [4:0] rd  = inst[11:7];
wire [31:0] DataA, DataB;
wire [31:0] DataWB;

// Immediate 
wire [31:0] imm;

// Export RegFile data for MAC unit
assign DataA_out = DataA;
assign DataB_out = DataB;

// ALU
reg [31:0] alu_a;
wire [31:0] alu_b, alu_out;

// Select AddrA or AddrD (for MAC support)
wire [4:0] Addr_AD;
assign Addr_AD = (addr_sel_mac) ? mac_rd : rs1;

// Select Final WriteBack (for MAC support)
wire [31:0] Final_WB;
assign Final_WB = (wb_sel_mac) ? mac_WB : DataWB;

// PC stall
assign pc_stall = (inst == 32'hDEAD_DEAD);

// PC Selector mux (Enforce LSB = 0 for Branch/Jump Targets)
assign pc_next = (PCSel) ? pc_plus4 : (alu_out & ~32'h1);
assign pc_out = pc;

// PC register
always @ (posedge clk) begin
    if (rst)            pc   <= 32'h0040_0000;
    else if (pc_stall)  pc   <= pc;
    else if (pc_en)     pc   <= pc_next; // pc_en is usually 1, or controlled by MAC
end

// Register File write enable logic (MAC override)
wire RegWEn_final;
assign RegWEn_final = (override_en) ? reg_wen_mac : RegWEn;

//Register File
reg_file u_reg(
    .AddrD( (addr_sel_mac) ? mac_rd : rd ),
    .AddrA(Addr_AD),
    .AddrB(rs2),
    .DataA(DataA),
    .DataB(DataB),
    .DataD(Final_WB),
    .clk(clk),
    .RegWEn(RegWEn_final),
    .result(result),
    .rst(rst)
    );

//Immediate Generator
ImmGen u_immGen(
    .inst(inst[31:7]),
    .ImmSel(ImmSel),
    .imm(imm)
    );

//Branch Comparator
BranchComp u_branch(
    .DataA(DataA),
    .DataB(DataB),
    .BrUn(BrUn),
    .BrEq(BrEq),
    .BrLT(BrLT)
    );

//A Selector
always @ (*) begin
    if (ASel_LUI)
        alu_a = 32'd0;
    else if (ASel)
        alu_a = pc;
    else 
        alu_a = DataA;
end

//B Selector
assign alu_b = (BSel) ? imm : DataB;

//Arithmetic Logic Unit
Arithmetic u_alu(
    .alu_a(alu_a),
    .alu_b(alu_b),
    .ALUSel(ALUSel),
    .alu_out(alu_out)
    );

// Write Back Selector
assign DataWB = (WBSel == 2'b00) ? dmem_data_r :
                (WBSel == 2'b01) ? alu_out :
                (WBSel == 2'b10) ? pc_plus4 :
                32'b0;

// Memory interface assignments
assign dmem_addr = alu_out;
assign dmem_data_w = DataB;

endmodule
