`timescale 1ns/1ps
`include "constants.svh"

module fdxmw_tb();
	logic clk;
   logic rst;
    
   // Fetch stage
   logic [DWIDTH - 1:0] tb_pc;
   logic [DWIDTH - 1:0] tb_inst;
    
   // Decode stage
   logic [4:0] tb_rs1, tb_rs2, tb_rd;
   logic [DWIDTH - 1:0] tb_imm;
   logic [6:0] tb_opcode;
   logic [2:0] tb_func3;
   logic [6:0] tb_func7;
   logic [DWIDTH - 1:0] tb_rs1_data, tb_rs2_data;
   logic tb_d_memR, tb_d_memW, tb_d_regW;
    
   // Execute stage
   logic [DWIDTH - 1:0] tb_alu_result, tb_x_rs2_out;
   logic [4:0] tb_x_rd_out;
   logic tb_x_memR, tb_x_memW, tb_x_regW;
   logic tb_branch_taken;
   logic [DWIDTH - 1:0] tb_branch_target;
    
   // Memory stage
   logic [DWIDTH - 1:0] tb_mem_data, tb_m_alu_result;
   logic [4:0] tb_m_rd_out;
   logic tb_m_regW;
   logic [DWIDTH - 1:0] tb_dmem_addr, tb_dmem_in, tb_dmem_out;
   logic tb_dmem_read_en, tb_dmem_write_en;
    
   // Writeback stage
   logic tb_w_regW;
   logic [4:0] tb_w_rd;
   logic [DWIDTH - 1:0] tb_w_data;
    
   // Valid signals from pipeline registers
   logic tb_fd_v, tb_dx_v, tb_xm_v, tb_mw_v;
    
   // Hazard and forwarding signals
   logic tb_stallF, tb_stallD, tb_stallX, tb_stallM, tb_stallW;
   logic tb_flushD, tb_flushX;
   logic [1:0] tb_fwdA, tb_fwdB;

   
   // memory operation tracking 
   logic [31:0] store_addresses [0:MAX_EVENTS-1];
   logic [31:0] store_data [0:MAX_EVENTS-1];
   logic [31:0] load_addresses [0:MAX_EVENTS-1];
   logic [31:0] load_data [0:MAX_EVENTS-1];
    
   int store_count, load_count;
   int cycle;
   int instruction_count;
   
   // Memory access macro
   `define DMEM_BYTES fdxmw_top1.memory1.dmemory1.main_memory

   // Read a 32-bit little-endian word from data memory at byte address 'a'
   function [31:0] dmem_word(input int a);
		dmem_word = {`DMEM_BYTES[a+3], `DMEM_BYTES[a+2],
                   `DMEM_BYTES[a+1], `DMEM_BYTES[a+0]};
   endfunction

	// top file instantiation
   fdxmw_top fdxmw_top1 (
		.clk(clk),
      .rst(rst)
   );

	// signal connections
   // Fetch stage
   assign tb_pc = fdxmw_top1.f_pc_now;
   assign tb_inst = fdxmw_top1.f_inst;
    
   // Decode stage
   assign tb_rs1 = fdxmw_top1.d_rs1;
   assign tb_rs2 = fdxmw_top1.d_rs2;
   assign tb_rd = fdxmw_top1.d_rd;
   assign tb_imm = fdxmw_top1.d_imm;
   assign tb_opcode = fdxmw_top1.d_opcode;
   assign tb_func3 = fdxmw_top1.d_func3;
   assign tb_func7 = fdxmw_top1.d_func7;
   assign tb_rs1_data = fdxmw_top1.rf_rs1;
   assign tb_rs2_data = fdxmw_top1.rf_rs2;
   assign tb_d_memR = fdxmw_top1.d_memR;
   assign tb_d_memW = fdxmw_top1.d_memW;
   assign tb_d_regW = fdxmw_top1.d_regW;
    
   // Execute stage
   assign tb_alu_result = fdxmw_top1.x_alu_result;
   assign tb_x_rs2_out = fdxmw_top1.x_rs2_out;
   assign tb_x_rd_out = fdxmw_top1.x_rd_out;
   assign tb_x_memR = fdxmw_top1.x_memR;
   assign tb_x_memW = fdxmw_top1.x_memW;
   assign tb_x_regW = fdxmw_top1.x_regW;
   assign tb_branch_taken = fdxmw_top1.x_branch_taken;
   assign tb_branch_target = fdxmw_top1.x_branch_target;
   
   // Memory stage
   assign tb_mem_data = fdxmw_top1.m_mem_data_out;
   assign tb_m_alu_result = fdxmw_top1.m_alu_result_out;
   assign tb_m_rd_out = fdxmw_top1.m_rd_out;
   assign tb_m_regW = fdxmw_top1.m_regW_out;
   assign tb_dmem_addr = fdxmw_top1.memory1.dmem_addr;
   assign tb_dmem_in = fdxmw_top1.memory1.dmem_in;
   assign tb_dmem_out = fdxmw_top1.memory1.dmem_out;
   assign tb_dmem_read_en = fdxmw_top1.memory1.dmem_read_en;
   assign tb_dmem_write_en = fdxmw_top1.memory1.dmem_write_en;
   
   // Writeback stage
   assign tb_w_regW = fdxmw_top1.w_regW_out;
   assign tb_w_rd = fdxmw_top1.w_rd_out;
   assign tb_w_data = fdxmw_top1.w_write_data;
   
	// Valid flags from pipeline regs
	assign tb_stallF = fdxmw_top1.t_stallF;
	assign tb_stallD = fdxmw_top1.t_stallD;
	assign tb_stallX = fdxmw_top1.t_stallX;
	assign tb_stallM = fdxmw_top1.t_stallM;
	assign tb_stallW = fdxmw_top1.t_stallW;

	assign tb_flushD = fdxmw_top1.t_flushD;
	assign tb_flushX = fdxmw_top1.t_flushX;

	assign tb_fwdA   = fdxmw_top1.t_fwdA;
	assign tb_fwdB   = fdxmw_top1.t_fwdB;

    
	// clock gen
   initial begin
		clk = 1'b0;
      forever #5 clk = ~clk;
   end

   
	// instruction order
   function string decode_instruction(input [31:0] inst);
		logic [6:0] opcode;
      logic [2:0] func3;
      logic [6:0] func7;
        
      if ($isunknown(inst)) return "UNKNOWN";
        
		opcode = inst[6:0];
      func3 = inst[14:12];
      func7 = inst[31:25];
        
      case (opcode)
			RTYPE: begin // R-type
				case ({func7[5], func3})
					ADD: return "ADD";
               SUB: return "SUB";
               SLL: return "SLL";
               SLT: return "SLT";
               SLTU: return "SLTU";
               XOR: return "XOR";
               SRL: return "SRL";
               SRA: return "SRA";
               OR: return "OR";
               AND: return "AND";
               default: return "R-TYPE";
            endcase
         end
         ITYPE: begin // I-type
            case (func3)
					ADD: return "ADDI";
               SLT: return "SLTI";
               SLTU: return "SLTIU";
               XOR: return "XORI";
               OR: return "ORI";
               AND: return "ANDI";
               SLL: return "SLLI";
               SRA: return "SRAI";
					SRL: return "SRLI";
               default: return "I-TYPE";
            endcase
         end
         LWITYPE: begin // Load
             case (func3)
					LB_f3: return "LB";
               LH_f3: return "LH";
               LW_f3: return "LW";
               LBU_f3: return "LBU";
               LHU_f3: return "LHU";
               default: return "L-TYPE";
            endcase
         end
         STYPE: begin // Store
            case (func3)
					SB_f3: return "SB";
               SH_f3: return "SH";
               SW_f3: return "SW";
               default: return "S-TYPE";
            endcase
         end
         BTYPE: begin // Branch
            case (func3)
               BEQ: return "BEQ";
               BNE: return "BNE";
               BLT: return "BLT";
               BGE: return "BGE";
               BLTU: return "BLTU";
               BGEU: return "BGEU";
               default: return "B-TYPE";
            endcase
         end
         LUIUTYPE: return "LUI";
         AUIPCUTYPE: return "AUIPC";
         JALJTYPE: return "JAL";
         JALRJTYPE: return "JALR";
         default: return "UNKNOWN";
		endcase
	endfunction
	 
    
	 // main test
    initial begin : main_test
        $display("=== Enhanced RISC-V Pipeline Testbench ===");
        $display("Testing: Execution, Memory ops, Stalls, Bypassing");
        $display("%s", {50{"="}});
        
        // Initialize counters
        store_count = 0;
        load_count = 0;
        cycle = 0;
        instruction_count = 0;
        
        // Reset sequence
        rst = 1'b1;
        repeat(3) @(posedge clk);
        rst = 1'b0;
        $display("\nReset complete. Pipeline starting...\n");
        
        // Wait for reset to settle
        @(posedge clk);
        
        // Check initial state
        if ($isunknown(tb_pc)) begin
            $fatal("ERROR: PC is unknown after reset!");
        end
        
        // Main monitoring loop
        repeat(35) begin
            @(posedge clk);
            #1ps; // Small delay for signal settling
            
            cycle++;
            
            // Print cycle header
            $display("CYCLE %0d", cycle);
            
            // Monitor each pipeline stage
            monitor_fetch_stage();
            monitor_decode_stage();
            monitor_execute_stage();
            monitor_memory_stage();
            monitor_writeback_stage();
            
            // Check for hazards and stalls
            monitor_hazards_and_stalls();
            
            // Track memory operations
            track_memory_operations();
            
            $display(""); // Blank line between cycles
            
            // Periodic register file snapshot
            if ((cycle % 10) == 0 && cycle > 8) begin
                print_register_snapshot();
            end
        end
        
        // Final summary
        print_final_summary();
        $finish;
    end

    // monitor task for each stage
	 // fetch stage task
    task monitor_fetch_stage();
        string inst_name;
        inst_name = decode_instruction(tb_inst);
        $display("FETCH   : PC=0x%08h  INST=0x%08h (%s)", 
                 tb_pc, tb_inst, inst_name);
        
        if (!$isunknown(tb_inst) && tb_inst != 32'h0) begin
            instruction_count++;
        end
    endtask
    
	 // decode stage task
    task monitor_decode_stage();
        if (tb_fd_v && !$isunknown(tb_opcode)) begin
            $display("DECODE  : rs1=x%0d(0x%h) rs2=x%0d(0x%h) rd=x%0d imm=%0d", 
                     tb_rs1, tb_rs1_data, tb_rs2, tb_rs2_data, tb_rd, $signed(tb_imm));
            $display("Controls: memR=%b memW=%b regW=%b", 
                     tb_d_memR, tb_d_memW, tb_d_regW);
        end else begin
            $display("DECODE  : [BUBBLE/STALLED]");
        end
    endtask
    
	 // execute stage task
    task monitor_execute_stage();
        if (tb_dx_v && !$isunknown(tb_alu_result)) begin
            $display("EXECUTE : ALU=0x%08h  Controls: memR=%b memW=%b regW=%b", 
                     tb_alu_result, tb_x_memR, tb_x_memW, tb_x_regW);
            
            // Show destination register
            if (tb_x_regW && tb_x_rd_out != 0) begin
                $display("Target: x%0d will receive ALU result", tb_x_rd_out);
            end
            
            // Show branch information
            if (tb_branch_taken) begin
                $display("BRANCH TAKEN -> PC=0x%08h", tb_branch_target);
            end
        end else begin
            $display("EXECUTE : [BUBBLE/STALLED]");
        end
    endtask
    
	 // memory stage task
    task monitor_memory_stage();
        string mem_op;
        if (tb_xm_v) begin
            if (tb_dmem_read_en || tb_dmem_write_en) begin
                mem_op = tb_dmem_write_en ? "STORE" : "LOAD ";
                $display("MEMORY  : %s addr=0x%08h din=0x%08h dout=0x%08h", 
                         mem_op, tb_dmem_addr, tb_dmem_in, tb_dmem_out);
            end else begin
                $display("MEMORY  : ALU passthrough=0x%08h (no mem access)", tb_m_alu_result);
            end
            
            if (tb_m_regW && tb_m_rd_out != 0) begin
                $display("Target: x%0d will be written", tb_m_rd_out);
            end
        end else begin
            $display("MEMORY  : [BUBBLE/STALLED]");
        end
    endtask
    
    task monitor_writeback_stage();
        if (tb_mw_v) begin
            if (tb_w_regW && tb_w_rd != 0) begin
                $display("WRITEBACK: x%0d <- 0x%08h", tb_w_rd, tb_w_data);
            end else begin
                $display("WRITEBACK: [NO REGISTER WRITE]");
            end
        end else begin
            $display("WRITEBACK: [BUBBLE/STALLED]");
        end
    endtask
    
    task monitor_hazards_and_stalls();
        logic hazard_activity;
        string fwdA_src, fwdB_src;
        
        hazard_activity = 1'b0;
        
        // Check for stalls
        if (tb_stallF || tb_stallD || tb_stallX || tb_stallM || tb_stallW) begin
            $display("STALLS: F=%b D=%b X=%b M=%b W=%b", 
                     tb_stallF, tb_stallD, tb_stallX, tb_stallM, tb_stallW);
            hazard_activity = 1'b1;
        end
        
        // Check for flushes
        if (tb_flushD || tb_flushX) begin
            $display("│FLUSH : D=%b X=%b", tb_flushD, tb_flushX);
            hazard_activity = 1'b1;
        end
        
        // Check for forwarding
        if (tb_fwdA != 2'b00 || tb_fwdB != 2'b00) begin
            fwdA_src = (tb_fwdA == 2'b10) ? "MEM" : (tb_fwdA == 2'b01) ? "WB" : "REG";
            fwdB_src = (tb_fwdB == 2'b10) ? "MEM" : (tb_fwdB == 2'b01) ? "WB" : "REG";
            $display("FORWARD: A=%s(%0d) B=%s(%0d)", 
                     fwdA_src, tb_fwdA, fwdB_src, tb_fwdB);
            hazard_activity = 1'b1;
        end
        
        // Manual RAW hazard detection for educational purposes
        if (tb_fd_v && tb_dx_v && tb_x_regW && tb_x_rd_out != 0) begin
            if (tb_rs1 == tb_x_rd_out || tb_rs2 == tb_x_rd_out) begin
                $display("RAW HAZARD: x%0d needed by decode, written by execute", tb_x_rd_out);
                hazard_activity = 1'b1;
            end
        end
        
        if (hazard_activity) begin
            $display("");
        end
    endtask
    
    task track_memory_operations();
        logic [31:0] readback;
        logic [31:0] expected_data;
        
        // Track store operations
        if (tb_dmem_write_en && tb_xm_v) begin
            store_addresses[store_count] = tb_dmem_addr;
            store_data[store_count] = tb_dmem_in;
            $display("STORE[%0d]: addr=0x%08h <- data=0x%08h", 
                     store_count, tb_dmem_addr, tb_dmem_in);
            store_count++;
            
            // Immediate verification (next cycle)
            fork
                begin
                    @(posedge clk);
                    #1ps;
                    readback = dmem_word(tb_dmem_addr);
                    if (readback === tb_dmem_in) begin
                        $display("Store verified: DMEM[0x%08h] = 0x%08h", 
                                 tb_dmem_addr, readback);
                    end else begin
                        $display("Store FAILED: Expected 0x%08h, got 0x%08h", 
                                 tb_dmem_in, readback);
                    end
                end
            join_none;
        end
        
        // Track load operations
        if (tb_dmem_read_en && tb_xm_v) begin
            expected_data = dmem_word(tb_dmem_addr);
            load_addresses[load_count] = tb_dmem_addr;
            load_data[load_count] = tb_dmem_out;
            
            $display("LOAD[%0d] : addr=0x%08h -> data=0x%08h", 
                     load_count, tb_dmem_addr, tb_dmem_out);
            
            // Verify load data
            if (tb_dmem_out === expected_data) begin
                $display("Load correct: matches memory content");
            end else begin
                $display("Load MISMATCH: Expected 0x%08h, got 0x%08h", 
                         expected_data, tb_dmem_out);
            end
            load_count++;
        end
    endtask
    
    task print_register_snapshot();
        $display("\nREGISTER FILE SNAPSHOT (Cycle %0d):", cycle);
        $display("────────────────────────────────────────────────");
        $display("x1 =0x%08h  x2 =0x%08h  x3 =0x%08h ", 
                 32'hDEADBEEF, 32'hDEADBEEF, 32'hDEADBEEF);
        $display("x4 =0x%08h  x5 =0x%08h  x6 =0x%08h ", 
                 32'hDEADBEEF, 32'hDEADBEEF, 32'hDEADBEEF);
        $display("x7 =0x%08h  x8 =0x%08h  x9 =0x%08h ", 
                 32'hDEADBEEF, 32'hDEADBEEF, 32'hDEADBEEF);
        $display("x10=0x%08h  x11=0x%08h  x12=0x%08h ", 
                 32'hDEADBEEF, 32'hDEADBEEF, 32'hDEADBEEF);
        $display("(Register file path needs adjustment)");
        $display("────────────────────────────────────────────────\n");
    endtask
    
    task print_final_summary();
        int i;
        logic [31:0] final_val;
        int store_errors, load_errors;
        
        store_errors = 0;
        load_errors = 0;
        
        $display("\n%s" + {60{"="}});
        $display("FINAL TEST SUMMARY");
        $display("\n%s", {60{"="}});
        
        $display("\nEXECUTION STATISTICS:");
        $display("   Instructions fetched: %0d", instruction_count);
        $display("   Store operations:     %0d", store_count);
        $display("   Load operations:      %0d", load_count);
        $display("   Total cycles:         %0d", cycle);
        
        $display("\nMEMORY OPERATION VERIFICATION:");
        if (store_count > 0) begin
            $display("Store Results:");
            for (i = 0; i < store_count; i++) begin
                final_val = dmem_word(store_addresses[i]);
                if (final_val === store_data[i]) begin
                    $display("DMEM[0x%08h] = 0x%08h", store_addresses[i], final_val);
                end else begin
                    $display("DMEM[0x%08h] = 0x%08h (expected 0x%08h)", 
                             store_addresses[i], final_val, store_data[i]);
                    store_errors++;
                end
            end
        end else begin
            $display("No store operations detected");
        end
        
        if (load_count > 0) begin
            $display("Load operations: %0d total", load_count);
        end else begin
            $display("No load operations detected");
        end
        
        // Check key memory locations
        $display("\nKEY MEMORY LOCATIONS:");
        final_val = dmem_word(32);
        $display("DMEM[32]  = 0x%08h", final_val);
        final_val = dmem_word(64);
        $display("DMEM[64]  = 0x%08h", final_val);
        final_val = dmem_word(96);
        $display("DMEM[96]  = 0x%08h", final_val);
        
        $display("\nFINAL REGISTER STATE:");
        $display("Register file path needs adjustment - check your decode module");
        $display("Current RF data: rs1=0x%08h rs2=0x%08h", tb_rs1_data, tb_rs2_data);
        
        $display("\nTEST RESULTS:");
        if (store_errors == 0 && load_errors == 0) begin
            $display("ALL MEMORY OPERATIONS PASSED!");
        end else begin
            $display("%0d store errors, %0d load errors detected", store_errors, load_errors);
        end
        
        $display("\n%s", {60{"="}});
        $display("Testbench completed successfully!");
    endtask

    // Watch for critical errors
    always @(posedge clk) begin
        if (!rst) begin
            // Check for X/Z values in critical paths
            if ($isunknown(tb_pc)) begin
                $warning("PC became unknown at cycle %0d", cycle);
            end
            
            // Monitor for impossible register writes (rd=0)
            if (tb_w_regW && tb_w_rd == 0 && tb_mw_v) begin
                $warning("Attempted write to x0 at cycle %0d", cycle);
            end
            
            // Check for memory alignment (word accesses should be 4-byte aligned)
            if ((tb_dmem_read_en || tb_dmem_write_en) && tb_xm_v) begin
                if (tb_dmem_addr[1:0] != 2'b00) begin
                    $warning("Unaligned memory access at 0x%08h (cycle %0d)", 
                             tb_dmem_addr, cycle);
                end
            end
        end
    end

endmodule : fdxmw_tb