`timescale 1ns/1ps

module tb_DE1_top();

    reg clk;
    reg [3:0] KEY_r;
    reg [9:0] SW_r;
    wire [9:0] LEDR_r;

    // -----------------------------------------------------------
    // Firmware Loading
    // -----------------------------------------------------------
    //defparam uut_mac.u_imem.FIRMWARE_FILE = "/user/choi.jw/PROJECT/RISCV/RISCV_32I_MAC/machinecode/code4.txt";
    defparam     u_DE1.u_RV32.u_imem.FIRMWARE_FILE = "/user/choi.jw/PROJECT/RISCV/RISCV_32I_MAC/machinecode/v2mac.txt";
    
    // -----------------------------------------------------------
    // Design Under Test (DUT)
    // -----------------------------------------------------------
    DE1_top u_DE1(
        .CLOCK_50(clk),
        .KEY(KEY_r),
        .SW(SW_r),
        .LEDR(LEDR_r),
        .HEX0(),
        .HEX1(),
        .HEX2(),
        .HEX3(),
        .HEX4(),
        .HEX5()
    );  
/*
    RV32I_top uut(
        .clk(clk),
        .rst(rst)
    );  
*/


    // -----------------------------------------------------------
    // Clock Generation
    // -----------------------------------------------------------
    always #5 clk = ~clk;

    // -----------------------------------------------------------
    // Main Test Sequence
    // -----------------------------------------------------------
    initial begin
        clk = 1'b0;
        KEY_r[0] = 1'b0;
        KEY_r[3:1] = 3'd0;
        SW_r[9] = 1'd1;
        SW_r[8:0] = 1'd0;

        #300;
        KEY_r[0] = 1'b1;

        #4000;

        SW_r[9] = 1'd0;
    end        
        // Wait until PC reaches the end address (Fix for timeout)
        //wait(u_DE1.u_RV32.inst == 32'hDEAD_DEAD); 
    
//        #50;
//        $display("---------------------------------------------------");
//        $display(" [SUCCESS] Simulation Finished Cleanly.");
//        $display(" Both models matched perfectly.");
//        $display(" Final PC: %h", uut_mac.pc);
//        $display("---------------------------------------------------");
//        $finish;
//    end 
    
    // -----------------------------------------------------------
    // Automatic Verification (Self-Checking)
    // -----------------------------------------------------------


/*    
    always @(negedge clk) begin
        if (rst == 1'b0) begin 
            
            // 1. Compare PC
            if (uut.pc !== uut_mac.pc) begin
                $display("\n[ERROR] PC Mismatch at time %0t", $time);
                $display("Expected (Ref): %h", uut.pc);
                $display("Actual   (MAC): %h", uut_mac.pc);
                $finish; 
            end

            // 2. Compare Register File (x0 ~ x31)
            for (i = 0; i < 32; i = i + 1) begin
                if (uut.u_reg.reg32[i] !== uut_mac.u_reg.reg32[i]) begin
                    $display("\n[ERROR] Register x%0d Mismatch at time %0t", i, $time);
                    $display("PC Location   : %h", uut.pc);
                    $display("Expected (Ref): %h", uut.u_reg.reg32[i]);
                    $display("Actual   (MAC): %h", uut_mac.u_reg.reg32[i]);
                    $finish;
                end
            end
        end
    end
*/


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
