`timescale 1ns / 1ps

module tb_MAC();

    reg         clk;
    reg         rst;
    reg  [31:0] DataA; 
    reg  [31:0] DataB;
    reg  [31:0] inst;
    
    wire        mac_on;
    wire        pc_en; 
    wire        wb_sel_mac; 
    wire        addr_sel_mac; 
    wire        reg_wen_mac;
    wire [31:0] mac_WB;
    wire [4:0]  mac_rd;

    // DUT: Optimized 2-cycle MAC
    MAC2_top uut(
        .clk(clk),
        .rst(rst),
        .DataA(DataA),
        .DataB(DataB),
        .inst(inst),
        .mac_on(mac_on),
        .pc_en(pc_en),
        .wb_sel_mac(wb_sel_mac),
        .addr_sel_mac(addr_sel_mac),
        .reg_wen_mac(reg_wen_mac),
        .mac_WB(mac_WB),
        .mac_rd(mac_rd)
    );

    // Clock Generation
    always #5 clk = ~clk;

    // -----------------------------------------------------------
    // Tasks ported from tb_System_Top_CRT
    // -----------------------------------------------------------
    
    task gen_MAC_type;
        input [4:0] rs1;
        input [4:0] rs2;
        input [4:0] rd;
        output [31:0] inst_out;
        begin
            // Opcode is 7'b0001011 (OPCODE_MAC)
            inst_out = {7'b0000000, rs2, rs1, 3'b000, rd, 7'b0001011};
        end
    endtask

    integer test_count;
    integer fail_count;

    task test_V2MAC;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rs2, rd;
        reg [31:0] vA, vB, vC;
        reg [31:0] inst_val;
        reg [15:0] mul_a_high, mul_a_low, mul_b_high, mul_b_low;
        reg signed [31:0] expected_mult_high, expected_mult_low;
        reg [31:0] expected_val;
        begin
            $display("\n=================================================");
            $display("-> Running %0d iterations for V2MAC Unit Test...", num_iters);
            $display("=================================================");
            
            for (i=0; i<num_iters; i=i+1) begin
                // 1. Prepare random operands and instruction
                rs1 = $urandom_range(1, 31);
                rs2 = $urandom_range(1, 31);
                rd  = $urandom_range(1, 31);
                
                vA = $urandom;
                vB = $urandom;
                vC = $urandom; // rd initial value (accumulate base)
                
                gen_MAC_type(rs1, rs2, rd, inst_val);
                
                // 2. Cycle 1: Start Detection & Latch RS
                @(negedge clk);
                inst  = inst_val;
                DataA = vA;
                DataB = vB;
                
                // 3. Cycle 2: Fetch RD from RegFile & WB
                @(negedge clk);
                DataA = vC; // Simulated RD value coming in via addr_sel_mac hijacking
                
                // --- Golden Model Calculation (from tb_System_Top_CRT logic) ---
                mul_a_high = vA[31:16]; mul_a_low = vA[15:0];
                mul_b_high = vB[31:16]; mul_b_low = vB[15:0];
                expected_mult_high = $signed(mul_a_high) * $signed(mul_b_high);
                expected_mult_low  = $signed(mul_a_low)  * $signed(mul_b_low);
                expected_val = (rd == 0) ? 32'b0 : (expected_mult_high + expected_mult_low + vC);
                
                // 4. Verify Output before the next state transition
                #1; // Wait for combinational logic to settle
                if (mac_WB !== expected_val) begin
                    $display("[FAIL] V2MAC | Expected: %h | Actual: %h", expected_val, mac_WB);
                    fail_count = fail_count + 1;
                end else begin
                    $display("[PASS] V2MAC | (%h * %h) + (%h * %h) + %h = %h", 
                              mul_a_high, mul_b_high, mul_a_low, mul_b_low, vC, mac_WB);
                end
                
                test_count = test_count + 1;
                
                // Complete 2-Cycle then back to Idle
                @(negedge clk);
                inst = 32'b0;
            end
        end
    endtask

    // -----------------------------------------------------------
    // Main Test Sequence
    // -----------------------------------------------------------
    initial begin
        // Initialize
        clk = 0;
        rst = 1;
        DataA = 0;
        DataB = 0;
        inst = 0;
        test_count = 0;
        fail_count = 0;
        
        #20;
        rst = 0;
        @(negedge clk);
        
        test_V2MAC(20);
        
        $display("\n=================================================");
        $display("   Unit Test Completed");
        $display("   Total Tests Run : %0d", test_count);
        $display("   Total Failures  : %0d", fail_count);
        if (fail_count == 0)
            $display("   Status: >> ALL TESTS PASSED <<");
        else
            $display("   Status: >> SOME TESTS FAILED <<");
        $display("=================================================\n");
        
        $finish;
    end

    // Waveform setup
    initial begin 
        $shm_open("wave.shm");
        $shm_probe("ACMTF");
    end

endmodule
