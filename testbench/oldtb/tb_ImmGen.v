module tb_ImmGen();

reg [31:7] inst;
reg [3:0] ImmSel;

wire [31:0] imm;

ImmGen uut(
    .inst(inst),
    .ImmSel(ImmSel),
    .imm(imm)
    );

initial begin
    
   ImmSel = 3'b000; // I type

   inst = 25'b0000000_00001_xxxxx_xxx_xxxxx; // imm[11:0] = 1
   
   #5;

   inst = 25'b0000000_00010_xxxxx_xxx_xxxxx; // imm[11:0] = 2

   #5;

   inst = 25'b1111111_11111_xxxxx_xxx_xxxxx; // imm[11:0] = -1

   #5; 

   inst = 25'b1111111_11110_xxxxx_xxx_xxxxx; // imm[11:0] = -2

   #10;
    
   ImmSel = 3'b001; // S type

   inst = 25'b0000000_xxxxx_xxxxx_xxx_00001; // imm[11:0] = 1
   
   #5;

   inst = 25'b0000000_xxxxx_xxxxx_xxx_00010; // imm[11:0] = 2

   #5;

   inst = 25'b1111111_xxxxx_xxxxx_xxx_11111; // imm[11:0] = -1

   #5; 

   inst = 25'b1111111_xxxxx_xxxxx_xxx_11110; // imm[11:0] = -2

   #10;
    
   ImmSel = 3'b010; // B type

   inst = 25'b0000000_xxxxx_xxxxx_xxx_00010; // imm[12:1] = 1 -> imm[12:0] = 2
   
   #5;

   inst = 25'b0000000_xxxxx_xxxxx_xxx_00100; // imm[12:1] = 2 -> imm[12:0] = 4

   #5;

   inst = 25'b1111111_xxxxx_xxxxx_xxx_11111; // imm[12:1] = -1 -> imm[12:0] = -2

   #5; 

   inst = 25'b1111111_xxxxx_xxxxx_xxx_11101; // imm[12:1] = -2 -> imm[12:0] = -4

   #10;
    
   ImmSel = 3'b011; // U type

   inst = 25'b0000000_00000_00000_001_xxxxx; // imm[31:12] = 1 -> imm[31:0] = 4096
   
   #5;

   inst = 25'b0000000_00000_00000_010_xxxxx; // imm[31:12] = 2 -> imm[31:0] = 8192

   #5;

   inst = 25'b1111111_11111_11111_111_xxxxx; // imm[31:12] = -1 -> imm[31:0] = -4096 

   #5; 

   inst = 25'b1111111_11111_11111_110_xxxxx; // imm[31:12] = -2 -> imm[31:0] = -8192

   #10;
    
   ImmSel = 3'b100; // J type

   inst = 25'b0000000_00010_00000_000_xxxxx; // imm[20:1] = 1 -> imm[20:0] = 2
   
   #5;

   inst = 25'b0000000_00100_00000_000_xxxxx; // imm[20:1] = 2 -> imm[20:0] = 4

   #5;

   inst = 25'b1111111_11111_11111_111_xxxxx; // imm[20:1] = -1 -> imm[20:0] = -2

   #5; 

   inst = 25'b1111111_11101_11111_111_xxxxx; // imm[20:1] = -2 -> imm[20:0] = -4

   #10;





   $finish;
end

initial begin 

//    $monitor("time = %t // [in] : %b // [out] : DataA = %h, DataB = %h ", $time,AddrD,AddrA,AddrB,DataD, DataA, DataB);
    $shm_open("wave.shm");
    $shm_probe("ACMTF");

end


endmodule
