`timescale 1ns/1ps

/*
 * System_UART_tb.v
 * System-level testbench for RISC-V UART MMIO.
 * 
 * This testbench runs the 'uart_test.c' firmware on the RISC-V core.
 * 1. Monitors UART_TXD to see if 'A' is sent.
 * 2. Sends 'B' through UART_RXD.
 * 3. Verifies if CPU echoes back 'B' via UART_TXD.
 */

module System_UART_tb();

    reg clk;
    reg rst;
    
    // Physical UART Pins
    reg  UART_RXD;
    wire UART_TXD;
    
    // Other System_Top ports
    wire [31:0] core_result;
    wire pc_stall;
    reg  [3:0]  KEY;
    reg  [9:0]  SW;
    
    // UART Timing: 50MHz / 115,200 = 434 cycles
    localparam BAUD_CLK = 434;

    // Instantiate System_Top with UART test firmware
    // Note: User must compile uart_test.c to uart_test.hex before running this!
    System_Top #(
        .FIRMWARE_FILE("../../software/C_code/files/uart_test/uart_test.hex")
    ) uut (
        .clk(clk),
        .rst(rst),
        .core_result(core_result),
        .pc_stall(pc_stall),
        .KEY(KEY),
        .SW(SW),
        .LEDR(),
        .HEX0(), .HEX1(), .HEX2(), .HEX3(), .HEX4(), .HEX5(),
        .VGA_R(), .VGA_G(), .VGA_B(), .VGA_HS(), .VGA_VS(), 
        .VGA_CLK(), .VGA_BLANK_N(), .VGA_SYNC_N(),
        .UART_RXD(UART_RXD),
        .UART_TXD(UART_TXD)
    );

    // Clock Generation (50MHz)
    initial clk = 0;
    always #10 clk = ~clk;

    // Task to send a byte TO the CPU (Simulating external device)
    task send_to_cpu(input [7:0] data);
        integer i;
        begin
            UART_RXD = 0; // Start Bit
            repeat (BAUD_CLK) @(posedge clk);
            for (i=0; i<8; i=i+1) begin
                UART_RXD = data[i];
                repeat (BAUD_CLK) @(posedge clk);
            end
            UART_RXD = 1; // Stop Bit
            repeat (BAUD_CLK) @(posedge clk);
        end
    endtask

    // Monitoring logic for UART_TXD
    // Automatically decodes and prints characters sent by the CPU
    reg [7:0] latest_rx_char;
    reg       latest_rx_valid;
    initial begin
        reg [7:0] char;
        integer j;
        latest_rx_valid = 0;
        forever begin
            @(negedge UART_TXD); // Start bit detect
            repeat (BAUD_CLK + BAUD_CLK/2) @(posedge clk); // Align to center of Bit 0
            
            char = 0;
            for (j=0; j<8; j=j+1) begin
                char[j] = UART_TXD;
                repeat (BAUD_CLK) @(posedge clk);
            end
            $display("[SYSTEM UART TX]: Character = %c (0x%h)", char, char);
            latest_rx_char = char;
            latest_rx_valid = 1;
            @(posedge clk);
            latest_rx_valid = 0;
        end
    end

    // Task to verify character received from CPU
    task wait_cpu_tx(input [7:0] expected_data);
        begin
            @(posedge latest_rx_valid);
            if (latest_rx_char !== expected_data) begin
                $display("ERROR: Expected '%c' (0x%h), got '%c' (0x%h)", expected_data, expected_data, latest_rx_char, latest_rx_char);
                $finish;
            end else begin
                $display("SUCCESS: CPU sent '%c'", expected_data);
            end
        end
    endtask

    // Test Sequence
    initial begin
        // Waveform Dumping
        $shm_open("wave.shm");
        $shm_probe("ACMTF");

        // Initialize signals
        rst = 1;
        UART_RXD = 1; // Idle high
        KEY = 4'hF;
        SW = 10'h000;
        
        repeat (10) @(posedge clk);
        rst = 0;
        $display("System Reset Released. RISC-V is now running uart_test firmware...");

        // Wait for CPU to send 'A' (indication that it's ready)
        // (Monitoring block will print this)
        $display("Wait for initialization character 'A'...");
        wait_cpu_tx("A");
        
        repeat (BAUD_CLK * 20) @(posedge clk); // Wait for some time

        // Send character 'S' to CPU and see if it echoes back
        $display("Testbench: Sending character 'S' to RISC-V...");
        send_to_cpu("S");
        wait_cpu_tx("S");
        
        // Wait for CPU to process and echo
        repeat (BAUD_CLK * 20) @(posedge clk);

        // Send character '!' to CPU
        $display("Testbench: Sending character '!' to RISC-V...");
        send_to_cpu("!");
        wait_cpu_tx("!");

        repeat (BAUD_CLK * 50) @(posedge clk);
        
        $display("System UART Simulation Finished.");
        $finish;
    end

endmodule
