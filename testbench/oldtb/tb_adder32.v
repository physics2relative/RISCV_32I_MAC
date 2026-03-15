module tb_adder32();

reg [31:0] a,b;

wire [31:0] sum;
wire c_out;

wire error_sig;

assign error_sig = (error == 0);



adder_cla32 uut(
    .a(a),
    .b(b),
    .c_in(1'b0),
    .s(sum),
    .c_out(c_out)
    );

integer i;
integer errors;
integer seed;

wire [32:0] sum_dut = {c_out, sum};

task automatic check_once(input [31:0] aa, input [31:0] bb);
    reg [32:0] sum_ref;
    begin
        sum_ref = {1'b0, aa} + {1'b0, bb};

        a = aa;
        b = bb;
        #1;

        if (sum_dut !== sum_ref) begin
            errors = errors + 1;
            $display("Mismatch: a=%h b=%h dut=%h ref=%h @%0t",
                        aa, bb, sum_dut, sum_ref, $time);
        end
    end

endtask

function [31:0] rand32;
    integer r1, r2;
    begin
        r1 = $random(seed);
        rand32 = r1[31:0];
    end
endfunction

initial begin 
    errors = 0;
    seed = 31'h1A2B3C4D;
    
    check_once(32'h0000_0000, 32'h0000_0000);
    check_once(32'hFFFF_FFFF, 32'h0000_0001);
    check_once(32'h8000_0000, 32'h8000_0000);
    check_once(32'hAAAA_AAAA, 32'h5555_5555);
    
    for (i = 0; i < 10000; i = i + 1) begin
        check_once(rand32(), rand32());
    end
    
    if (errors == 0) begin
        $display("PASS: all tests passed.");
    end 
    else begin
        $display("FAIL: %0d mismatch(es) found.", errors);
    end
    
    $finish;
    
    end


initial begin 

    //$monitor("time = %t // [in] : %b // [out] : DataA = %h, DataB = %h ", $time,AddrD,AddrA,AddrB,DataD, DataA, DataB);
    $shm_open("wave.shm");
    $shm_probe("ACMTF");

end


endmodule
