`timescale 1ns/1ps

module DMEM(
    input        clk,
    input        cs,        // Chip Select from Interconnect
    input [31:0] Addr, 
    input [31:0] DataW,
    input [1:0]  WdLen,     // length of load data
    input [2:0]  MemRW,     // Read length or store  
    input        LoadEx,    // Unsigned or Signed extension 
    output [31:0] DataO
    );
       
    // WdLen parameter (read)
    localparam read_byte = 2'd0;
    localparam read_half = 2'd1;
    localparam read_word = 2'd2;

    // MemRW parameter (write)
    localparam write_byte = 3'd0;
    localparam write_half = 3'd1;
    localparam write_word = 3'd2;
    localparam read_mode  = 3'd3;
    localparam idle_mode  = 3'd4;
    
    // localparam for address width
    localparam dm_aw = 8;

    reg [7:0] dmem [0:(1 << dm_aw)-1]; // [data] register [addr]

    reg [31:0] DataR;

    wire [dm_aw-1:0] a0 = Addr[dm_aw-1:0];
    wire [dm_aw-1:0] a1 = a0 + 8'd1;
    wire [dm_aw-1:0] a2 = a0 + 8'd2;
    wire [dm_aw-1:0] a3 = a0 + 8'd3;
    
    // CS-gated read output
    assign DataO = (cs && MemRW == read_mode) ? DataR : 32'd0;

    // Initialize
    integer i;
    initial begin
        for (i=0; i < (1 << (dm_aw)); i=i+1) dmem[i] = 8'b0;
    end

    // Writing (store) - gated by CS
    always @ (posedge clk) begin
        if (cs) begin
            case(MemRW)
                write_byte: 
                    dmem[a0]    <= DataW[7:0];
                write_half: begin
                    dmem[a0]    <= DataW[7:0];
                    dmem[a1]    <= DataW[15:8];
                end
                write_word: begin
                    dmem[a0]    <= DataW[7:0];
                    dmem[a1]    <= DataW[15:8];
                    dmem[a2]    <= DataW[23:16];
                    dmem[a3]    <= DataW[31:24];
                end
                default: begin end 
            endcase
        end
    end

    // Reading (load)
    always @ (*) begin
        DataR = 32'd0;
        case(WdLen)
            read_byte: begin
                if(LoadEx) // zero extension
                    DataR = {{24{1'b0}}, dmem[a0]};
                else       // signed extension
                    DataR = {{24{dmem[a0][7]}}, dmem[a0]};
            end
            read_half: begin
                if(LoadEx) // zero extension
                    DataR = {{16{1'b0}}, dmem[a1], dmem[a0]};
                else       // signed extension
                    DataR = {{16{dmem[a1][7]}}, dmem[a1], dmem[a0]};
            end
            read_word: 
                DataR = {dmem[a3], dmem[a2], dmem[a1], dmem[a0]};
            default:
                DataR = 32'b0;
        endcase                     
    end

endmodule 
