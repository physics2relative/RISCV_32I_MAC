module ssd(
   input [3:0] num,
   output reg [6:0] ssd
   );

    always @(*) begin
        case (num)
            4'h0 : ssd = 7'b1000000; // 0
            4'h1 : ssd = 7'b1111001; // 1
            4'h2 : ssd = 7'b0100100; // 2
            4'h3 : ssd = 7'b0110000; // 3
            4'h4 : ssd = 7'b0011001; // 4
            4'h5 : ssd = 7'b0010010; // 5
            4'h6 : ssd = 7'b0000010; // 6
            4'h7 : ssd = 7'b1111000; // 7
            4'h8 : ssd = 7'b0000000; // 8
            4'h9 : ssd = 7'b0010000; // 9
            4'hA : ssd = 7'b0001000; // A
            4'hB : ssd = 7'b0000011; // b 
            4'hC : ssd = 7'b1000110; // C
            4'hD : ssd = 7'b0100001; // d 
            4'hE : ssd = 7'b0000110; // E
            4'hF : ssd = 7'b0001110; // F
            default: ssd = 7'b1111111; //
        endcase
    end

endmodule
