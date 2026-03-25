`timescale 1ns/1ps

module UART_tx(

    input clk,
    input rst,
    input [7:0] tx_data,
    input tx_start,
    
    output reg tx_serial,
    output reg tx_ready
);

    parameter CLOCK_FREQ = 50_000_000;
    parameter BAUD_RATE  = 115_200;

    localparam CLOCK_COUNT = CLOCK_FREQ / BAUD_RATE;

    localparam s_IDLE = 1'd0;
    localparam s_BUSY = 1'd1;

    reg [8:0] tx_shift_reg;
    reg       tx_state;
    reg [8:0] tx_clock_count;
    reg [3:0] tx_bit_count;


    always @ (posedge clk) begin
        
        if (rst) begin
           tx_serial      <= 1'b1;
           tx_ready       <= 1'b1;
           tx_state       <= s_IDLE;
           tx_shift_reg   <= 9'd0;
           tx_bit_count   <= 4'd0;
           tx_clock_count <= 9'd0;
        end
        else begin
            case (tx_state) 
                s_IDLE: begin
                    if (tx_start == 1'b1) begin
                        tx_state     <= s_BUSY;
                        tx_ready     <= 1'b0;
                        tx_shift_reg <= {1'b1, tx_data}; 
                        tx_serial    <= 1'b0;
                    end
                    else begin
                        tx_ready <= 1'b1;
                    end
                end
                s_BUSY: begin
                    if (tx_clock_count == CLOCK_COUNT - 1) begin
                        if (tx_bit_count == 4'd9) begin 
                            tx_state       <= s_IDLE;
                            tx_ready       <= 1'b1;
                            tx_bit_count   <= 4'd0;
                            tx_clock_count <= 9'd0;
                        end
                        else begin
                            tx_serial      <= tx_shift_reg[tx_bit_count];
                            tx_bit_count   <= tx_bit_count + 1;
                            tx_clock_count <= 9'd0;
                        end
                    end
                    else 
                        tx_clock_count <= tx_clock_count + 1;
                end
            endcase
        end

    end


endmodule

