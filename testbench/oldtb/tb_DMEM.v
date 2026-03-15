module tb_DMEM();

reg [31:0] Addr, DataW;
reg [1:0] WdLen;
reg [2:0] MemRW;
reg LoadEx;
reg clk;

wire [31:0] DataO;

DMEM uut(
    .Addr(Addr),
    .DataW(DataW),
    .WdLen(WdLen),
    .MemRW(MemRW),
    .clk(clk),
    .LoadEx(LoadEx),
    .DataO(DataO)
    );

always @(*) #5 clk <= ~clk;

initial begin
    clk = 1'b0;
    MemRW = 3'd4; // IDLE mode
    WdLen = 2'd3; // NULL  
    LoadEx = 1'b0;

    #5; 

    /// writing ///
    Addr    = 32'h1000_0000;
    DataW   = 32'h1122_3344;
    MemRW = 3'd2; // write_word 
    LoadEx = 1'b0;
    #10;

    Addr    = 32'h1000_0004;
    DataW   = 32'h5566_7788;
    MemRW = 3'd2; // write_word
    LoadEx = 1'b0;
    #10;

    Addr    = 32'h1000_0008;
    DataW   = 32'h0000_00AA;
    MemRW = 3'd2; // write_byte 
    LoadEx = 1'b0;
    #10;

    Addr    = 32'h1000_0009;
    DataW   = 32'h0000_00BB;
    MemRW = 3'd2; // write_byte
    LoadEx = 1'b0;
    #10;

    Addr    = 32'h1000_000A;
    DataW   = 32'h0000_CCDD;
    MemRW = 3'd1; // write_half
    LoadEx = 1'b0;
    #10;

    /// reading ///
    DataW   = 32'h0;
    Addr    = 32'h1000_0000;
    MemRW = 3'd3; // read_mode
    WdLen = 3'd2;
    LoadEx = 1'b0;
    #10;

    Addr    = 32'h1000_0000;
    MemRW = 3'd3; // read_mode
    WdLen = 3'd2;
    LoadEx = 1'b0;
    #10;

    Addr    = 32'h1000_0000;
    MemRW = 3'd3; // read_mode
    WdLen = 3'd0;
    LoadEx = 1'b0;
    #10;

    Addr    = 32'h1000_0000;
    MemRW = 3'd3; // read_mode
    WdLen = 3'd0;
    LoadEx = 1'b1;
    #10;

    Addr    = 32'h1000_0000;
    MemRW = 3'd3; // read_mode
    WdLen = 3'd1;
    LoadEx = 1'b0;
    #10;

    Addr    = 32'h1000_0000;
    MemRW = 3'd3; // read_mode
    WdLen = 3'd1;
    LoadEx = 1'b1;
    #10;

    $finish;

end

initial begin 

    $shm_open("wave.shm");
    $shm_probe("ACMTF");

end


endmodule
