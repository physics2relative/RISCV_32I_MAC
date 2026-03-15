`timescale 1ns/1ps

module tb_System_Top();

    reg clk, rst;
    wire [31:0] result;
    wire pc_stall;
    
    // MAC interface controls (stubbed for now or tied to basic values)
    reg override_en;
    reg pc_en;
    reg wb_sel_mac;
    reg addr_sel_mac;
    reg [31:0] mac_WB;
    reg reg_wen_mac;

    // -----------------------------------------------------------
    // Firmware Loading
    // -----------------------------------------------------------
    // Using a known good firmware file for RISCV_32I_MAC test
    defparam uut.u_imem.FIRMWARE_FILE = "/user/choi.jw/PROJECT/RISCV/RISCV_32I_MAC/machinecode/v2mac.txt";

    // -----------------------------------------------------------
    // Design Under Test (DUT)
    // -----------------------------------------------------------
    System_Top uut(
        .clk(clk),
        .rst(rst),
        .override_en(override_en),
        .pc_en(pc_en),
        .wb_sel_mac(wb_sel_mac),
        .addr_sel_mac(addr_sel_mac),
        .mac_WB(mac_WB),
        .reg_wen_mac(reg_wen_mac),
        .core_result(result),
        .pc_stall(pc_stall)
    );  

    // -----------------------------------------------------------
    // Clock Generation
    // -----------------------------------------------------------
    always #5 clk = ~clk;

    // -----------------------------------------------------------
    // Main Test Sequence
    // -----------------------------------------------------------
    initial begin
        clk = 1'b0;
        rst = 1'b1; 
        
        // MAC stubs
        override_en = 1'b0;
        pc_en = 1'b1; // PC runs normally
        wb_sel_mac = 1'b0;
        addr_sel_mac = 1'b0;
        mac_WB = 32'b0;
        reg_wen_mac = 1'b0;

        #10;
        rst = 1'b0; 
        
        // Wait until PC stalls (DEAD_DEAD)
        wait(pc_stall == 1'b1); 
    
        #50;
        $display("---------------------------------------------------");
        $display(" [SUCCESS] System_Top Simulation Finished Cleanly.");
        $display(" Final PC: %h", uut.u_core.imem_addr);
        $display("---------------------------------------------------");
        $finish;
    end 
    
    // -----------------------------------------------------------
    // Timeout Watchdog
    // -----------------------------------------------------------
    initial begin
        #100000; 
        $display("\n[TIMEOUT] Simulation ran too long without finishing.");
        $finish;
    end 

    // -----------------------------------------------------------
    // Waveform Dump
    // -----------------------------------------------------------
    initial begin 
        $shm_open("wave.shm");
        $shm_probe("ACMTF");
    end 

endmodule
