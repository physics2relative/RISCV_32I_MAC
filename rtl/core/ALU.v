`timescale 1ns/1ps

module Arithmetic(
    input [31:0] alu_a, alu_b,
    input [3:0] ALUSel,
    output reg [31:0] alu_out
    );

    wire [31:0] adder;

    wire [31:0] comparator;

    reg sub_sel;

    reg un_sel;

    ALU_adder a1 (.in_a(alu_a), .in_b(alu_b), .sub_sel(sub_sel), .result(adder));

    ALU_comparator c1 (.in_a(alu_a), .in_b(alu_b), .un_sel(un_sel), .result(comparator));

    localparam add   = 4'b0000;
    localparam sub   = 4'b0001;
    localparam and_  = 4'b0010;
    localparam or_   = 4'b0011;
    localparam xor_  = 4'b0100;
    localparam comp  = 4'b0101;
    localparam ucomp = 4'b0110;
    localparam sl    = 4'b0111;
    localparam srl   = 4'b1000;
    localparam sra   = 4'b1001;

    wire [4:0] shamt = alu_b[4:0];
    wire signed [31:0] sra_alu_a = alu_a;

    always @ (*) begin
        un_sel = 1'b0;
        sub_sel = 1'b0;
        alu_out = 32'b0;
        case(ALUSel)
            add: begin
                alu_out = adder;
                sub_sel = 1'b0;
            end
            sub: begin
                alu_out = adder;
                sub_sel = 1'b1;
            end
            and_:
                alu_out = (alu_a & alu_b);
            or_:
                alu_out = (alu_a | alu_b);
            xor_:
                alu_out = (alu_a ^ alu_b);
            comp: begin
                alu_out = comparator;
                un_sel  = 1'b0;
            end
            ucomp: begin
                alu_out = comparator;
                un_sel  = 1'b1;
            end
            sl:
                alu_out = (alu_a << shamt);
            srl:
                alu_out = (alu_a >> shamt);
            sra: 
                alu_out = sra_alu_a >>> shamt;
            default:
                alu_out = 32'b0;
        endcase
    end

endmodule
