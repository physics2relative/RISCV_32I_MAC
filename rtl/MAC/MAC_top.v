`timescale 1ns/1ps

module MAC_top(
 input         rst
,input         clk
,input  [31:0] DataA 
,input  [31:0] DataB 
,input  [31:0] inst 
,output reg    override_en 
,output reg    pc_en 
,output reg    wb_sel_mac 
,output reg    addr_sel_mac 
,output reg    reg_wen_mac
,output [31:0] mac_WB
,output [4:0]  mac_rd
);

localparam s_IDLE     = 2'b00;
localparam s_LATCH_RS = 2'b01;
localparam s_FETCH_RD = 2'b10;
localparam s_CALC_WB  = 2'b11;

reg [1:0] state;

reg [31:0] mul_a;
reg [31:0] mul_b;

reg [31:0] read_rd;
reg [31:0] latched_inst;

wire [31:0] mult_high;
wire [31:0] mult_low;


wire [15:0] mul_a_high;
wire [15:0] mul_a_low;
wire [15:0] mul_b_high;
wire [15:0] mul_b_low;

multiplier16 mult1(
    .in_a(mul_a_high),
    .in_b(mul_b_high),
    .out (mult_high)
    );

multiplier16 mult2(
    .in_a(mul_a_low),
    .in_b(mul_b_low),
    .out (mult_low)
    );

adder3 adder(
    .in_a(mult_high),
    .in_b(mult_low),
    .in_c(read_rd),
    .out (mac_WB)
    );


assign mul_a_high = mul_a[31:16];
assign mul_a_low  = mul_a[15:0];
assign mul_b_high = mul_b[31:16];
assign mul_b_low  = mul_b[15:0];

assign MAC_start = (inst[31:25] == 7'b0000000) && (inst[14:12] == 3'b000) && (inst[6:0] == 7'b0001011);
assign mac_rd    = latched_inst[11:7];

    // state output
    always @ (*) begin
        override_en  = 1'b0;
        pc_en        = 1'b0;
        wb_sel_mac   = 1'b0;
        addr_sel_mac = 1'b0;
        reg_wen_mac  = 1'b0;

        case(state) 
            s_IDLE: begin
                override_en  = 1'b0;
                if (MAC_start) pc_en = 1'b0;
                else           pc_en = 1'b1;
                wb_sel_mac   = 1'b0;
                addr_sel_mac = 1'b0;
                reg_wen_mac  = 1'b0;
            end
            s_LATCH_RS: begin
                override_en  = 1'b1;
                pc_en        = 1'b0;
                wb_sel_mac   = 1'b0;
                addr_sel_mac = 1'b0;
                reg_wen_mac  = 1'b0;
            end
            s_FETCH_RD: begin
                override_en  = 1'b1;
                pc_en        = 1'b0;
                wb_sel_mac   = 1'b0;
                addr_sel_mac = 1'b1;
                reg_wen_mac  = 1'b0;
            end           
            s_CALC_WB: begin
                override_en  = 1'b1;
                pc_en        = 1'b1;
                wb_sel_mac   = 1'b1;
                addr_sel_mac = 1'b1;
                reg_wen_mac  = 1'b1;
            end
            default: begin
                override_en  = 1'b0;
                pc_en        = 1'b1;
                wb_sel_mac   = 1'b0;
                addr_sel_mac = 1'b0;
            end
        endcase
    end
    
    // state transition
    always @ (posedge clk) begin
        if (rst) 
            state <= s_IDLE;
        else begin
        case(state)
            s_IDLE    : begin
                if (MAC_start) 
                    state <= s_LATCH_RS;
                else    
                    state <= s_IDLE;
            end
            s_LATCH_RS: begin
                state <= s_FETCH_RD;
            end
            s_FETCH_RD: begin
                state <= s_CALC_WB;
            end
            s_CALC_WB:  state <= s_IDLE;
            default:    state <= s_IDLE;
        endcase
        end
    end

  // state filp flop
    always @ (posedge clk) begin
        case(state) 
            s_IDLE    : begin  
                if (MAC_start) latched_inst <= inst;
            end
            s_LATCH_RS: begin 
                mul_a <= DataA;
                mul_b <= DataB;
            end
            s_FETCH_RD: read_rd <= DataA; 
            s_CALC_WB : begin 
`ifdef SIMULATION
                $display("[MAC Debug] inst=%h | rs1(mul_a)=%h, rs2(mul_b)=%h, rd(old)=%h", latched_inst, mul_a, mul_b, read_rd);
                $display("[MAC Debug]   high_a=%d * high_b=%d = %d", $signed(mul_a_high), $signed(mul_b_high), $signed(mult_high));
                $display("[MAC Debug]   low_a=%d * low_b=%d = %d", $signed(mul_a_low), $signed(mul_b_low), $signed(mult_low));
                $display("[MAC Debug]   mac_WB(new_rd) = %d", $signed(mac_WB));
`endif
            end 
            default   : begin end    
        endcase           
    end

endmodule    
         


        

