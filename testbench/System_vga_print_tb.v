`timescale 1ns/1ps

module System_vga_print_tb();

    reg clk;
    reg rst;
    
    // System_Top ports
    wire [31:0] core_result;
    wire pc_stall;
    reg  [3:0]  KEY;
    reg  [9:0]  SW;
    
    wire [9:0] LEDR;
    wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;

    // Declarations for probe wires
    wire [11:0] probe_vmem_addr;
    wire [7:0]  probe_vmem_wdata;
    wire        probe_vmem_we;
    
    // Probing VMEM Write Port A
    assign probe_vmem_addr  = uut.u_vga.u_vmem.addr_a;
    assign probe_vmem_wdata = uut.u_vga.u_vmem.din_a;
    assign probe_vmem_we    = uut.u_vga.u_vmem.we_a;

    // Instantiate System_Top with 'vga_print.hex'
    System_Top #(
        .FIRMWARE_FILE("../../software/C_code/files/vga_print/vga_print.hex")
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
            $display("[%0t] VMEM WRITE: Addr=0x%03h, Data=0x%02h ('%c')", 
                     $time, probe_vmem_addr, probe_vmem_wdata, probe_vmem_wdata);
        end
    end

    // Test Sequence
    initial begin
        // Waveform Dumping
        $dumpfile("System_vga_print_tb.vcd");
        $dumpvars(0, System_vga_print_tb);

        // Initialize signals
        rst = 1;
        KEY = 4'hF; // All keys unpressed (Active Low)
        SW = 10'd0;
        
        repeat (10) @(posedge clk);
        rst = 0;
        $display("[%0t] System Reset Released. RISC-V is booting vga_print firmware...", $time);

        // Give firmware time to boot and execute vga_print_safe()
        // It writes to offset = 2 * 80 + 5 = 165 (0x0A5)
        repeat (1000) @(posedge clk);
        
        $display("\n[%0t] Simulation Finished.", $time);
        $finish;
    end

endmodule
