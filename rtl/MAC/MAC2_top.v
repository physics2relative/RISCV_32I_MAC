`timescale 1ns/1ps

module MAC2_top(
    input         rst,
    input         clk,
    input  [31:0] DataA,      // From RegFile Port1
    input  [31:0] DataB,      // From RegFile Port2
    input  [31:0] inst,
    output reg    mac_on,     // Replaces override_en
    output reg    pc_en,
    output reg    wb_sel_mac,
    output reg    addr_sel_mac,
    output reg    reg_wen_mac,
    output [31:0] mac_WB,
    output [4:0]  mac_rd
);

    // State definitions
    localparam S_DETECTION = 1'b0; // Detection & Start
    localparam S_FETCH_WB  = 1'b1; // Fetch RD & WB

    reg state;

    // Internal registers for latching rs1, rs2 (Cycle 1)
    reg [31:0] mul_a;
    reg [31:0] mul_b;
    reg [31:0] latched_inst;

    // instruction decode
    wire v2mac = (inst[31:25] == 7'b0000000) && (inst[14:12] == 3'b000) && (inst[6:0] == 7'b0001011);
    
    assign mac_rd = latched_inst[11:7];

    // Combinational Logic for Output Signals
    always @ (*) begin
        // Default values
        pc_en        = 1'b1;
        mac_on       = 1'b0;
        addr_sel_mac = 1'b0;
        wb_sel_mac   = 1'b0;
        reg_wen_mac  = 1'b0;

        case(state)
            S_DETECTION: begin
                if (v2mac) begin
                    pc_en  = 1'b0;
                    mac_on = 1'b1;
                end else begin
                    pc_en  = 1'b1;
                    mac_on = 1'b0;
                end
                reg_wen_mac = 1'b0;
            end

            S_FETCH_WB: begin
                pc_en        = 1'b1;
                mac_on       = 1'b1; // Must maintain 1 to override RegWEn for Write-back
                addr_sel_mac = 1'b1; // Read rd from Port1
                wb_sel_mac   = 1'b1;
                reg_wen_mac  = 1'b1; // Note: diagram said 0, but for WB it must be 1. 
                                     // (If you want to strictly follow diagram 0, 
                                     // please let me know, but 1 is required for writing.)
            end
        endcase
    end

    // Sequential Logic for State Transition and Latching
    always @ (posedge clk) begin
        if (rst) begin
            state <= S_DETECTION;
            mul_a <= 32'b0;
            mul_b <= 32'b0;
            latched_inst <= 32'b0;
        end else begin
            case(state)
                S_DETECTION: begin
                    if (v2mac) begin
                        state        <= S_FETCH_WB;
                        mul_a        <= DataA;
                        mul_b        <= DataB;
                        latched_inst <= inst;
                    end
                end

                S_FETCH_WB: begin
                    state <= S_DETECTION;
                end
            endcase
        end
    end

    // MAC Arithmetic: (rs1_h * rs2_h) + (rs1_l * rs2_l) + rd
    // Behavioral modeling to infer Cyclone V DSP Multiplier-Adder mode
    wire [15:0] mul_a_high = mul_a[31:16];
    wire [15:0] mul_a_low  = mul_a[15:0];
    wire [15:0] mul_b_high = mul_b[31:16];
    wire [15:0] mul_b_low  = mul_b[15:0];

    // DataA contains 'rd' value in the 2nd cycle because of addr_sel_mac = 1
    assign mac_WB = ($signed(mul_a_high) * $signed(mul_b_high)) + 
                    ($signed(mul_a_low)  * $signed(mul_b_low))  + 
                    $signed(DataA);

endmodule
