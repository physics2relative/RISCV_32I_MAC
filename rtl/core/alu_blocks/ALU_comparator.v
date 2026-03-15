`timescale 1ns/1ps


module ALU_comparator(
    input [31:0] in_a, in_b,
    input un_sel,
    output [31:0] result
    );

    reg less_than;

    assign result = { {31{1'b0}}, less_than };

    always @ (*) begin
        if(un_sel)  // unsigned comparison 
            less_than = (in_a < in_b); 
        else
            less_than = ($signed(in_a) < $signed(in_b));
    end

endmodule

    
