`timescale 1ns/1ps

module BranchComp(
    input [31:0] DataA, DataB,
    input BrUn,
    output reg BrEq, BrLT
    );

    wire signed [31:0] s_DataA = DataA;
    wire signed [31:0] s_DataB = DataB;
    
    always @ (*) begin

        BrEq = (DataA == DataB); 

        if (BrUn) // Unsigned less than
            BrLT = (DataA < DataB);
        else // Signed less than
            BrLT = (s_DataA < s_DataB);

    end


endmodule 

