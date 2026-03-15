`timescale 1ns/1ps


module ALU_adder(
    input [31:0] in_a, in_b,
    input sub_sel,
    output [31:0] result
    );

    wire [31:0] b = (sub_sel) ? (~in_b) + 1'b1: (in_b);

    adder_cla32 cla(
        .a(in_a),
        .b(b),
        .c_in(1'b0),
        .s(result),
        .c_out()
        );

endmodule
    
