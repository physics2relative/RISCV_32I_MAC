`timescale 1ns/1ps

/*
 * UART MMIO Wrapper
 * Base Address: 0x3000_0000 (Suggested)
 *
 * Register Map:
 * Offset 0x00: DATA (R/W)
 *              - Read: Returns received 8-bit data, clears rx_valid flag.
 *              - Write: Sends 8-bit data to UART TX.
 * Offset 0x04: STATUS (R)
 *              - Bit 0: tx_ready (1 = OK to send)
 *              - Bit 1: rx_valid (1 = Data received and waiting)
 */

module UART_MMIO (
    input         clk,
    input         rst,

    // MMIO Interface
    input         cs,          // Chip Select from Interconnect
    input  [2:0]  MemRW,       // Memory operation (Read/Write)
    input  [31:0] addr,        // Byte address
    input  [31:0] wdata,       // Write data from Core
    output reg [31:0] rdata,   // Read data to Core

    // UART Physical Interface
    input         rx_serial,
    output        tx_serial
);

    // MemRW encodings
    localparam WRITE_BYTE = 3'd0;
    localparam WRITE_HALF = 3'd1;
    localparam WRITE_WORD = 3'd2;
    localparam READ_MODE  = 3'd3;

    // Address Decoding
    wire [7:0] offset = addr[7:0];
    wire wen = cs & (MemRW == WRITE_BYTE || MemRW == WRITE_HALF || MemRW == WRITE_WORD);
    wire ren = cs & (MemRW == READ_MODE);

    // Internal UART signals
    wire [7:0] rx_byte;
    wire       rx_done_pulse;
    wire       tx_ready;
    reg        tx_start;
    reg  [7:0] tx_byte;

    // Status Flags
    reg        status_rx_valid;

    // Instantiate UART TX
    UART_tx u_tx (
        .clk(clk),
        .rst(rst),
        .tx_data(tx_byte),
        .tx_start(tx_start),
        .tx_serial(tx_serial),
        .tx_ready(tx_ready)
    );

    // Instantiate UART RX
    UART_rx u_rx (
        .clk(clk),
        .rst(rst),
        .rx_serial(rx_serial),
        .rx_data(rx_byte),
        .rx_valid(rx_done_pulse)
    );

    // Write Logic
    always @(posedge clk) begin
        if (rst) begin
            tx_start <= 1'b0;
            tx_byte  <= 8'd0;
        end
        else begin
            tx_start <= 1'b0; // Pulse for 1 cycle
            if (wen && offset == 8'h00) begin
                tx_byte  <= wdata[7:0];
                tx_start <= 1'b1;
            end
        end
    end

    // RX Valid Flag Management
    always @(posedge clk) begin
        if (rst) begin
            status_rx_valid <= 1'b0;
        end
        else begin
            if (rx_done_pulse)
                status_rx_valid <= 1'b1;
            else if (ren && offset == 8'h00)
                status_rx_valid <= 1'b0; // Clear on read
        end
    end

    // Read Logic
    always @(*) begin
        if (cs && ren) begin
            case (offset)
                8'h00:   rdata = {24'd0, rx_byte};
                8'h04:   rdata = {30'd0, status_rx_valid, tx_ready};
                default: rdata = 32'd0;
            endcase
        end
        else begin
            rdata = 32'd0;
        end
    end

endmodule
