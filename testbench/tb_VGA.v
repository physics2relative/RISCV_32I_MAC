`timescale 1ns/1ps

module tb_System_Top_C();

    reg clk, rst;
    wire [31:0] core_result;
    wire pc_stall;

    // -----------------------------------------------------------
    // Design Under Test (DUT)
    // -----------------------------------------------------------
    System_Top uut(
        .clk(clk),
        .rst(rst),
        .core_result(core_result),
        .pc_stall(pc_stall)
    );

    // -----------------------------------------------------------
    // Clock Generation
    // -----------------------------------------------------------
    always #5 clk = ~clk;

    // -----------------------------------------------------------
    // Internal Probes (For Waveform / Debug)
    // -----------------------------------------------------------
    wire [31:0] probe_x31;
    assign probe_x31 = uut.u_core.u_datapath.u_reg.reg32[31];

    // -----------------------------------------------------------
    // Main Executive Block (C Program Verification)
    // -----------------------------------------------------------
    initial begin
        // Initialize Signals
        clk = 0;
        rst = 1;

        // 1. Load Compiled C Program (add.hex or add.bin depending on support)
        // Memory needs to be initialized. Assuming $readmemh reads words into memory array
        // NOTE: Adjust the path to your generated .hex file as needed
        $display("=================================================");
        $display("   Loading Compiled C Code (.hex) into IMEM...   ");
        $display("=================================================");
        
        $readmemh("/user/choi.jw/PROJECT/RISCV/RISCV_32I_MAC_2/software/C_code/files/add.hex", uut.u_imem.imem);

        // 2. Release Reset
        #15;
        rst = 0;
        
        $display("   Core Started. Running 'add.c'...");

        // 3. Wait for Simulation to complete (trigger on DEADDEAD)
        wait (pc_stall == 1'b1);
        
        // Let it settle for a couple of cycles
        @(negedge clk);
        @(negedge clk);

        // 4. Verify Result
        $display("=================================================");
        $display("   Simulation Halted successfully.");
        $display("   Checking Result in Register x31");
        
        // In add.c: a = b + c = 10 + 5 = 15 (0x0000000F)
        if (probe_x31 === 32'd15) begin
            $display("   [SUCCESS] Computed Result: %0d", probe_x31);
            $display("   Status: >> C PROGRAM TEST PASSED <<\n");
        end else begin
            $display("   [FAIL] Computed Result: %0d (Expected: 15)", probe_x31);
            $display("   Status: >> C PROGRAM TEST FAILED <<\n");
        end
        $display("=================================================");
        
        $finish;
    end

    // -----------------------------------------------------------
    // SimVision Dumping
    // -----------------------------------------------------------
    initial begin
        $shm_open("wave_c.shm");
        $shm_probe(tb_System_Top_C, "ACMTF"); 
    end

endmodule
