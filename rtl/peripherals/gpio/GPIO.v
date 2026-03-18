`timescale 1ns/1ps

// =========================================================
// GPIO Peripheral for DE1-SoC
// MMIO Base Address: 0x1000_0000
// =========================================================
// Register Map (Offset from base):
//   0x00 : [R]    KEY     - Push Buttons  [3:0]   (active low)
//   0x04 : [R]    SW      - Slide Switches [9:0]
//   0x08 : [R/W]  LEDR    - Red LEDs      [9:0]
//   0x0C : [R/W]  HEX0    - 7-Segment 0   [6:0]   (active low)
//   0x10 : [R/W]  HEX1    - 7-Segment 1   [6:0]   (active low)
//   0x14 : [R/W]  HEX2    - 7-Segment 2   [6:0]   (active low)
//   0x18 : [R/W]  HEX3    - 7-Segment 3   [6:0]   (active low)
//   0x1C : [R/W]  HEX4    - 7-Segment 4   [6:0]   (active low)
//   0x20 : [R/W]  HEX5    - 7-Segment 5   [6:0]   (active low)
// =========================================================

module GPIO (
    input         clk,
    input         rst,

    // MMIO Interface
    input         cs,          // Chip Select from Interconnect
    input  [2:0]  MemRW,       // Memory operation
    input  [31:0] addr,        // Full address (offset extracted internally)
    input  [31:0] wdata,       // Write data from Core
    output reg [31:0] rdata,   // Read data to Core

    // DE1-SoC Physical Pins (directly connected to top-level I/O)
    input  [3:0]  KEY,         // Push Buttons   (directly active-low from board)
    input  [9:0]  SW,          // Slide Switches
    output [9:0]  LEDR,        // Red LEDs
    output [6:0]  HEX0,        // 7-Segment Display 0
    output [6:0]  HEX1,        // 7-Segment Display 1
    output [6:0]  HEX2,        // 7-Segment Display 2
    output [6:0]  HEX3,        // 7-Segment Display 3
    output [6:0]  HEX4,        // 7-Segment Display 4
    output [6:0]  HEX5         // 7-Segment Display 5
);

    // MemRW encoding (shared with DMEM)
    localparam WRITE_BYTE = 3'd0;
    localparam WRITE_HALF = 3'd1;
    localparam WRITE_WORD = 3'd2;
    localparam READ_MODE  = 3'd3;

    // Internal offset from base address
    wire [7:0] offset = addr[7:0];

    // Write enable
    wire wen = cs & (MemRW == WRITE_BYTE || MemRW == WRITE_HALF || MemRW == WRITE_WORD);

    // =========================================================
    // Output Registers (active-low for HEX, directly driven for LEDs)
    // =========================================================
    reg [9:0] reg_ledr;
    reg [6:0] reg_hex0;
    reg [6:0] reg_hex1;
    reg [6:0] reg_hex2;
    reg [6:0] reg_hex3;
    reg [6:0] reg_hex4;
    reg [6:0] reg_hex5;

    // Drive physical pins
    assign LEDR = reg_ledr;
    assign HEX0 = reg_hex0;
    assign HEX1 = reg_hex1;
    assign HEX2 = reg_hex2;
    assign HEX3 = reg_hex3;
    assign HEX4 = reg_hex4;
    assign HEX5 = reg_hex5;

    // =========================================================
    // Register Write Logic
    // =========================================================
    always @(posedge clk) begin
        if (rst) begin
            reg_ledr <= 10'd0;
            reg_hex0 <= 7'h7F;  // All segments OFF (active-low)
            reg_hex1 <= 7'h7F;
            reg_hex2 <= 7'h7F;
            reg_hex3 <= 7'h7F;
            reg_hex4 <= 7'h7F;
            reg_hex5 <= 7'h7F;
        end else if (wen) begin
            case (offset)
                8'h08: reg_ledr <= wdata[9:0];
                8'h0C: reg_hex0 <= wdata[6:0];
                8'h10: reg_hex1 <= wdata[6:0];
                8'h14: reg_hex2 <= wdata[6:0];
                8'h18: reg_hex3 <= wdata[6:0];
                8'h1C: reg_hex4 <= wdata[6:0];
                8'h20: reg_hex5 <= wdata[6:0];
                default: ; // Ignore writes to read-only or undefined registers
            endcase
        end
    end

    // =========================================================
    // Register Read Logic (combinational)
    // =========================================================
    always @(*) begin
        rdata = 32'd0;
        if (cs && MemRW == READ_MODE) begin
            case (offset)
                8'h00: rdata = {28'd0, KEY};
                8'h04: rdata = {22'd0, SW};
                8'h08: rdata = {22'd0, reg_ledr};
                8'h0C: rdata = {25'd0, reg_hex0};
                8'h10: rdata = {25'd0, reg_hex1};
                8'h14: rdata = {25'd0, reg_hex2};
                8'h18: rdata = {25'd0, reg_hex3};
                8'h1C: rdata = {25'd0, reg_hex4};
                8'h20: rdata = {25'd0, reg_hex5};
                default: rdata = 32'd0;
            endcase
        end
    end

endmodule
