module tb;
reg  [31:0] alu_a;
reg  [31:0] alu_b;
wire signed [31:0] a_s = alu_a;
wire [4:0] shamt = alu_b[4:0];
wire [31:0] y_sra = a_s >>> shamt;

initial begin
alu_a = 32'hffff_fffd;
alu_b = 32'd3;

$display("%h", 32'hffff_fffd >>> 32'd3);
end
endmodule

