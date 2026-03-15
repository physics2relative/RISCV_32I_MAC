`timescale 1ns/1ps

module ImmGen(
    input [31:7] inst,
    input [2:0] ImmSel,
    output reg [31:0] imm
    );
    
    localparam I = 3'b000;
    localparam S = 3'b001;
    localparam B = 3'b010;
    localparam U = 3'b011;
    localparam J = 3'b100;
    
    always @ (*) begin
        case(ImmSel)
            I: imm = { {20{inst[31]}}, inst[31:20] };
            S: imm = { {20{inst[31]}}, inst[31:25], inst[11:7] };
            B: imm = { {20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0 };
            U: imm = { inst[31:12] , {12{1'b0}} };
            J: imm = { {11{inst[31]}}, inst[31], inst[19:12], inst[20] ,inst[30:21], 1'b0 };
            default: imm = 32'h0;
        endcase
    end
endmodule
