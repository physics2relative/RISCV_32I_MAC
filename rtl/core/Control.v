`timescale 1ns/1ps

module Control(
    input [31:0] inst,
    input BrLT, BrEq,
    output     ASel_LUI,
    output reg PCSel,
    output reg [2:0] ImmSel,
    output reg RegWEn,
    output reg BrUn,
    output reg ASel,
    output reg BSel,
    output reg [3:0] ALUSel,
    output reg [1:0] WdLen,
    output reg [2:0] MemRW,
    output reg LoadEx,
    output reg [1:0] WBSel
    );

    //PCSel
    always @ (*) begin
        PCSel = 1'b1;
        
        case(inst[6:0])
            7'b1101111: PCSel = 1'b0;
            7'b1100111: PCSel = 1'b0;
            7'b1100011: begin
                case(inst[14:12])
                    3'b000: if(BrEq) PCSel = 1'b0; else PCSel = 1'b1;
                    3'b001: if(BrEq) PCSel = 1'b1; else PCSel = 1'b0;
                    3'b100: if(BrLT) PCSel = 1'b0; else PCSel = 1'b1;
                    3'b101: if(BrLT) PCSel = 1'b1; else PCSel = 1'b0;
                    3'b110: if(BrLT) PCSel = 1'b0; else PCSel = 1'b1;
                    3'b111: if(BrLT) PCSel = 1'b1; else PCSel = 1'b0;
                    default: PCSel = 1'b1;
                endcase
            end
            default: PCSel = 1'b1;
        endcase
    end 

    //ImmSel
    always @ (*) begin
        ImmSel = 3'd7;
        
        case(inst[6:0]) 
            7'b1101111: ImmSel = 3'd4;
            7'b1100111: ImmSel = 3'd0; // <-- FIX: Added JALR (I-Type Immediate)
            7'b1100011: ImmSel = 3'd2;    
            7'b0110111: ImmSel = 3'd3;
            7'b0010111: ImmSel = 3'd3;
            7'b0100011: ImmSel = 3'd1;
            7'b0010011: ImmSel = 3'd0;
            7'b0110011: ImmSel = 3'd7;
            7'b0000011: ImmSel = 3'd0;
            default   : ImmSel = 3'd7;
        endcase
    end

    //Wdlen (read)
    always @ (*) begin
        WdLen = 2'd3;
        if(inst[6:0] == 7'b0000011) begin
            case(inst[14:12]) 
                3'b000: WdLen = 2'd0;
                3'b001: WdLen = 2'd1;
                3'b010: WdLen = 2'd2;
                3'b100: WdLen = 2'd0;
                3'b101: WdLen = 2'd1;
                default: WdLen = 2'd3;
            endcase
            end
        else 
            WdLen = 2'd3;
    end

    //BrUn
    always @ (*) begin
        BrUn = 1'b0;
        if(inst[6:0] == 7'b1100011) begin
            if(inst[14:13] == 2'b11) BrUn = 1'b1; 
        end
    end

    //ASel
    always @ (*) begin
        ASel = 1'b0;
        case(inst[6:0]) 
            7'b0010111: ASel = 1'b1;
            7'b1101111: ASel = 1'b1;
            7'b1100111: ASel = 1'b0;
            7'b1100011: ASel = 1'b1;
            default   : ASel = 1'b0;
        endcase
    end

    //ASel_LUI
    assign ASel_LUI = (inst[6:0] == 7'b0110111);
    
    //BSel
    always @ (*) begin
        BSel = 1'b1;
        case(inst[6:0])
            7'b0110011: BSel = 1'b0;
            default   : BSel = 1'b1;
        endcase
    end

    //RegWEn
    always @ (*) begin
        RegWEn = 1'b1;
        case(inst[6:0])
            7'b0001011: RegWEn = 1'b0;
            7'b1100011: RegWEn = 1'b0;
            7'b0100011: RegWEn = 1'b0;
            default   : RegWEn = 1'b1;
        endcase
    end

    //MemRW (write)
    always @ (*) begin
        MemRW = 3'd4;
        if(inst[6:0] == 7'b0000011)
            MemRW = 3'd3;
        else if(inst[6:0] == 7'b0100011) begin
            case(inst[14:12]) 
                3'b000: MemRW = 3'd0;
                3'b001: MemRW = 3'd1;
                3'b010: MemRW = 3'd2;
            endcase
        end
    end

    //LoadEx
    always @ (*) begin
        LoadEx = 1'b0;
        if(inst[6:0] == 7'b0000011) 
            if(inst[14] == 1'b1) LoadEx = 1'b1;
        else LoadEx = 1'b0;
    end

    //WBSel
    always @ (*) begin
        WBSel = 2'd1;
        case(inst[6:0]) 
            7'b1101111: WBSel = 2'd2;
            7'b1100111: WBSel = 2'd2;
            7'b0000011: WBSel = 2'd0;
            default   : WBSel = 2'd1;
        endcase
    end

    //ALUSel
    always @ (*) begin
        ALUSel = 4'd15;
        case(inst[6:0])
            7'b0110111: ALUSel = 4'd0;
            7'b0010111: ALUSel = 4'd0;
            7'b1101111: ALUSel = 4'd0;
            7'b1100111: ALUSel = 4'd0;
            7'b0000011: ALUSel = 4'd0;
            7'b0100011: ALUSel = 4'd0;
            7'b1100011: ALUSel = 4'd0;
            7'b0010011: begin 
                case(inst[14:12]) 
                    3'b000: ALUSel = 4'd0;
                    3'b010: ALUSel = 4'd5;
                    3'b011: ALUSel = 4'd6;
                    3'b100: ALUSel = 4'd4;
                    3'b110: ALUSel = 4'd3;
                    3'b111: ALUSel = 4'd2;
                    3'b001: ALUSel = 4'd7;
                    3'b101: ALUSel = (inst[30]) ? 4'd9 : 4'd8;
                    default: ALUSel = 4'd12;
                endcase
            end
            7'b0110011: begin
                case(inst[14:12])
                    3'b000: ALUSel = (inst[30]) ? 4'd1 : 4'd0;
                    3'b001: ALUSel = 4'd7;
                    3'b010: ALUSel = 4'd5;
                    3'b011: ALUSel = 4'd6;
                    3'b100: ALUSel = 4'd4;
                    3'b101: ALUSel = (inst[30]) ? 4'd9 : 4'd8;
                    3'b110: ALUSel = 4'd3;
                    3'b111: ALUSel = 4'd2;
                    default: ALUSel = 4'd13;
                endcase
            end
            default: ALUSel = 4'd14;
        endcase
    end

endmodule
    
                    
                
                


