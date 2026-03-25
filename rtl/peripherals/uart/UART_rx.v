`timescale 1ns/1ps

module UART_rx(
    input clk,
    input rst,
    
    input        rx_serial,

    output reg       rx_valid,
    output reg [7:0] rx_data
);

    parameter CLOCK_FREQ = 50_000_000;
    parameter BAUD_RATE  = 115_200;

    localparam CLOCK_COUNT = CLOCK_FREQ / BAUD_RATE;
    localparam HALF_COUNT  = CLOCK_COUNT / 2;

    localparam s_IDLE = 2'd0;
    localparam s_TEST = 2'd1;
    localparam s_BUSY = 2'd2;
    localparam s_STOP = 2'd3;

    reg [1:0]  rx_state;
    reg [15:0] rx_clock_count;
    reg [3:0]  rx_bit_count;
    reg [7:0]  rx_shift_reg;

    always @ (posedge clk) begin
        if (rst) begin
            rx_state       <= s_IDLE;
            rx_clock_count <= 16'd0;
            rx_bit_count   <= 4'd0;
            rx_shift_reg   <= 8'd0;
            rx_data        <= 8'd0;
            rx_valid       <= 1'b0;
        end
        else begin
            case (rx_state) 
                s_IDLE: begin
                    rx_valid       <= 1'b0;
                    rx_clock_count <= 16'd0;
                    rx_bit_count   <= 4'd0;
                    if (rx_serial == 1'b0)  
                        rx_state <= s_TEST;
                end

                s_TEST: begin
                    if (rx_clock_count == HALF_COUNT - 1) begin
                        rx_clock_count <= 16'd0;
                        if (rx_serial == 1'b0) 
                            rx_state <= s_BUSY;
                        else 
                            rx_state <= s_IDLE;
                    end
                    else 
                        rx_clock_count <= rx_clock_count + 1;
                end

                s_BUSY: begin
                    if (rx_clock_count == CLOCK_COUNT - 1) begin
                        rx_clock_count <= 16'd0;
                        rx_shift_reg[rx_bit_count] <= rx_serial;
                        
                        if (rx_bit_count == 4'd7) begin 
                            rx_state <= s_STOP;
                        end
                        else begin
                            rx_bit_count <= rx_bit_count + 1;
                        end
                    end
                    else 
                        rx_clock_count <= rx_clock_count + 1;
                end

                s_STOP: begin
                    if (rx_clock_count == CLOCK_COUNT - 1) begin
                        rx_clock_count <= 16'd0;
                        rx_data  <= rx_shift_reg;
                        rx_valid <= 1'b1; 
                        rx_state <= s_IDLE;
                    end
                    else 
                        rx_clock_count <= rx_clock_count + 1;
                end

                default: rx_state <= s_IDLE;
            endcase
        end
    end

endmodule
