`timescale 1ns/1ps

module tb_imem;
  reg  [31:0] addr;
  wire [31:0] data_o;

  IMEM dut (
    .addr  (addr),
    .data_o(data_o)
  );

initial begin 
    $shm_open("wave.shm");
    $shm_probe("ACMTF");

end 



endmodule


