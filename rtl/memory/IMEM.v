`timescale 1ns/1ps


module IMEM #(
    parameter FIRMWARE_FILE = "Z:/user/choi.jw/PROJECT/RISCV/RISCV_32I_MAC/software/C_code/files/add/add.hex"
)(
    input [31:0] addr,
    output [31:0] data_o
);
    
    localparam im_aw = 9;

    reg [31:0] imem [0:(1 << im_aw)-1]; // [data] register [addr]

    initial begin
        $readmemh(FIRMWARE_FILE, imem);
    end


    wire [im_aw-1:0] widx = addr[im_aw+1:2];
    assign data_o = imem[widx];

endmodule
