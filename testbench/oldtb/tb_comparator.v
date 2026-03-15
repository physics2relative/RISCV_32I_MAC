module tb_comparator();

reg [31:0] a,b;
reg un_sel;

wire [31:0] out;

ALU_comparator uut(
    .in_a(a),
    .in_b(b),
    .un_sel(un_sel),
    .result(out)
    );

integer i;
integer errors;
integer seed;

task automatic check_once(input [31:0] aa, input [31:0] bb, input ss);
    reg [31:0] comp_ref;
    begin
        comp_ref = (ss) ? (aa < bb) : ($signed(aa) < $signed(bb));

        a = aa;
        b = bb;
        un_sel = ss;
        #1;

        if (out !== comp_ref) begin
            errors = errors + 1;
            $display("Mismatch: a=%b b=%b dut=%b ref=%b @%0t",
                        aa, bb, out, comp_ref, $time);
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

function rand1;
    integer r3;
    begin
        r3 = $random(seed);
        rand1 = r3;
    end
endfunction

initial begin 
    errors = 0;
    seed = 31'h1A2B3C4E;
    
    check_once(32'h0000_0000, 32'h0000_0000, 1'b0);
    check_once(32'hFFFF_FFFF, 32'h0000_0001, 1'b1);
    check_once(32'h8000_0000, 32'h8000_0000, 1'b1);
    check_once(32'hAAAA_AAAA, 32'h5555_5555, 1'b0);
    
    for (i = 0; i < 10 ; i = i + 1) begin
        check_once(rand32(), rand32(), rand1());
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
