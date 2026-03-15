`timescale 1ns / 1ps 

module tb_MAC();

reg         clk;
reg  [31:0] DataA; 
reg  [31:0] DataB;
reg  [31:0] inst;
wire        override_en;
wire        pc_en; 
wire        wb_sel_mac; 
wire        addr_sel_mac; 
wire [31:0] mac_WB;

MAC_top uut(
    .clk(clk),
    .DataA(DataA),
    .DataB(DataB),
    .inst(inst),
    .override_en(override_en),
    .pc_en(pc_en),
    .wb_sel_mac(wb_sel_mac),
    .addr_sel_mac(addr_sel_mac),
    .mac_WB(mac_WB)
    );

always #5 clk = ~clk;

initial begin

clk = 1'b0;
DataA = 32'h0;
DataB = 32'h0;
inst  = 32'b0000000_00000_00000_000_00000_0001011;

end

initial begin

#10;

#5;

DataA <= #1 32'h0001_0003;
DataB <= #1 32'h0004_0002;

#10;

DataA = #1 32'h0000_0004;

#30;




$finish;

end

initial begin 

    //$monitor("time = %t // [in] : %b // [out] : DataA = %h, DataB = %h ", $time,AddrD,AddrA,AddrB,DataD, DataA, DataB);
    $shm_open("wave.shm");
    $shm_probe("ACMTF");

end


endmodule


