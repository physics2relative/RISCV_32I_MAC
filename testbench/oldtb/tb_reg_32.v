module tb_reg_32();

reg [31:0] in; 
reg clk, rst;
wire [31:0] out;


reg_32 uut (
    .clk(clk),
    .rst(rst),
    .in (in ),
    .out(out)
    );

always @(*) #5 clk <= ~clk;




initial begin

    clk = 1'b0;

    rst <= 1'h1;
    #3;
    rst <= 1'h0;
    #10; 
    in <= 32'h11111111; 
    #10;
    in <= 32'h11110000;
    #10;
    in <= 32'h00001111;
    #20;
    rst <= 1'h1;
    #10;

    $finish;
end

initial begin 

    $monitor("time = %t, in = %h, out = %h, rst = %b", $time,  in, out, rst);
    $shm_open("wave.shm");
    $shm_probe("ACMTF");

end
endmodule




