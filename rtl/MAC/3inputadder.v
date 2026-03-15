`timescale 1ns/1ps

`timescale 1ns / 1ps 

module adder3(
    input  [31:0] in_a
,   input  [31:0] in_b
,   input  [31:0] in_c
,   output [31:0] out
);

assign out = in_a + in_b + in_c;

endmodule

