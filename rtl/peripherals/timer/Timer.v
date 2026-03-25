`timescale 1ns/1ps

// =========================================================
// Timer Peripheral for DE1-SoC
// MMIO Base Address: 0x2000_0000
// =========================================================
// Register Map (Offset from base):
//   0x00 : [R]    CYCLE_COUNT - Cycle Count
//   0x04 : [R/W]  CONTROL     - Control Register
//   0x08 : [R]    SNAPSHOT    - Snapshot Register
// =========================================================

module Timer (
    input         clk,
    input         rst,

    // MMIO Interface
    input         cs,          // Chip Select from Interconnect
    input  [2:0]  MemRW,       // Memory operation
    input  [31:0] addr,        // Full address (offset extracted internally)
    input  [31:0] wdata,       // Write data from Core
    output reg [31:0] rdata    // Read data to Core

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

    // Internal Registers
    reg [31:0] cycle_count;
    reg [31:0] snapshot_reg;
    reg        timer_en;

    // =========================================================
    // Internal State and Counter Logic
    // =========================================================
    always @(posedge clk) begin
        if (rst) begin
            timer_en     <= 1'b0;
            snapshot_reg <= 32'd0;
            cycle_count  <= 32'd0;
        end else begin
            // 1. Process Memory Writes
            if (wen) begin
                if (offset == 8'h04) begin
                    timer_en <= wdata[0];
                    if (wdata[2]) snapshot_reg <= cycle_count;
                end
            end

            // 2. Process Counter Updates (Override if software resets it)
            if (wen && offset == 8'h04 && wdata[1]) begin
                cycle_count <= 32'd0;
            end else if (timer_en) begin
                cycle_count <= cycle_count + 32'd1;
            end
        end
    end

    // =========================================================
    // Register Read Logic
    // =========================================================
    always @(*) begin
        rdata = 32'd0;
        if (cs && MemRW == READ_MODE) begin
            case (offset)
                8'h00:   rdata = cycle_count;
                8'h04:   rdata = {29'd0, 2'b0, timer_en}; // Only expose enable bit for now
                8'h08:   rdata = snapshot_reg;
                default: rdata = 32'd0;
            endcase
        end
    end

endmodule
