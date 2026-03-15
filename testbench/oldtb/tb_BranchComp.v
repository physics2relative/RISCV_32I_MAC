module tb_BranchComp();

reg [31:0] DataA, DataB;
reg BrUn;

wire BrEq, BrLT;

BranchComp uut(
    .DataA(DataA),
    .DataB(DataB),
    .BrUn(BrUn),
    .BrEq(BrEq),
    .BrLT(BrLT)
    );

initial begin
    
   BrUn = 1'b0; // Sigend Comparison

   DataA = 32'h0000_0001;
   DataB = 32'h0000_0002;

   #10;

   DataA = 32'hFFFF_FFFF;
   DataB = 32'h0000_0001;

   #10;

   DataA = 32'h0000_0000;
   DataB = 32'h0000_0000;

   #10;
   
   BrUn = 1'b1; // UnSigend Comparison

   DataA = 32'h0000_0001;
   DataB = 32'h0000_0002;

   #10;

   DataA = 32'hFFFF_FFFF;
   DataB = 32'h0000_0001;

   #10;

   DataA = 32'h0000_0000;
   DataB = 32'h0000_0000;

   #10;

   $finish;

end

initial begin 

//    $monitor("time = %t // [in] : %b // [out] : DataA = %h, DataB = %h ", $time,AddrD,AddrA,AddrB,DataD, DataA, DataB);
    $shm_open("wave.shm");
    $shm_probe("ACMTF");

end



endmodule
