`timescale 1ns/1ps
 
module multiplier16(
    input  [15:0] in_a
,   input  [15:0] in_b
,   output [31:0] out
);

assign out = $signed(in_a) * $signed(in_b);


endmodule
