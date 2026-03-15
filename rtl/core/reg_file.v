`timescale 1ns/1ps

module reg_file(
    input [4:0] AddrD,
    input [4:0] AddrA,
    input [4:0] AddrB,
    input [31:0] DataD,
    input clk,
    input RegWEn,
    input rst,

    output [31:0] DataA,
    output [31:0] DataB,
    output [31:0] result
    );

    reg [31:0] reg32 [0:31]; // [data] register [addr]

    integer i;

    always @ (posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1) begin
                reg32[i] <= 32'd0;
            end
        end
        else if (RegWEn && (AddrD != 5'd0))
            reg32[AddrD] <= DataD;
    end

    assign DataA = (AddrA == 5'd0) ? 32'h0 : reg32[AddrA];
    assign DataB = (AddrB == 5'd0) ? 32'h0 : reg32[AddrB];

    assign result = reg32[31];

endmodule 
