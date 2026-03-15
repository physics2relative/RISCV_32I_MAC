module tb_ALU();

reg [31:0] a,b;
reg [3:0] ALUSel;

wire [31:0] out_uut;

Arithmetic uut(
    .alu_a(a),
    .alu_b(b),
    .ALUSel(ALUSel),
    .alu_out(out_uut)
    );

integer i, j;
integer errors;
integer seed;

task automatic check_once(input [31:0] aa, input [31:0] bb, input [3:0] ss);
    reg [31:0] out_ref;
    reg less_than;
    begin
        
        case(ss)
            4'b0000:
                out_ref = aa + bb;
            4'b0001:
                out_ref = aa - bb;           
            4'b0010:
                out_ref = aa & bb;
            4'b0011:
                out_ref = aa | bb;
            4'b0100:
                out_ref = aa ^ bb;
            4'b0101: begin
                less_than = ($signed(aa) < $signed(bb));
                out_ref = {{31{1'b0}}, {less_than}};
                end
            4'b0110: begin
                less_than = (aa < bb);
                out_ref = {{31{1'b0}}, {less_than}};
                end
            4'b0111:
                out_ref = aa << bb;
            4'b1000:
                out_ref = aa >> bb;
            4'b1001:
                out_ref = aa >>> bb;
        endcase
        
        a = aa;
        b = bb;
        ALUSel = ss;

        #5;

        if (out_uut !== out_ref) begin
            errors = errors + 1;
            $display("Mismatch: a=%h b=%h sel = %b uut=%h ref=%h @%0t",
                        aa, bb,ss ,out_uut, out_ref, $time);
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

function [3:0] rand4;
    integer r3;
    begin
        do begin
            r3 = $random(seed);
        end while (r3[3:0] > 4'd9);

        rand4 = r3[3:0];
    end
endfunction

initial begin 
    errors = 0;
    seed = 31'h1A2B3C4D;
        
    for (j = 0; j < 10  ; j = j + 1) begin
        check_once(rand32(), rand4(), 4'd7);
    end
    
    for (j = 0; j < 10  ; j = j + 1) begin
        check_once(rand32(), rand4(), 4'd8);
    end
    
    for (j = 0; j < 10  ; j = j + 1) begin
        check_once(rand32(), rand4(), 4'd9);
    end

    for (i = 0; i < 10000 ; i = i + 1) begin
        check_once(rand32(), rand32(), rand4());
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
