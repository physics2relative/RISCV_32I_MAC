`timescale 1ns/1ps

module tb_System_Top_VGA();

    // -----------------------------------------------------------
    // DUT Signals
    // -----------------------------------------------------------
    reg clk, rst;
    wire [31:0] core_result;
    wire pc_stall;

    // VGA output wires (not verified directly, just tied)
    wire [7:0] VGA_R, VGA_G, VGA_B;
    wire VGA_HS, VGA_VS, VGA_CLK, VGA_BLANK_N, VGA_SYNC_N;

    // -----------------------------------------------------------
    // Design Under Test (DUT)
    // -----------------------------------------------------------
    System_Top uut(
        .clk         (clk),
        .rst         (rst),
        .core_result (core_result),
        .pc_stall    (pc_stall),
        .VGA_R       (VGA_R),
        .VGA_G       (VGA_G),
        .VGA_B       (VGA_B),
        .VGA_HS      (VGA_HS),
        .VGA_VS      (VGA_VS),
        .VGA_CLK     (VGA_CLK),
        .VGA_BLANK_N (VGA_BLANK_N),
        .VGA_SYNC_N  (VGA_SYNC_N)
    );

    // -----------------------------------------------------------
    // Clock Generation (50MHz)
    // -----------------------------------------------------------
    always #10 clk = ~clk; // 50MHz (period = 20ns)

    // -----------------------------------------------------------
    // Internal Probes
    // -----------------------------------------------------------
    // Probe x31 to check how many chars were written
    wire [31:0] probe_x31;
    assign probe_x31 = uut.u_core.u_datapath.u_reg.reg32[31];

    // Direct access to VMEM bram inside VGA_Subsystem
    // Hierarchy: uut.u_vga.u_vmem.vram[N]
    
    // Expected values from add.c
    localparam EXPECTED_VAL = 1; // x31 = 1 means success
    
    integer k;
    integer error_count;

    // Helper task to check a single VMEM character
    task check_char;
        input integer col;
        input integer row;
        input [7:0] expected_char;
        integer addr;
        begin
            addr = (row * 80) + col;
            if (uut.u_vga.u_vmem.vram[addr] === expected_char) begin
                $display("  [%3d,%2d] | 0x%02x ('%s') | 0x%02x ('%s') | PASS",
                    col, row,
                    expected_char, expected_char,
                    uut.u_vga.u_vmem.vram[addr], uut.u_vga.u_vmem.vram[addr]);
            end else begin
                $display("  [%3d,%2d] | 0x%02x ('%s') | 0x%02x ('%s') | FAIL <---",
                    col, row,
                    expected_char, expected_char,
                    uut.u_vga.u_vmem.vram[addr], uut.u_vga.u_vmem.vram[addr]);
                error_count = error_count + 1;
            end
        end
    endtask

    // -----------------------------------------------------------
    // Main Test Block
    // -----------------------------------------------------------
    initial begin
        // Initialize
        clk = 0;
        rst = 1;
        error_count = 0;

        $display("=================================================");
        $display("   tb_System_Top_VGA: VMEM Write Verification   ");
        $display("=================================================");

        // Load compiled VGA test C hex into IMEM
        $readmemh("/user/choi.jw/PROJECT/RISCV/RISCV_32I_MAC_3/software/C_code/files/add.hex",
                  uut.u_imem.imem);
        $display("[Info] add.hex loaded into IMEM.");

        // Release Reset after 3 clock edges
        #25; rst = 0;
        $display("[Info] Reset released. Core is running...");

        // Wait for the DEADDEAD trap (pc_stall goes HIGH)
        wait (pc_stall == 1'b1);

        // Let VMEM settle for a few more cycles
        repeat(10) @(negedge clk);

        // -----------------------------------------------------------
        // Step 1: Check x31 completion flag
        // -----------------------------------------------------------
        $display("-------------------------------------------------");
        $display("[Check] x31 = %0d (expected: %0d)",
                  probe_x31, EXPECTED_VAL);
        if (probe_x31 !== EXPECTED_VAL) begin
            $display("[WARN] x31 mismatch! Got %0d, expected %0d",
                      probe_x31, EXPECTED_VAL);
            error_count = error_count + 1;
        end

        // -----------------------------------------------------------
        // Step 2: Read VMEM and compare specific coordinates
        // -----------------------------------------------------------
        $display("-------------------------------------------------");
        $display("[Check] Verifying VMEM content:");
        $display("  [Col,Row]| Expected | Got      | Result");
        $display("  ---------|----------|----------|-------");

        // Row 0: "HELLO VGA! V2MAC TEST"
        check_char( 0, 0, "H");
        check_char( 1, 0, "E");
        check_char( 2, 0, "L");
        check_char( 3, 0, "L");
        check_char( 4, 0, "O");
        check_char( 5, 0, " ");
        check_char( 6, 0, "V");
        check_char( 7, 0, "G");
        check_char( 8, 0, "A");
        check_char( 9, 0, "!");
        check_char(10, 0, " ");
        check_char(11, 0, "V");
        check_char(12, 0, "2");
        check_char(13, 0, "M");
        check_char(14, 0, "A");
        check_char(15, 0, "C");
        check_char(16, 0, " ");
        check_char(17, 0, "T");
        check_char(18, 0, "E");
        check_char(19, 0, "S");
        check_char(20, 0, "T");

        // Row 1: "[3,4].[3,4]=25"
        check_char( 0, 1, "[");
        check_char( 1, 1, "3");
        check_char( 2, 1, ",");
        check_char( 3, 1, "4");
        check_char( 4, 1, "]");
        check_char( 5, 1, ".");
        check_char( 6, 1, "[");
        check_char( 7, 1, "3");
        check_char( 8, 1, ",");
        check_char( 9, 1, "4");
        check_char(10, 1, "]");
        check_char(11, 1, "=");
        check_char(12, 1, "2");
        check_char(13, 1, "5");

        // Row 2: "[1-4].[1-4]=30"
        check_char( 0, 2, "[");
        check_char( 1, 2, "1");
        check_char( 2, 2, "-");
        check_char( 3, 2, "4");
        check_char( 4, 2, "]");
        check_char( 5, 2, ".");
        check_char( 6, 2, "[");
        check_char( 7, 2, "1");
        check_char( 8, 2, "-");
        check_char( 9, 2, "4");
        check_char(10, 2, "]");
        check_char(11, 2, "=");
        check_char(12, 2, "3");
        check_char(13, 2, "0");

        // Row 3: "ACC=32"
        check_char( 0, 3, "A");
        check_char( 1, 3, "C");
        check_char( 2, 3, "C");
        check_char( 3, 3, "=");
        check_char( 4, 3, "3");
        check_char( 5, 3, "2");

        // -----------------------------------------------------------
        // Final Result
        // -----------------------------------------------------------
        $display("-------------------------------------------------");
        if (error_count == 0) begin
            $display("  Status: >> VGA VMEM TEST PASSED (0 errors) <<");
        end else begin
            $display("  Status: >> VGA VMEM TEST FAILED (%0d errors) <<", error_count);
        end
        $display("=================================================");

        $finish;
    end

    // -----------------------------------------------------------
    // SimVision Waveform Dumping
    // -----------------------------------------------------------
    initial begin
        $shm_open("wave_vga.shm");
        $shm_probe(tb_System_Top_VGA, "ACMTF");
    end

    // -----------------------------------------------------------
    // Timeout Guard (avoid infinite simulation)
    // -----------------------------------------------------------
    initial begin
        #10_000_000;
        $display("[FAIL] Simulation Timeout - 10ms reached.");
        $finish;
    end

endmodule