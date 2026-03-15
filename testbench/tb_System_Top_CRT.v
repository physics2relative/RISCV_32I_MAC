`timescale 1ns/1ps

module tb_System_Top_CRT();

    reg clk, rst;
    wire [31:0] core_result;
    wire pc_stall;
    reg [31:0] mac_WB;
    
    // MAC interface stub removed (Internal to RV32I_Core now)

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
    // Variables
    // -----------------------------------------------------------
    integer test_count;
    integer fail_count;
    
    // Configurable number of iterations per instruction test 
    parameter NUM_TEST_ITERS = 5;
    
    reg [31:0] expected_val;
    reg [31:0] actual_val;
    reg [31:0] test_pc;
    
    // ASCII Display in Waveform (Max 20 characters)
    reg [8*20:1] current_inst_name;

    // -----------------------------------------------------------
    // RV32I Opcodes & Funct definitions
    // -----------------------------------------------------------
    localparam OPCODE_R_TYPE = 7'b0110011;
    localparam OPCODE_I_TYPE = 7'b0010011;
    localparam OPCODE_LOAD   = 7'b0000011;
    localparam OPCODE_STORE  = 7'b0100011;
    localparam OPCODE_BRANCH = 7'b1100011;
    localparam OPCODE_LUI    = 7'b0110111;
    localparam OPCODE_AUIPC  = 7'b0010111;
    localparam OPCODE_JAL    = 7'b1101111;
    localparam OPCODE_JALR   = 7'b1100111;
    localparam OPCODE_MAC    = 7'b0001011;

    localparam F3_ADD_SUB = 3'b000;
    localparam F7_ADD     = 7'b0000000;
    localparam F7_SUB     = 7'b0100000;
    localparam F3_SLLSLA  = 3'b001; // SLLI, SLL
    localparam F3_SLT     = 3'b010;
    localparam F3_SLTU    = 3'b011;
    localparam F3_XOR     = 3'b100;
    localparam F3_SRLSRA  = 3'b101; // SRLI, SRAI, SRL, SRA
    localparam F3_OR      = 3'b110;
    localparam F3_AND     = 3'b111;

    localparam F3_LB      = 3'b000;
    localparam F3_LH      = 3'b001;
    localparam F3_LW      = 3'b010;
    localparam F3_LBU     = 3'b100;
    localparam F3_LHU     = 3'b101;
    
    localparam F3_SB      = 3'b000;
    localparam F3_SH      = 3'b001;
    localparam F3_SW      = 3'b010;

    localparam F3_BEQ     = 3'b000;
    localparam F3_BNE     = 3'b001;
    localparam F3_BLT     = 3'b100;
    localparam F3_BGE     = 3'b101;
    localparam F3_BLTU    = 3'b110;
    localparam F3_BGEU    = 3'b111;

    localparam F7_SRL     = 7'b0000000;
    localparam F7_SRA     = 7'b0100000;

    // -----------------------------------------------------------
    // Base Tasks : Generate Instruction Machine Codes
    // -----------------------------------------------------------
    task gen_R_type;
        input [6:0] opt;
        input [2:0] f3;
        input [6:0] f7;
        input [4:0] rs1;
        input [4:0] rs2;
        input [4:0] rd;
        output [31:0] inst;
        begin
            inst = {f7, rs2, rs1, f3, rd, opt};
        end
    endtask

    task gen_I_type;
        input [6:0] opt;
        input [2:0] f3;
        input [11:0] imm;
        input [4:0] rs1;
        input [4:0] rd;
        output [31:0] inst;
        begin
            inst = {imm, rs1, f3, rd, opt};
        end
    endtask

    task gen_S_type;
        input [2:0] f3;
        input [11:0] imm;
        input [4:0] rs1;
        input [4:0] rs2;
        output [31:0] inst;
        begin
            inst = {imm[11:5], rs2, rs1, f3, imm[4:0], OPCODE_STORE};
        end
    endtask

    task gen_B_type;
        input [2:0] f3;
        input [12:1] imm; // Actually 13 bit imm, LSB is 0
        input [4:0] rs1;
        input [4:0] rs2;
        output [31:0] inst;
        begin
            inst = {imm[12], imm[10:5], rs2, rs1, f3, imm[4:1], imm[11], OPCODE_BRANCH};
        end
    endtask

    task gen_U_type;
        input [6:0] opt;
        input [31:12] imm; // upper 20 bits
        input [4:0] rd;
        output [31:0] inst;
        begin
            inst = {imm, rd, opt};
        end
    endtask

    task gen_J_type;
        input [20:1] imm; // Actually 21 bit imm, LSB is 0
        input [4:0] rd;
        output [31:0] inst;
        begin
            inst = {imm[20], imm[10:1], imm[11], imm[19:12], rd, OPCODE_JAL};
        end
    endtask

    task gen_MAC_type;
        input [4:0] rs1;
        input [4:0] rs2;
        input [4:0] rd;
        output [31:0] inst;
        begin
            // As per MAC_start condition: (inst[31:25] == 7'b0000000) && (inst[14:12] == 3'b000) && (inst[6:0] == 7'b0001011)
            inst = {7'b0000000, rs2, rs1, 3'b000, rd, OPCODE_MAC};
        end
    endtask

    // -----------------------------------------------------------
    // Checker Task
    // -----------------------------------------------------------
    task execute_and_verify_reg;
        input [31:0] inst;
        input [4:0] rd;
        input [31:0] expected;
        input [8*20:1] test_name;
        begin
            current_inst_name = test_name;

            // Inject instruction to current PC memory location
            uut.u_imem.imem[test_pc >> 2] = inst;
            uut.u_imem.imem[(test_pc >> 2) + 1] = 32'hDEAD_DEAD; // Stall next
            
            // Set Core PC (forces the injection)
            uut.u_core.u_datapath.pc = test_pc;
            
            // Advance clock to let Core execute it
            @(negedge clk);
            
            // Verify Dest register (x0 is hardwired 0)
            actual_val = (rd == 0) ? 32'b0 : uut.u_core.u_datapath.u_reg.reg32[rd];
            
            if (actual_val !== expected) begin
                $display("[FAIL] %s | rd: x%0d | Expected: %8h | Actual: %8h", test_name, rd, expected, actual_val);
                fail_count = fail_count + 1;
            end
            
            test_count = test_count + 1;
            test_pc = test_pc + 4;
        end
    endtask

    // -----------------------------------------------------------
    // Task: Reset CPU and clear memories
    // -----------------------------------------------------------
    task reset_cpu;
        integer k;
        begin
            // 1. Assert Hardware Reset
            rst = 1;
            uut.u_core.u_datapath.pc = 32'h0000_0000;
            test_pc = 32'h0000_0000;
            
            // 2. Clear Regfile
            for(k=0; k<32; k=k+1) begin
                uut.u_core.u_datapath.u_reg.reg32[k] = 32'b0;
            end
            
            // 3. Clear DMEM (Assume DMEM depth is 256 bytes for test)
            // Array is byte-addressable (8-bit width)
            for(k=0; k<256; k=k+1) begin
                uut.u_dmem.dmem[k] = 8'b0;
            end

            // 4. Clear IMEM
            for(k=0; k<64; k=k+1) begin
                uut.u_imem.imem[k] = 32'b0;
            end
            
            // 5. Release Reset
            @(negedge clk);
            rst = 0;
            @(negedge clk);
        end
    endtask

    // -----------------------------------------------------------
    // Encapsulated Test Vector Tasks per Instruction
    // -----------------------------------------------------------
    
    // --- ADD ---
    task test_ADD;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rs2, rd;
        reg [31:0] v1, v2, inst;
        begin
            $display("-> Running %0d iterations for ADD...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu(); // Guarantee clean state
                
                rs1 = $urandom_range(1, 31);
                rs2 = $urandom_range(1, 31);
                while (rs1 == rs2) rs2 = $urandom_range(1, 31);
                rd  = $urandom_range(1, 31);
                v1  = (i == 0) ? 32'hFFFFFFFF : $urandom; // Edge case
                v2  = (i == 0) ? 32'h00000001 : $urandom; // Edge case
                
                uut.u_core.u_datapath.u_reg.reg32[rs1] = v1;
                uut.u_core.u_datapath.u_reg.reg32[rs2] = v2;
                
                gen_R_type(OPCODE_R_TYPE, F3_ADD_SUB, F7_ADD, rs1, rs2, rd, inst);
                expected_val = (rd == 0) ? 32'b0 : (v1 + v2);
                execute_and_verify_reg(inst, rd, expected_val, "R-Type: ADD");
            end
        end
    endtask

    // --- SUB ---
    task test_SUB;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rs2, rd;
        reg [31:0] v1, v2, inst;
        begin
            $display("-> Running %0d iterations for SUB...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                
                rs1 = $urandom_range(1, 31);
                rs2 = $urandom_range(1, 31);
                while (rs1 == rs2) rs2 = $urandom_range(1, 31);
                rd  = $urandom_range(1, 31);
                v1  = (i == 0) ? 32'h00000000 : $urandom; // Edge case
                v2  = (i == 0) ? 32'h00000001 : $urandom; // Edge case
                
                uut.u_core.u_datapath.u_reg.reg32[rs1] = v1;
                uut.u_core.u_datapath.u_reg.reg32[rs2] = v2;
                
                gen_R_type(OPCODE_R_TYPE, F3_ADD_SUB, F7_SUB, rs1, rs2, rd, inst);
                expected_val = (rd == 0) ? 32'b0 : (v1 - v2);
                execute_and_verify_reg(inst, rd, expected_val, "R-Type: SUB");
            end
        end
    endtask

    // --- XOR ---
    task test_XOR;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rs2, rd;
        reg [31:0] v1, v2, inst;
        begin
            $display("-> Running %0d iterations for XOR...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                
                rs1 = $urandom_range(1, 31);
                rs2 = $urandom_range(1, 31);
                while (rs1 == rs2) rs2 = $urandom_range(1, 31);
                rd  = $urandom_range(1, 31);
                v1  = $urandom;
                v2  = $urandom;
                
                uut.u_core.u_datapath.u_reg.reg32[rs1] = v1;
                uut.u_core.u_datapath.u_reg.reg32[rs2] = v2;
                
                gen_R_type(OPCODE_R_TYPE, F3_XOR, 7'b0, rs1, rs2, rd, inst);
                expected_val = (rd == 0) ? 32'b0 : (v1 ^ v2);
                execute_and_verify_reg(inst, rd, expected_val, "R-Type: XOR");
            end
        end
    endtask

    // --- OR ---
    task test_OR;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rs2, rd;
        reg [31:0] v1, v2, inst;
        begin
            $display("-> Running %0d iterations for OR...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                rs1 = $urandom_range(1, 31);
                rs2 = $urandom_range(1, 31);
                while (rs1 == rs2) rs2 = $urandom_range(1, 31);
                rd  = $urandom_range(1, 31);
                v1  = $urandom;
                v2  = $urandom;
                uut.u_core.u_datapath.u_reg.reg32[rs1] = v1;
                uut.u_core.u_datapath.u_reg.reg32[rs2] = v2;
                gen_R_type(OPCODE_R_TYPE, F3_OR, 7'b0, rs1, rs2, rd, inst);
                expected_val = (rd == 0) ? 32'b0 : (v1 | v2);
                execute_and_verify_reg(inst, rd, expected_val, "R-Type: OR");
            end
        end
    endtask

    // --- AND ---
    task test_AND;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rs2, rd;
        reg [31:0] v1, v2, inst;
        begin
            $display("-> Running %0d iterations for AND...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                
                rs1 = $urandom_range(1, 31);
                rs2 = $urandom_range(1, 31);
                while (rs1 == rs2) rs2 = $urandom_range(1, 31);
                rd  = $urandom_range(1, 31);
                v1  = $urandom;
                v2  = $urandom;
                
                uut.u_core.u_datapath.u_reg.reg32[rs1] = v1;
                uut.u_core.u_datapath.u_reg.reg32[rs2] = v2;
                
                gen_R_type(OPCODE_R_TYPE, F3_AND, 7'b0, rs1, rs2, rd, inst);
                expected_val = (rd == 0) ? 32'b0 : (v1 & v2);
                execute_and_verify_reg(inst, rd, expected_val, "R-Type: AND");
            end
        end
    endtask

    // --- SLL ---
    task test_SLL;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rs2, rd;
        reg [31:0] v1, v2, inst;
        reg [4:0] shamt;
        begin
            $display("-> Running %0d iterations for SLL...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                rs1 = $urandom_range(1, 31);
                rs2 = $urandom_range(1, 31);
                while (rs1 == rs2) rs2 = $urandom_range(1, 31);
                rd  = $urandom_range(1, 31);
                v1  = $urandom;
                v2  = $urandom;
                shamt = v2[4:0];
                uut.u_core.u_datapath.u_reg.reg32[rs1] = v1;
                uut.u_core.u_datapath.u_reg.reg32[rs2] = v2;
                gen_R_type(OPCODE_R_TYPE, F3_SLLSLA, 7'b0, rs1, rs2, rd, inst);
                expected_val = (rd == 0) ? 32'b0 : (v1 << shamt);
                execute_and_verify_reg(inst, rd, expected_val, "R-Type: SLL");
            end
        end
    endtask

    // --- SRL ---
    task test_SRL;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rs2, rd;
        reg [31:0] v1, v2, inst;
        reg [4:0] shamt;
        begin
            $display("-> Running %0d iterations for SRL...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                rs1 = $urandom_range(1, 31);
                rs2 = $urandom_range(1, 31);
                while (rs1 == rs2) rs2 = $urandom_range(1, 31);
                rd  = $urandom_range(1, 31);
                v1  = $urandom;
                v2  = $urandom;
                shamt = v2[4:0];
                uut.u_core.u_datapath.u_reg.reg32[rs1] = v1;
                uut.u_core.u_datapath.u_reg.reg32[rs2] = v2;
                gen_R_type(OPCODE_R_TYPE, F3_SRLSRA, F7_SRL, rs1, rs2, rd, inst);
                expected_val = (rd == 0) ? 32'b0 : (v1 >> shamt);
                execute_and_verify_reg(inst, rd, expected_val, "R-Type: SRL");
            end
        end
    endtask

    // --- SRA ---
    task test_SRA;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rs2, rd;
        reg [31:0] v1, v2, inst;
        reg signed [31:0] sv1;
        reg [4:0] shamt;
        begin
            $display("-> Running %0d iterations for SRA...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                rs1 = $urandom_range(1, 31);
                rs2 = $urandom_range(1, 31);
                while (rs1 == rs2) rs2 = $urandom_range(1, 31);
                rd  = $urandom_range(1, 31);
                v1  = $urandom;
                v2  = $urandom;
                sv1 = v1;
                shamt = v2[4:0];
                uut.u_core.u_datapath.u_reg.reg32[rs1] = v1;
                uut.u_core.u_datapath.u_reg.reg32[rs2] = v2;
                gen_R_type(OPCODE_R_TYPE, F3_SRLSRA, F7_SRA, rs1, rs2, rd, inst);
                if (rd == 0) expected_val = 32'b0;
                else         expected_val = sv1 >>> shamt;
                execute_and_verify_reg(inst, rd, expected_val, "R-Type: SRA");
            end
        end
    endtask

    // --- SLT ---
    task test_SLT;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rs2, rd;
        reg [31:0] v1, v2, inst;
        reg signed [31:0] sv1, sv2;
        begin
            $display("-> Running %0d iterations for SLT...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                rs1 = $urandom_range(1, 31);
                rs2 = $urandom_range(1, 31);
                while (rs1 == rs2) rs2 = $urandom_range(1, 31);
                rd  = $urandom_range(1, 31);
                v1  = $urandom;
                v2  = $urandom;
                sv1 = v1;
                sv2 = v2;
                uut.u_core.u_datapath.u_reg.reg32[rs1] = v1;
                uut.u_core.u_datapath.u_reg.reg32[rs2] = v2;
                gen_R_type(OPCODE_R_TYPE, F3_SLT, 7'b0, rs1, rs2, rd, inst);
                expected_val = (rd == 0) ? 32'b0 : ((sv1 < sv2) ? 32'h1 : 32'h0);
                execute_and_verify_reg(inst, rd, expected_val, "R-Type: SLT");
            end
        end
    endtask

    // --- SLTU ---
    task test_SLTU;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rs2, rd;
        reg [31:0] v1, v2, inst;
        begin
            $display("-> Running %0d iterations for SLTU...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                rs1 = $urandom_range(1, 31);
                rs2 = $urandom_range(1, 31);
                while (rs1 == rs2) rs2 = $urandom_range(1, 31);
                rd  = $urandom_range(1, 31);
                v1  = $urandom;
                v2  = $urandom;
                uut.u_core.u_datapath.u_reg.reg32[rs1] = v1;
                uut.u_core.u_datapath.u_reg.reg32[rs2] = v2;
                gen_R_type(OPCODE_R_TYPE, F3_SLTU, 7'b0, rs1, rs2, rd, inst);
                expected_val = (rd == 0) ? 32'b0 : ((v1 < v2) ? 32'h1 : 32'h0);
                execute_and_verify_reg(inst, rd, expected_val, "R-Type: SLTU");
            end
        end
    endtask

    // --- ADDI ---
    task test_ADDI;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rd;
        reg [11:0] imm;
        reg signed [31:0] sext_imm;
        reg [31:0] v1, inst;
        begin
            $display("-> Running %0d iterations for ADDI...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                
                rs1 = $urandom_range(1, 31);
                rd  = $urandom_range(1, 31);
                imm = $urandom;
                v1  = $urandom;
                sext_imm = {{20{imm[11]}}, imm};
                
                uut.u_core.u_datapath.u_reg.reg32[rs1] = v1;
                
                gen_I_type(OPCODE_I_TYPE, F3_ADD_SUB, imm, rs1, rd, inst);
                expected_val = (rd == 0) ? 32'b0 : (v1 + sext_imm);
                execute_and_verify_reg(inst, rd, expected_val, "I-Type: ADDI");
            end
        end
    endtask

    // --- XORI ---
    task test_XORI;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rd;
        reg [11:0] imm;
        reg signed [31:0] sext_imm;
        reg [31:0] v1, inst;
        begin
            $display("-> Running %0d iterations for XORI...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                rs1 = $urandom_range(1, 31);
                rd  = $urandom_range(1, 31);
                imm = $urandom;
                v1  = $urandom;
                sext_imm = {{20{imm[11]}}, imm};
                uut.u_core.u_datapath.u_reg.reg32[rs1] = v1;
                gen_I_type(OPCODE_I_TYPE, F3_XOR, imm, rs1, rd, inst);
                expected_val = (rd == 0) ? 32'b0 : (v1 ^ sext_imm);
                execute_and_verify_reg(inst, rd, expected_val, "I-Type: XORI");
            end
        end
    endtask

    // --- ORI ---
    task test_ORI;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rd;
        reg [11:0] imm;
        reg signed [31:0] sext_imm;
        reg [31:0] v1, inst;
        begin
            $display("-> Running %0d iterations for ORI...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                rs1 = $urandom_range(1, 31);
                rd  = $urandom_range(1, 31);
                imm = $urandom;
                v1  = $urandom;
                sext_imm = {{20{imm[11]}}, imm};
                uut.u_core.u_datapath.u_reg.reg32[rs1] = v1;
                gen_I_type(OPCODE_I_TYPE, F3_OR, imm, rs1, rd, inst);
                expected_val = (rd == 0) ? 32'b0 : (v1 | sext_imm);
                execute_and_verify_reg(inst, rd, expected_val, "I-Type: ORI");
            end
        end
    endtask
    
    // --- ANDI ---
    task test_ANDI;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rd;
        reg [11:0] imm;
        reg signed [31:0] sext_imm;
        reg [31:0] v1, inst;
        begin
            $display("-> Running %0d iterations for ANDI...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                rs1 = $urandom_range(1, 31);
                rd  = $urandom_range(1, 31);
                imm = $urandom;
                v1  = $urandom;
                sext_imm = {{20{imm[11]}}, imm};
                uut.u_core.u_datapath.u_reg.reg32[rs1] = v1;
                gen_I_type(OPCODE_I_TYPE, F3_AND, imm, rs1, rd, inst);
                expected_val = (rd == 0) ? 32'b0 : (v1 & sext_imm);
                execute_and_verify_reg(inst, rd, expected_val, "I-Type: ANDI");
            end
        end
    endtask

    // --- SLTI ---
    task test_SLTI;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rd;
        reg [11:0] imm;
        reg signed [31:0] sext_imm;
        reg [31:0] v1, inst;
        reg signed [31:0] sv1, simm;
        begin
            $display("-> Running %0d iterations for SLTI...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                rs1 = $urandom_range(1, 31);
                rd  = $urandom_range(1, 31);
                imm = $urandom;
                v1  = $urandom;
                sext_imm = {{20{imm[11]}}, imm};
                sv1 = v1;
                simm = sext_imm;
                uut.u_core.u_datapath.u_reg.reg32[rs1] = v1;
                gen_I_type(OPCODE_I_TYPE, F3_SLT, imm, rs1, rd, inst);
                expected_val = (rd == 0) ? 32'b0 : ((sv1 < simm) ? 32'h1 : 32'h0);
                execute_and_verify_reg(inst, rd, expected_val, "I-Type: SLTI");
            end
        end
    endtask

    // --- SLTIU ---
    task test_SLTIU;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rd;
        reg [11:0] imm;
        reg signed [31:0] sext_imm;
        reg [31:0] v1, inst;
        begin
            $display("-> Running %0d iterations for SLTIU...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                rs1 = $urandom_range(1, 31);
                rd  = $urandom_range(1, 31);
                imm = $urandom;
                v1  = $urandom;
                sext_imm = {{20{imm[11]}}, imm};
                uut.u_core.u_datapath.u_reg.reg32[rs1] = v1;
                gen_I_type(OPCODE_I_TYPE, F3_SLTU, imm, rs1, rd, inst);
                expected_val = (rd == 0) ? 32'b0 : ((v1 < sext_imm) ? 32'h1 : 32'h0); // Unsigned comparison!
                execute_and_verify_reg(inst, rd, expected_val, "I-Type: SLTIU");
            end
        end
    endtask

    // --- SLLI ---
    task test_SLLI;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rd, shamt;
        reg [11:0] imm;
        reg [31:0] v1, inst;
        begin
            $display("-> Running %0d iterations for SLLI...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                rs1 = $urandom_range(1, 31);
                rd  = $urandom_range(1, 31);
                shamt = $urandom_range(0, 31); // 5-bit shift amount
                imm = {7'b0000000, shamt}; // SLLI uses 0000000 in f7
                v1  = $urandom;
                uut.u_core.u_datapath.u_reg.reg32[rs1] = v1;
                gen_I_type(OPCODE_I_TYPE, F3_SLLSLA, imm, rs1, rd, inst);
                expected_val = (rd == 0) ? 32'b0 : (v1 << shamt);
                execute_and_verify_reg(inst, rd, expected_val, "I-Type: SLLI");
            end
        end
    endtask

    // --- SRLI ---
    task test_SRLI;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rd, shamt;
        reg [11:0] imm;
        reg [31:0] v1, inst;
        begin
            $display("-> Running %0d iterations for SRLI...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                rs1 = $urandom_range(1, 31);
                rd  = $urandom_range(1, 31);
                shamt = $urandom_range(0, 31);
                imm = {F7_SRL, shamt};
                v1  = $urandom;
                uut.u_core.u_datapath.u_reg.reg32[rs1] = v1;
                gen_I_type(OPCODE_I_TYPE, F3_SRLSRA, imm, rs1, rd, inst);
                expected_val = (rd == 0) ? 32'b0 : (v1 >> shamt);
                execute_and_verify_reg(inst, rd, expected_val, "I-Type: SRLI");
            end
        end
    endtask

    // --- SRAI ---
    task test_SRAI;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rd, shamt;
        reg [11:0] imm;
        reg [31:0] v1, inst;
        reg signed [31:0] sv1;
        begin
            $display("-> Running %0d iterations for SRAI...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                rs1 = $urandom_range(1, 31);
                rd  = $urandom_range(1, 31);
                shamt = $urandom_range(0, 31);
                imm = {F7_SRA, shamt}; // 0100000 for SRAI
                v1  = $urandom;
                sv1 = v1; // Treat as signed
                uut.u_core.u_datapath.u_reg.reg32[rs1] = v1;
                gen_I_type(OPCODE_I_TYPE, F3_SRLSRA, imm, rs1, rd, inst);
                if (rd == 0) expected_val = 32'b0;
                else         expected_val = sv1 >>> shamt;
                execute_and_verify_reg(inst, rd, expected_val, "I-Type: SRAI");
            end
        end
    endtask

    // --- LW ---
    task test_LW;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rd;
        reg [11:0] imm;
        reg [31:0] base_addr, mem_val, inst;
        reg [31:0] eff_addr;
        begin
            $display("-> Running %0d iterations for LW...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                rs1 = $urandom_range(1, 31);
                rd  = $urandom_range(1, 31);
                
                // Keep base+imm word-aligned and within DMEM bounds (max size 256 bytes)
                eff_addr = ($urandom_range(0, 63)) * 4;
                imm = eff_addr[11:0];
                base_addr = 32'b0;
                
                mem_val = $urandom;
                
                uut.u_core.u_datapath.u_reg.reg32[rs1] = base_addr;
                uut.u_dmem.dmem[eff_addr]   = mem_val[7:0];
                uut.u_dmem.dmem[eff_addr+1] = mem_val[15:8];
                uut.u_dmem.dmem[eff_addr+2] = mem_val[23:16];
                uut.u_dmem.dmem[eff_addr+3] = mem_val[31:24];
                
                gen_I_type(OPCODE_LOAD, F3_LW, imm, rs1, rd, inst);
                expected_val = (rd == 0) ? 32'b0 : mem_val;
                
                // Pipeline needs 1 extra clock for DMEM read? Let's check:
                // Execute HW test
                execute_and_verify_reg(inst, rd, expected_val, "I-Type: LW");
            end
        end
    endtask

    // --- LB ---
    task test_LB;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rd;
        reg [11:0] imm;
        reg [31:0] base_addr, mem_val, inst;
        reg [31:0] eff_addr;
        reg [7:0] byte_val;
        begin
            $display("-> Running %0d iterations for LB...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                rs1 = $urandom_range(1, 31);
                rd  = $urandom_range(1, 31);
                
                eff_addr = $urandom_range(0, 255);
                imm = eff_addr[11:0];
                base_addr = 32'b0;
                byte_val = $urandom;
                
                uut.u_core.u_datapath.u_reg.reg32[rs1] = base_addr;
                uut.u_dmem.dmem[eff_addr] = byte_val;
                
                gen_I_type(OPCODE_LOAD, F3_LB, imm, rs1, rd, inst);
                
                // Sign extend
                expected_val = (rd == 0) ? 32'b0 : {{24{byte_val[7]}}, byte_val};
                
                execute_and_verify_reg(inst, rd, expected_val, "I-Type: LB");
            end
        end
    endtask

    // --- LH ---
    task test_LH;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rd;
        reg [11:0] imm;
        reg [31:0] base_addr, mem_val, inst;
        reg [31:0] eff_addr;
        reg [15:0] half_val;
        begin
            $display("-> Running %0d iterations for LH...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                rs1 = $urandom_range(1, 31);
                rd  = $urandom_range(1, 31);
                
                eff_addr = $urandom_range(0, 127) * 2; // Halfword aligned
                imm = eff_addr[11:0];
                base_addr = 32'b0;
                half_val = $urandom;
                
                uut.u_core.u_datapath.u_reg.reg32[rs1] = base_addr;
                uut.u_dmem.dmem[eff_addr]   = half_val[7:0];
                uut.u_dmem.dmem[eff_addr+1] = half_val[15:8];
                
                gen_I_type(OPCODE_LOAD, F3_LH, imm, rs1, rd, inst);
                
                expected_val = (rd == 0) ? 32'b0 : {{16{half_val[15]}}, half_val};
                
                execute_and_verify_reg(inst, rd, expected_val, "I-Type: LH");
            end
        end
    endtask

    // --- LBU ---
    task test_LBU;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rd;
        reg [11:0] imm;
        reg [31:0] base_addr, mem_val, inst;
        reg [31:0] eff_addr;
        reg [7:0] byte_val;
        begin
            $display("-> Running %0d iterations for LBU...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                rs1 = $urandom_range(1, 31);
                rd  = $urandom_range(1, 31);
                
                eff_addr = $urandom_range(0, 255);
                imm = eff_addr[11:0];
                base_addr = 32'b0;
                byte_val = $urandom;
                
                uut.u_core.u_datapath.u_reg.reg32[rs1] = base_addr;
                uut.u_dmem.dmem[eff_addr] = byte_val;
                
                gen_I_type(OPCODE_LOAD, F3_LBU, imm, rs1, rd, inst);
                
                expected_val = (rd == 0) ? 32'b0 : {24'b0, byte_val}; // Zero extend
                execute_and_verify_reg(inst, rd, expected_val, "I-Type: LBU");
            end
        end
    endtask

    // --- LHU ---
    task test_LHU;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rd;
        reg [11:0] imm;
        reg [31:0] base_addr, mem_val, inst;
        reg [31:0] eff_addr;
        reg [15:0] half_val;
        begin
            $display("-> Running %0d iterations for LHU...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                rs1 = $urandom_range(1, 31);
                rd  = $urandom_range(1, 31);
                
                eff_addr = $urandom_range(0, 127) * 2;
                imm = eff_addr[11:0];
                base_addr = 32'b0;
                half_val = $urandom;
                
                uut.u_core.u_datapath.u_reg.reg32[rs1] = base_addr;
                uut.u_dmem.dmem[eff_addr]   = half_val[7:0];
                uut.u_dmem.dmem[eff_addr+1] = half_val[15:8];
                
                gen_I_type(OPCODE_LOAD, F3_LHU, imm, rs1, rd, inst);
                
                expected_val = (rd == 0) ? 32'b0 : {16'b0, half_val}; // Zero extend
                execute_and_verify_reg(inst, rd, expected_val, "I-Type: LHU");
            end
        end
    endtask

    // --- SW ---
    task test_SW;
        // SW doesn't write to Reg file, so execute_and_verify_reg isn't perfect.
        // We write custom verification logic here.
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rs2;
        reg [11:0] imm;
        reg [31:0] base_addr, store_val, inst;
        reg [31:0] eff_addr;
        reg [31:0] actual_mem_val;
        begin
            $display("-> Running %0d iterations for SW...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                current_inst_name = "S-Type: SW";
                
                rs1 = $urandom_range(1, 31);
                rs2 = $urandom_range(1, 31);
                while (rs1 == rs2) rs2 = $urandom_range(1, 31);
                
                eff_addr = ($urandom_range(0, 63)) * 4;
                imm = eff_addr[11:0];
                base_addr = 32'b0;
                store_val = $urandom;
                
                uut.u_core.u_datapath.u_reg.reg32[rs1] = base_addr;
                uut.u_core.u_datapath.u_reg.reg32[rs2] = store_val;
                
                gen_S_type(F3_SW, imm, rs1, rs2, inst);
                
                // Inject & Execute
                uut.u_imem.imem[test_pc >> 2] = inst;
                uut.u_imem.imem[(test_pc >> 2) + 1] = 32'hDEAD_DEAD;
                uut.u_core.u_datapath.pc = test_pc;
                
                @(negedge clk);
                
                // Check DMEM Write
                actual_mem_val = {uut.u_dmem.dmem[eff_addr+3], uut.u_dmem.dmem[eff_addr+2], uut.u_dmem.dmem[eff_addr+1], uut.u_dmem.dmem[eff_addr]};
                if (actual_mem_val !== store_val) begin
                    $display("[FAIL] S-Type: SW | Mem[%8h] | Expected: %8h | Actual: %8h", eff_addr, store_val, actual_mem_val);
                    fail_count = fail_count + 1;
                end
                
                test_count = test_count + 1;
                test_pc = test_pc + 4;
            end
        end
    endtask

    // --- SB ---
    task test_SB;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rs2;
        reg [11:0] imm;
        reg [31:0] base_addr, store_val, inst;
        reg [31:0] eff_addr, actual_mem_val, expected_mem_val;
        reg [31:0] orig_mem_val;
        begin
            $display("-> Running %0d iterations for SB...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                current_inst_name = "S-Type: SB";
                rs1 = $urandom_range(1, 31);
                rs2 = $urandom_range(1, 31);
                while (rs1 == rs2) rs2 = $urandom_range(1, 31);
                eff_addr = $urandom_range(0, 255);
                imm = eff_addr[11:0];
                base_addr = 32'b0;
                store_val = $urandom;
                
                uut.u_core.u_datapath.u_reg.reg32[rs1] = base_addr;
                uut.u_core.u_datapath.u_reg.reg32[rs2] = store_val;
                
                gen_S_type(F3_SB, imm, rs1, rs2, inst);
                
                uut.u_imem.imem[test_pc >> 2] = inst;
                uut.u_core.u_datapath.pc = test_pc;
                @(negedge clk);
                
                actual_mem_val = {24'b0, uut.u_dmem.dmem[eff_addr]};
                expected_mem_val = {24'b0, store_val[7:0]};
                
                if (actual_mem_val !== expected_mem_val) begin
                    $display("[FAIL] S-Type: SB | Mem[%8h] | Expected Word: %8h | Actual: %8h", eff_addr, expected_mem_val, actual_mem_val);
                    fail_count = fail_count + 1;
                end
                
                test_count = test_count + 1;
                test_pc = test_pc + 4;
            end
        end
    endtask

    // --- SH ---
    task test_SH;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rs2;
        reg [11:0] imm;
        reg [31:0] base_addr, store_val, inst;
        reg [31:0] eff_addr, actual_mem_val, expected_mem_val;
        reg [31:0] orig_mem_val;
        begin
            $display("-> Running %0d iterations for SH...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                current_inst_name = "S-Type: SH";
                rs1 = $urandom_range(1, 31);
                rs2 = $urandom_range(1, 31);
                while (rs1 == rs2) rs2 = $urandom_range(1, 31);
                eff_addr = $urandom_range(0, 127) * 2;
                imm = eff_addr[11:0];
                base_addr = 32'b0;
                store_val = $urandom;
                
                uut.u_core.u_datapath.u_reg.reg32[rs1] = base_addr;
                uut.u_core.u_datapath.u_reg.reg32[rs2] = store_val;
                
                gen_S_type(F3_SH, imm, rs1, rs2, inst);
                
                uut.u_imem.imem[test_pc >> 2] = inst;
                uut.u_core.u_datapath.pc = test_pc;
                @(negedge clk);
                
                actual_mem_val = {16'b0, uut.u_dmem.dmem[eff_addr+1], uut.u_dmem.dmem[eff_addr]};
                expected_mem_val = {16'b0, store_val[15:0]};
                
                if (actual_mem_val !== expected_mem_val) begin
                    $display("[FAIL] S-Type: SH | Mem[%8h] | Expected Word: %8h | Actual: %8h", eff_addr, expected_mem_val, actual_mem_val);
                    fail_count = fail_count + 1;
                end
                
                test_count = test_count + 1;
                test_pc = test_pc + 4;
            end
        end
    endtask

    // --- BEQ ---
    task test_BEQ;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rs2;
        reg [12:1] imm;
        reg [31:0] v1, v2, inst;
        reg [31:0] actual_next_pc, expected_next_pc;
        reg signed [31:0] sext_imm;
        begin
            $display("-> Running %0d iterations for BEQ...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                current_inst_name = "B-Type: BEQ";
                
                rs1 = $urandom_range(1, 31);
                rs2 = $urandom_range(1, 31);
                while (rs1 == rs2) rs2 = $urandom_range(1, 31);
                
                // 50% chance of being equal to force branch taken
                v1 = $urandom;
                v2 = (i % 2 == 0) ? v1 : $urandom; 
                
                // Random target aligned to 2 bytes
                imm = $urandom_range(2, 60) & ~1;
                sext_imm = {{19{imm[12]}}, imm, 1'b0};
                
                uut.u_core.u_datapath.u_reg.reg32[rs1] = v1;
                uut.u_core.u_datapath.u_reg.reg32[rs2] = v2;
                
                gen_B_type(F3_BEQ, imm, rs1, rs2, inst);
                
                // Inject & Execute
                uut.u_imem.imem[test_pc >> 2] = inst;
                uut.u_core.u_datapath.pc = test_pc;
                
                expected_next_pc = (v1 == v2) ? (test_pc + sext_imm) : (test_pc + 4);
                
                // Clock step
                @(negedge clk);
                
                actual_next_pc = uut.u_core.u_datapath.pc; // View PC after clock
                
                if (actual_next_pc !== expected_next_pc) begin
                    $display("[FAIL] B-Type: BEQ | v1:%8h v2:%8h | Expected PC: %8h | Actual PC: %8h", v1, v2, expected_next_pc, actual_next_pc);
                    fail_count = fail_count + 1;
                end
                
                test_count = test_count + 1;
                test_pc = test_pc + 4; // Reset test_pc progression for next test (not related to branch result)
            end
        end
    endtask

    // --- BNE ---
    task test_BNE;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rs2;
        reg [12:1] imm;
        reg [31:0] v1, v2, inst;
        reg [31:0] actual_next_pc, expected_next_pc;
        reg signed [31:0] sext_imm;
        begin
            $display("-> Running %0d iterations for BNE...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                current_inst_name = "B-Type: BNE";
                rs1 = $urandom_range(1, 31);
                rs2 = $urandom_range(1, 31);
                while (rs1 == rs2) rs2 = $urandom_range(1, 31);
                v1 = $urandom;
                v2 = (i % 2 == 0) ? v1 : $urandom; // 50% chance of being equal
                imm = $urandom_range(2, 60) & ~1;
                sext_imm = {{19{imm[12]}}, imm, 1'b0};
                uut.u_core.u_datapath.u_reg.reg32[rs1] = v1;
                uut.u_core.u_datapath.u_reg.reg32[rs2] = v2;
                gen_B_type(F3_BNE, imm, rs1, rs2, inst);
                uut.u_imem.imem[test_pc >> 2] = inst;
                uut.u_core.u_datapath.pc = test_pc;
                expected_next_pc = (v1 != v2) ? (test_pc + sext_imm) : (test_pc + 4);
                @(negedge clk);
                actual_next_pc = uut.u_core.u_datapath.pc; 
                if (actual_next_pc !== expected_next_pc) begin
                    $display("[FAIL] B-Type: BNE | Expected PC: %8h | Actual PC: %8h", expected_next_pc, actual_next_pc);
                    fail_count = fail_count + 1;
                end
                test_count = test_count + 1;
                test_pc = test_pc + 4; 
            end
        end
    endtask

    // --- BLT ---
    task test_BLT;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rs2;
        reg [12:1] imm;
        reg [31:0] v1, v2, inst;
        reg [31:0] actual_next_pc, expected_next_pc;
        reg signed [31:0] sext_imm;
        reg signed [31:0] sv1, sv2;
        begin
            $display("-> Running %0d iterations for BLT...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                current_inst_name = "B-Type: BLT";
                
                rs1 = $urandom_range(1, 31);
                rs2 = $urandom_range(1, 31);
                while (rs1 == rs2) rs2 = $urandom_range(1, 31);
                v1 = $urandom;
                v2 = $urandom;
                sv1 = v1;
                sv2 = v2;
                
                imm = $urandom_range(2, 60) & ~1;
                sext_imm = {{19{imm[12]}}, imm, 1'b0};
                
                uut.u_core.u_datapath.u_reg.reg32[rs1] = v1;
                uut.u_core.u_datapath.u_reg.reg32[rs2] = v2;
                
                gen_B_type(F3_BLT, imm, rs1, rs2, inst);
                
                uut.u_imem.imem[test_pc >> 2] = inst;
                uut.u_core.u_datapath.pc = test_pc;
                
                expected_next_pc = (sv1 < sv2) ? (test_pc + sext_imm) : (test_pc + 4);
                
                @(negedge clk);
                
                actual_next_pc = uut.u_core.u_datapath.pc; 
                
                if (actual_next_pc !== expected_next_pc) begin
                    $display("[FAIL] B-Type: BLT | Expected PC: %8h | Actual PC: %8h", expected_next_pc, actual_next_pc);
                    fail_count = fail_count + 1;
                end
                
                test_count = test_count + 1;
                test_pc = test_pc + 4; 
            end
        end
    endtask

    // --- BGE ---
    task test_BGE;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rs2;
        reg [12:1] imm;
        reg [31:0] v1, v2, inst;
        reg [31:0] actual_next_pc, expected_next_pc;
        reg signed [31:0] sext_imm;
        reg signed [31:0] sv1, sv2;
        begin
            $display("-> Running %0d iterations for BGE...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                current_inst_name = "B-Type: BGE";
                rs1 = $urandom_range(1, 31);
                rs2 = $urandom_range(1, 31);
                while (rs1 == rs2) rs2 = $urandom_range(1, 31);
                v1 = $urandom;
                v2 = $urandom;
                sv1 = v1;
                sv2 = v2;
                imm = $urandom_range(2, 60) & ~1;
                sext_imm = {{19{imm[12]}}, imm, 1'b0};
                uut.u_core.u_datapath.u_reg.reg32[rs1] = v1;
                uut.u_core.u_datapath.u_reg.reg32[rs2] = v2;
                gen_B_type(F3_BGE, imm, rs1, rs2, inst);
                uut.u_imem.imem[test_pc >> 2] = inst;
                uut.u_core.u_datapath.pc = test_pc;
                expected_next_pc = (sv1 >= sv2) ? (test_pc + sext_imm) : (test_pc + 4);
                @(negedge clk);
                actual_next_pc = uut.u_core.u_datapath.pc; 
                if (actual_next_pc !== expected_next_pc) begin
                    $display("[FAIL] B-Type: BGE | Expected PC: %8h | Actual PC: %8h", expected_next_pc, actual_next_pc);
                    fail_count = fail_count + 1;
                end
                test_count = test_count + 1;
                test_pc = test_pc + 4; 
            end
        end
    endtask

    // --- BLTU ---
    task test_BLTU;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rs2;
        reg [12:1] imm;
        reg [31:0] v1, v2, inst;
        reg [31:0] actual_next_pc, expected_next_pc;
        reg signed [31:0] sext_imm;
        begin
            $display("-> Running %0d iterations for BLTU...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                current_inst_name = "B-Type: BLTU";
                rs1 = $urandom_range(1, 31);
                rs2 = $urandom_range(1, 31);
                while (rs1 == rs2) rs2 = $urandom_range(1, 31);
                v1 = $urandom;
                v2 = $urandom;
                imm = $urandom_range(2, 60) & ~1;
                sext_imm = {{19{imm[12]}}, imm, 1'b0};
                uut.u_core.u_datapath.u_reg.reg32[rs1] = v1;
                uut.u_core.u_datapath.u_reg.reg32[rs2] = v2;
                gen_B_type(F3_BLTU, imm, rs1, rs2, inst);
                uut.u_imem.imem[test_pc >> 2] = inst;
                uut.u_core.u_datapath.pc = test_pc;
                expected_next_pc = (v1 < v2) ? (test_pc + sext_imm) : (test_pc + 4); // Unsigned
                @(negedge clk);
                actual_next_pc = uut.u_core.u_datapath.pc; 
                if (actual_next_pc !== expected_next_pc) begin
                    $display("[FAIL] B-Type: BLTU | Expected PC: %8h | Actual PC: %8h", expected_next_pc, actual_next_pc);
                    fail_count = fail_count + 1;
                end
                test_count = test_count + 1;
                test_pc = test_pc + 4; 
            end
        end
    endtask

    // --- BGEU ---
    task test_BGEU;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rs2;
        reg [12:1] imm;
        reg [31:0] v1, v2, inst;
        reg [31:0] actual_next_pc, expected_next_pc;
        reg signed [31:0] sext_imm;
        begin
            $display("-> Running %0d iterations for BGEU...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                current_inst_name = "B-Type: BGEU";
                rs1 = $urandom_range(1, 31);
                rs2 = $urandom_range(1, 31);
                while (rs1 == rs2) rs2 = $urandom_range(1, 31);
                v1 = $urandom;
                v2 = $urandom;
                imm = $urandom_range(2, 60) & ~1;
                sext_imm = {{19{imm[12]}}, imm, 1'b0};
                uut.u_core.u_datapath.u_reg.reg32[rs1] = v1;
                uut.u_core.u_datapath.u_reg.reg32[rs2] = v2;
                gen_B_type(F3_BGEU, imm, rs1, rs2, inst);
                uut.u_imem.imem[test_pc >> 2] = inst;
                uut.u_core.u_datapath.pc = test_pc;
                expected_next_pc = (v1 >= v2) ? (test_pc + sext_imm) : (test_pc + 4); // Unsigned
                @(negedge clk);
                actual_next_pc = uut.u_core.u_datapath.pc; 
                if (actual_next_pc !== expected_next_pc) begin
                    $display("[FAIL] B-Type: BGEU | Expected PC: %8h | Actual PC: %8h", expected_next_pc, actual_next_pc);
                    fail_count = fail_count + 1;
                end
                test_count = test_count + 1;
                test_pc = test_pc + 4; 
            end
        end
    endtask

    // --- LUI ---
    task test_LUI;
        input integer num_iters;
        integer i;
        reg [4:0] rd;
        reg [31:12] imm;
        reg [31:0] inst;
        begin
            $display("-> Running %0d iterations for LUI...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                rd  = $urandom_range(1, 31);
                imm = $urandom;
                gen_U_type(OPCODE_LUI, imm, rd, inst);
                expected_val = (rd == 0) ? 32'b0 : {imm, 12'b0};
                execute_and_verify_reg(inst, rd, expected_val, "U-Type: LUI");
            end
        end
    endtask

    // --- JAL ---
    task test_JAL;
        input integer num_iters;
        integer i;
        reg [4:0] rd;
        reg [20:1] imm;
        reg [31:0] inst;
        reg signed [31:0] sext_imm;
        reg [31:0] expected_next_pc, actual_next_pc;
        begin
            $display("-> Running %0d iterations for JAL...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                current_inst_name = "J-Type: JAL";
                rd  = $urandom_range(1, 31);
                imm = $urandom_range(2, 60) & ~1;
                sext_imm = {{11{imm[20]}}, imm, 1'b0};
                
                gen_J_type(imm, rd, inst);
                
                // Inject & Execute
                uut.u_imem.imem[test_pc >> 2] = inst;
                uut.u_core.u_datapath.pc = test_pc;
                
                expected_val = (rd == 0) ? 32'b0 : (test_pc + 4);
                expected_next_pc = test_pc + sext_imm;
                
                @(negedge clk);
                
                // Verify Link Register
                actual_val = (rd == 0) ? 32'b0 : uut.u_core.u_datapath.u_reg.reg32[rd];
                if (actual_val !== expected_val) begin
                    $display("[FAIL] JAL Link  | rd: x%0d | Expected: %8h | Actual: %8h", rd, expected_val, actual_val);
                    fail_count = fail_count + 1;
                end
                
                // Verify Jump Target
                actual_next_pc = uut.u_core.u_datapath.pc; 
                if (actual_next_pc !== expected_next_pc) begin
                    $display("[FAIL] JAL Jump  | Expected PC: %8h | Actual PC: %8h", expected_next_pc, actual_next_pc);
                    fail_count = fail_count + 1;
                end
                
                test_count = test_count + 1;
                test_pc = test_pc + 4; 
            end
        end
    endtask

    // --- JALR ---
    task test_JALR;
        input integer num_iters;
        integer i;
        reg [4:0] rd, rs1;
        reg [11:0] imm;
        reg [31:0] inst;
        reg signed [31:0] sext_imm;
        reg [31:0] expected_next_pc, actual_next_pc, v1;
        begin
            $display("-> Running %0d iterations for JALR...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                current_inst_name = "I-Type: JALR";
                rd  = $urandom_range(1, 31);
                rs1 = $urandom_range(1, 31);
                imm = $urandom;
                v1  = $urandom;
                sext_imm = {{20{imm[11]}}, imm};
                
                uut.u_core.u_datapath.u_reg.reg32[rs1] = v1;
                // I-Type for JALR is F3=000
                gen_I_type(OPCODE_JALR, 3'b000, imm, rs1, rd, inst);
                
                uut.u_imem.imem[test_pc >> 2] = inst;
                uut.u_core.u_datapath.pc = test_pc;
                
                expected_val = (rd == 0) ? 32'b0 : (test_pc + 4);
                expected_next_pc = (v1 + sext_imm) & ~1; // LSB is cleared
                
                @(negedge clk);
                
                actual_val = (rd == 0) ? 32'b0 : uut.u_core.u_datapath.u_reg.reg32[rd];
                if (actual_val !== expected_val) begin
                    $display("[FAIL] JALR Link | rd: x%0d | Expected: %8h | Actual: %8h", rd, expected_val, actual_val);
                    fail_count = fail_count + 1;
                end
                
                actual_next_pc = uut.u_core.u_datapath.pc; 
                if (actual_next_pc !== expected_next_pc) begin
                    $display("[FAIL] JALR Jump | Expected PC: %8h | Actual PC: %8h", expected_next_pc, actual_next_pc);
                    fail_count = fail_count + 1;
                end
                
                test_count = test_count + 1;
                test_pc = test_pc + 4; 
            end
        end
    endtask

    // --- AUIPC ---
    task test_AUIPC;
        input integer num_iters;
        integer i;
        reg [4:0] rd;
        reg [31:12] imm;
        reg [31:0] inst;
        begin
            $display("-> Running %0d iterations for AUIPC...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                rd  = $urandom_range(1, 31);
                imm = $urandom;
                gen_U_type(OPCODE_AUIPC, imm, rd, inst);
                expected_val = (rd == 0) ? 32'b0 : (test_pc + {imm, 12'b0});
                execute_and_verify_reg(inst, rd, expected_val, "U-Type: AUIPC");
            end
        end
    endtask

    // --- MAC (Custom Instruction V2MAC) ---
    task test_MAC;
        input integer num_iters;
        integer i;
        reg [4:0] rs1, rs2, rd;
        reg [31:0] vA, vB, vC;
        reg [31:0] inst;
        reg [15:0] mul_a_high, mul_a_low, mul_b_high, mul_b_low;
        reg [31:0] expected_mult_high, expected_mult_low;
        begin
            $display("-> Running %0d iterations for V2MAC...", num_iters);
            for (i=0; i<num_iters; i=i+1) begin
                reset_cpu();
                current_inst_name = "Custom: V2MAC";
                
                rs1 = $urandom_range(1, 31);
                rs2 = $urandom_range(1, 31);
                while (rs1 == rs2) rs2 = $urandom_range(1, 31); // Prevent collision
                rd  = $urandom_range(1, 31);
                while (rd == rs1 || rd == rs2) rd = $urandom_range(1, 31); // Protect operand overwrite
                
                vA = $urandom;
                vB = $urandom;
                vC = $urandom; // rd initial value (accumulate base)
                
                uut.u_core.u_datapath.u_reg.reg32[rs1] = vA;
                uut.u_core.u_datapath.u_reg.reg32[rs2] = vB;
                uut.u_core.u_datapath.u_reg.reg32[rd]  = vC;
                
                gen_MAC_type(rs1, rs2, rd, inst);
                
                // Inject
                uut.u_imem.imem[test_pc >> 2] = inst;
                // Since MAC takes 3-4 cycles, stall pipeline with DEAD_DEAD
                uut.u_imem.imem[(test_pc >> 2) + 1] = 32'hDEAD_DEAD;
                uut.u_imem.imem[(test_pc >> 2) + 2] = 32'hDEAD_DEAD;
                uut.u_imem.imem[(test_pc >> 2) + 3] = 32'hDEAD_DEAD;
                
                uut.u_core.u_datapath.pc = test_pc;
                
                // --- Golden Model Calculation based on MAC_top.v logic ---
                mul_a_high = vA[31:16];
                mul_a_low  = vA[15:0];
                mul_b_high = vB[31:16];
                mul_b_low  = vB[15:0];
                
                expected_mult_high = $signed(mul_a_high) * $signed(mul_b_high);
                expected_mult_low  = $signed(mul_a_low)  * $signed(mul_b_low);
                expected_val = (rd == 0) ? 32'b0 : (expected_mult_high + expected_mult_low + vC);
                
                // --- Wait for MAC FSM to finish ---
                @(negedge clk); // Wait for state to change out of IDLE (T0)
                while (uut.u_core.u_MAC.state != 2'b00) begin
                    @(negedge clk);
                end
                
                // Verify Result
                actual_val = (rd == 0) ? 32'b0 : uut.u_core.u_datapath.u_reg.reg32[rd];
                
                if (actual_val !== expected_val) begin
                    $display("[FAIL] Custom: V2MAC | rd: x%0d | Expected: %8h | Actual: %8h", rd, expected_val, actual_val);
                    fail_count = fail_count + 1;
                end
                
                test_count = test_count + 1;
                test_pc = test_pc + 4; 
            end
        end
    endtask

    // -----------------------------------------------------------
    // Main Executive Block
    // -----------------------------------------------------------
    initial begin
        clk = 0;
        rst = 1;
        mac_WB = 0;
        
        test_count = 0;
        fail_count = 0;
        test_pc = 32'h0000_0000;
        current_inst_name = "INIT";
        
        #15;
        rst = 0;
        @(negedge clk);
        
        $display("\n=================================================");
        $display("   Constrained Random Testing (CRT) Started");
        $display("   Executing Modular Vector Tasks...");
        $display("=================================================");

        // --- Call Test Vectors Here ---
        test_ADD (NUM_TEST_ITERS); // 1
        test_SUB (NUM_TEST_ITERS); // 2
        test_XOR (NUM_TEST_ITERS); // 3
        test_OR  (NUM_TEST_ITERS); // 4
        test_AND (NUM_TEST_ITERS); // 5
        test_SLL (NUM_TEST_ITERS); // 6
        test_SRL (NUM_TEST_ITERS); // 7
        test_SRA (NUM_TEST_ITERS); // 8
        test_SLT (NUM_TEST_ITERS); // 9
        test_SLTU(NUM_TEST_ITERS); // 10
        
        test_ADDI (NUM_TEST_ITERS); // 11
        test_SLLI (NUM_TEST_ITERS); // 12
        test_SRLI (NUM_TEST_ITERS); // 13
        test_SRAI (NUM_TEST_ITERS); // 14
        test_XORI (NUM_TEST_ITERS); // 15
        test_ORI  (NUM_TEST_ITERS); // 16
        test_ANDI (NUM_TEST_ITERS); // 17
        test_SLTI (NUM_TEST_ITERS); // 18
        test_SLTIU(NUM_TEST_ITERS); // 19
        
        test_LW  (NUM_TEST_ITERS); // 20
        test_LB  (NUM_TEST_ITERS); // 21
        test_LH  (NUM_TEST_ITERS); // 22
        test_LBU (NUM_TEST_ITERS); // 23
        test_LHU (NUM_TEST_ITERS); // 24
        
        test_SW  (NUM_TEST_ITERS); // 25
        test_SB  (NUM_TEST_ITERS); // 26
        test_SH  (NUM_TEST_ITERS); // 27

        test_BEQ (NUM_TEST_ITERS); // 28
        test_BNE (NUM_TEST_ITERS); // 29
        test_BLT (NUM_TEST_ITERS); // 30
        test_BGE (NUM_TEST_ITERS); // 31
        test_BLTU(NUM_TEST_ITERS); // 32
        test_BGEU(NUM_TEST_ITERS); // 33

        test_LUI  (NUM_TEST_ITERS); // 34
        test_AUIPC(NUM_TEST_ITERS); // 35
        test_JAL  (NUM_TEST_ITERS); // 36
        test_JALR (NUM_TEST_ITERS); // 37

        test_MAC (NUM_TEST_ITERS); // 38
        
        // test_OR(50);
        // test_XORI(50);
        // test_MAC(50);
        // ...

        $display("\n=================================================");
        $display("   Testing Completed");
        $display("   Total Tests Run : %0d", test_count);
        $display("   Total Failures  : %0d", fail_count);
        if (fail_count == 0)
            $display("   Status: >> ALL TESTS PASSED <<");
        else
            $display("   Status: >> SOME TESTS FAILED <<");
        $display("=================================================\n");
        $finish;
    end

    // -----------------------------------------------------------
    // SimVision Dumping
    // -----------------------------------------------------------
    initial begin
        $shm_open("wave.shm");
        $shm_probe(tb_System_Top_CRT, "ACMTF"); // A: All, C: Ports, M: Memories, T: Tasks, F: Functions
    end

endmodule
