module tb_reg_file();

reg [31:0] inst, DataD;
reg clk, RegWEn;


wire [31:0] DataA, DataB;

reg_file uut(
    .inst(inst),
    .DataD(DataD),
    .clk(clk),
    .RegWEn(RegWEn),
    .DataA(DataA),
    .DataB(DataB)
    );

wire [4:0] AddrD = inst[11:7];
wire [4:0] AddrA = inst[19:15];
wire [4:0] AddrB = inst[24:20];


always @(*) #5 clk <= ~clk;

initial begin

    clk = 1'b0;
    RegWEn = 1'b0;

    #5;
    
    RegWEn = 1'b1; // write enabled

    // [rs2, rs1, rd1]

    inst = 32'bxxxxxx_00000_00000_xxx_00011_xxxxxxx; // rd = x3
    DataD = 32'h0000_0001; // write data = 0000_0001
    // writing : x1 = 0000_0001
    
    #10;

    inst = 32'bxxxxxx_00000_00000_xxx_00100_xxxxxxx; // rd = x4
    DataD = 32'h0000_0002; // write data = 0000_0002
    // writing : x2 = 0000_0002       
    
    #10;

    inst = 32'bxxxxxx_00000_00000_xxx_00010_xxxxxxx; // rd = x2
    DataD = 32'h0000_0003; // write data = 0000_0002  
    // writing : x0 = 0000_0003 (ignored)
    
    #10; 

    RegWEn = 1'b0; // write disabled, reading mode
  
    inst = 32'bxxxxxx_00010_00001_xxx_00000_xxxxxxx; // rs2 = x2, rs1 = x1
    // reading : rs1 = x1, rs2 = x2    
    
    #10;

    inst = 32'bxxxxxx_00000_00010_xxx_00000_xxxxxxx; // rs2 = x2, rs1 = x1
    // reading : rs1 = x2, rs2 = x0     
    
    #10;   

    $finish;
end

initial begin 

    $monitor("time = %t // [in] : AddrD = %h, AddrA = %h, AddrA = %h, Data = %h // [out] : DataA = %h, DataB = %h ", $time,AddrD,AddrA,AddrB,DataD, DataA, DataB);
    $shm_open("wave.shm");
    $shm_probe("ACMTF");

end


endmodule
