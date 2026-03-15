`timescale 1ns/1ps


module IMEM #(
    parameter FIRMWARE_FILE = "../../RISCV/RISCV_32I_MAC_3/software/C_code/files/add.hex"
)(
    input [31:0] addr,
    output [31:0] data_o
);
    
    localparam im_aw = 10;

    reg [31:0] imem [0:(1 << im_aw)-1]; // [data] register [addr]

    initial begin
        $readmemh(FIRMWARE_FILE, imem);
    end


    wire [im_aw-1:0] widx = addr[im_aw+1:2];
    assign data_o = imem[widx];

endmodule
