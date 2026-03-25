`timescale 1ns/1ps

module System_add_tb();

    reg clk;
    reg rst;
    
    // Other System_Top ports
    wire [31:0] core_result;
    wire pc_stall;
    reg  [3:0]  KEY;
    reg  [9:0]  SW;
    
    wire [9:0] LEDR;
    wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;

    // Declarations for probe wires
    wire [9:0] probe_led;
    wire [6:0] probe_hex0, probe_hex1, probe_hex2, probe_hex3, probe_hex4, probe_hex5;
    wire [31:0] probe_timer;

    // Declarations for VMEM probe wires
    wire [11:0] probe_vmem_addr;
    wire [7:0]  probe_vmem_wdata;
    wire        probe_vmem_we;

    // Use instance name 'uut' for hierarchical paths
    assign probe_led  = uut.u_gpio.reg_ledr;
    assign probe_hex0 = uut.u_gpio.reg_hex0;
    assign probe_hex1 = uut.u_gpio.reg_hex1;
    assign probe_hex2 = uut.u_gpio.reg_hex2;
    assign probe_hex3 = uut.u_gpio.reg_hex3;
    assign probe_hex4 = uut.u_gpio.reg_hex4;
    assign probe_hex5 = uut.u_gpio.reg_hex5;
    
    assign probe_timer = uut.u_timer.cycle_count;

    // Probing VMEM Write Port A
    assign probe_vmem_addr  = uut.u_vga.u_vmem.addr_a;
    assign probe_vmem_wdata = uut.u_vga.u_vmem.din_a;
    assign probe_vmem_we    = uut.u_vga.u_vmem.we_a;

    // Instantiate System_Top with 'add.hex'
    System_Top #(
        .FIRMWARE_FILE("../../software/C_code/files/add/add.hex")
    ) uut (
        .clk(clk),
        .rst(rst),
        .core_result(core_result),
        .pc_stall(pc_stall),
        .KEY(KEY),
        .SW(SW),
        .LEDR(LEDR),
        .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2), .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5),
        .VGA_R(), .VGA_G(), .VGA_B(), .VGA_HS(), .VGA_VS(), 
        .VGA_CLK(), .VGA_BLANK_N(), .VGA_SYNC_N(),
        .UART_RXD(1'b1), // Idle high
        .UART_TXD()
    );

    // Clock Generation (50MHz => 20ns period)
    initial clk = 0;
    always #10 clk = ~clk;

    // Monitor VMEM Writes
    always @(posedge clk) begin
        if (probe_vmem_we && rst == 0) begin
            // We ignore writes of ' ' (space) to reduce console spam, UNLESS it's rewriting.
            if (probe_vmem_wdata != 8'h20) begin
                integer v_row, v_col;
                v_row = probe_vmem_addr / 80;
                v_col = probe_vmem_addr % 80;
                $display("[%0t] VMEM WRITE: Addr=(Row %0d, Col %0d), Data=0x%02h ('%c')", 
                         $time, v_row, v_col, probe_vmem_wdata, probe_vmem_wdata);
            end
        end
    end

    // Test Sequence
    initial begin
        // Waveform Dumping
        $dumpfile("System_add_tb.vcd");
        $dumpvars(0, System_add_tb);

        // Initialize signals
        rst = 1;
        KEY = 4'hF; // All keys unpressed (Active Low)
        SW = 10'd0;
        
        repeat (10) @(posedge clk);
        rst = 0;
        $display("[%0t] System Reset Released. RISC-V is now running add firmware (Convolution Profiler)...", $time);

        // 1. Give firmware time to boot, clear 4096 bytes of VGA (takes ~150,000 cycles)
        $display("[%0t] Waiting for VGA init...", $time);
        repeat (100000) @(posedge clk);
        $display("[%0t] VGA init done. Boot UI should be printed.", $time);

        // 2. Change SW to set X[0] = 5. (SW[7:4] = 5  ->  SW = 0x050)
        $display("\n[%0t] ---------- Setting SW[7:4] = 5 ----------", $time);
        SW = 10'h050; // SW[7:4] = 5
        repeat (100000) @(posedge clk);

        // 3. Test KEY[1] (Standard Convolution)
        $display("\n[%0t] ---------- Pressing KEY[1] (Standard Convolution) ----------", $time);
        KEY[1] = 0; // Press KEY1 (Active Low)
        // Wait until last Y element is written to VMEM (Row 5, Col 53 = addr 0x1C5)
        wait(probe_vmem_we && probe_vmem_addr == 12'h1C5);
        @(posedge clk);
        $display("[%0t] Standard Conv output complete. Releasing KEY[1]...", $time);
        KEY[1] = 1; // Release
        repeat (100) @(posedge clk); // Small settling time

        // 4. Test KEY[2] (V2MAC Convolution)
        $display("\n[%0t] ---------- Pressing KEY[2] (V2MAC Convolution) ----------", $time);
        KEY[2] = 0; // Press KEY2 (Active Low)
        // Wait until last Y element is written to VMEM (Row 5, Col 53 = addr 0x1C5)
        wait(probe_vmem_we && probe_vmem_addr == 12'h1C5);
        @(posedge clk);
        $display("[%0t] V2MAC Conv output complete. Releasing KEY[2]...", $time);
        KEY[2] = 1; // Release
        repeat (100) @(posedge clk); // Small settling time

        $display("\n[%0t] Simulation Finished.", $time);

        
        $finish;
    end

    initial begin
        // Waveform Dumping
        $shm_open("wave.shm");
        $shm_probe("ACMTF");
    end 

endmodule
