`timescale 1ns/1ps
`include "constants.svh"

// synthesis translate_off
module pp_tb();
   logic clk;
   logic rst;

// === Program generator for IMEM ===
function automatic [31:0] rv_addi(input int rd, input int rs1, input int imm);
   rv_addi = ((imm & 'hFFF) << 20) | ((rs1 & 31) << 15) | (0 << 12) | ((rd & 31) << 7) | 7'h13;
endfunction
function automatic [31:0] rv_add(input int rd, input int rs1, input int rs2);
   rv_add = (0 << 25) | ((rs2 & 31) << 20) | ((rs1 & 31) << 15) | (0 << 12) | ((rd & 31) << 7) | 7'h33;
endfunction
function automatic [31:0] rv_sub(input int rd, input int rs1, input int rs2);
   rv_sub = (32'h20 << 25) | ((rs2 & 31) << 20) | ((rs1 & 31) << 15) | (0 << 12) | ((rd & 31) << 7) | 7'h33;
endfunction
function automatic [31:0] rv_lw(input int rd, input int rs1, input int imm);
   rv_lw = ((imm & 'hFFF) << 20) | ((rs1 & 31) << 15) | (3 << 12) | ((rd & 31) << 7) | 7'h03;
endfunction
function automatic [31:0] rv_sw(input int rs2, input int rs1, input int imm);
   rv_sw = (((imm >> 5) & 'h7F) << 25) | ((rs2 & 31) << 20) | ((rs1 & 31) << 15) | (2 << 12) | ((imm & 31) << 7) | 7'h23;
endfunction
function automatic [31:0] rv_nop();
   rv_nop = rv_addi(0,0,0);
endfunction

task automatic write_imem_program();
   int fh;
   fh = $fopen("memory_file.mem","w");
   if (fh == 0) $fatal(1, "Failed to open memory_file.mem for writing");
   // Program:
   // 0x00: addi x1, x0, 5
   // 0x04: addi x2, x0, 7
   // 0x08: add  x5, x1, x2         ; forward to next
   // 0x0C: sub  x6, x5, x2         ; should forward from XM (no stall)
   // 0x10: addi x3, x0, 0          ; DMEM base
   // 0x14: addi x7, x0, 9
   // 0x18: sw   x7, 0(x3)          ; DMEM[0] = 9
   // 0x1C: lw   x5, 0(x3)          ; load 9 into x5
   // 0x20: add  x6, x5, x2         ; load-use -> 1-cycle stall then WB forward
   // 0x24: nop
   $fdisplay(fh, "%08x", rv_addi(1, 0, 5));
   $fdisplay(fh, "%08x", rv_addi(2, 0, 7));
   $fdisplay(fh, "%08x", rv_add(5, 1, 2));
   $fdisplay(fh, "%08x", rv_sub(6, 5, 2));
   $fdisplay(fh, "%08x", rv_addi(3, 0, 0));
   $fdisplay(fh, "%08x", rv_addi(7, 0, 9));
   $fdisplay(fh, "%08x", rv_sw(7, 3, 0));
   $fdisplay(fh, "%08x", rv_lw(5, 3, 0));
   $fdisplay(fh, "%08x", rv_add(6, 5, 2));
   $fdisplay(fh, "%08x", rv_nop());
   for (int i=0;i<20;i++) $fdisplay(fh, "%08x", rv_nop());
   $fclose(fh);
   $display("TB: Wrote program to memory_file.mem");
endtask

// Ensure IMEM is loaded after writing the file (deterministic)
task automatic preload_imem();
   // Try reading via hierarchical path
   $readmemh("memory_file.mem", fdxmw_top1.imemory1.main_memory);
   $display("TB: Preloaded IMEM via $readmemh");
endtask

// Addresses for key instructions
localparam int PC_ADD    = 32'h0000_0008;
localparam int PC_SUB    = 32'h0000_000C;
localparam int PC_SW     = 32'h0000_0018;
localparam int PC_LW     = 32'h0000_001C;
localparam int PC_ADDDEP = 32'h0000_0020;


   // Monitor signals for pipeline stages
   // Fetch stage
   logic [DWIDTH - 1:0] tb_pc;
   logic [DWIDTH - 1:0] tb_inst;
    
   // Decode stage
   logic [4:0] tb_rs1, tb_rs2, tb_rd;
   logic [DWIDTH - 1:0] tb_imm;
   logic [6:0] tb_opcode;
   logic [2:0] tb_func3;
   logic [6:0] tb_func7;
   
   // Register file
   logic [DWIDTH - 1:0] tb_rs1_data, tb_rs2_data;
   
   // Execute stage
   logic [DWIDTH - 1:0] tb_alu_result, tb_x_rs2_out, tb_x_pc_out;
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
   logic [2:0] tb_m_func3;
	 
   // Writeback stage
   logic tb_w_regW;
   logic [4:0] tb_w_rd;
   logic [DWIDTH - 1:0] tb_w_data;
	 
   // Track store/load operations 
   localparam int MAX_EVENTS   = 100;
   localparam int DMEM_RD      = 0;  // read 
   localparam int DMEM_WR_VIS  = 1;  // write visible

   logic [31:0] store_addresses [0:MAX_EVENTS-1];
   logic [31:0] store_data      [0:MAX_EVENTS-1];
   int          store_ready     [0:MAX_EVENTS-1];

   logic [31:0] load_addresses  [0:MAX_EVENTS-1];
   logic [31:0] load_expected   [0:MAX_EVENTS-1];
   logic [2:0]  load_func3      [0:MAX_EVENTS-1];
   int          load_ready      [0:MAX_EVENTS-1];
	
   logic [4:0]  load_rd         [0:MAX_EVENTS-1];
   bit          load_w_pending  [0:MAX_EVENTS-1];

   int store_count, load_count;
   int cycle;
   int cycles = 80;
	 
   // capture of last store
   int checked_store_idx;
   int checked_load_idx;
	 
   logic write_hit, read_hit;
	 
   `define DMEM_BYTES fdxmw_top1.memory1.dmemory1.main_memory

   // Read a 32-bit little-endian word from data memory at byte address 'a'
   function automatic [31:0] dmem_word(input int a);
      dmem_word = {`DMEM_BYTES[a+3], `DMEM_BYTES[a+2],
                   `DMEM_BYTES[a+1], `DMEM_BYTES[a+0]};
   endfunction

   // Compute expected LOAD value 
   function automatic [31:0] dmem_load_expected(input int addr, input logic [2:0] func3);
      if (func3 == LW_f3) begin
         dmem_load_expected = dmem_word(addr);
      end else begin
         dmem_load_expected = 'x;
      end
   endfunction

   // pipeline valid bits
   logic f_v, d_v, x_v, m_v, w_v;
	
   // previous pc tracker
   logic [DWIDTH - 1:0] pc_q;
	
   // branch behavior checks
   parameter int BR_REDIRECT = 1;
   parameter int FLUSH_WIN   = 2;
	
   // Instantiate the DUT
   fdxmw_top fdxmw_top1 (
      .clk(clk),
      .rst(rst)
   );

   // Connect monitoring signals
   // Fetch
   assign tb_pc   = fdxmw_top1.fetch1.pc_now;
   assign tb_inst = fdxmw_top1.imem_out;
    
   // Decode
   assign tb_rs1    = fdxmw_top1.decode1.rs1;
   assign tb_rs2    = fdxmw_top1.decode1.rs2;
   assign tb_rd     = fdxmw_top1.decode1.rd;
   assign tb_imm    = fdxmw_top1.decode1.imm;
   assign tb_opcode = fdxmw_top1.decode1.opcode;
   assign tb_func3  = fdxmw_top1.decode1.func3;
   assign tb_func7  = fdxmw_top1.decode1.func7;
    
   // Register file
   assign tb_rs1_data = fdxmw_top1.decode1.rf1.rs1_data;
   assign tb_rs2_data = fdxmw_top1.decode1.rf1.rs2_data;
    
   // Execute
   assign tb_alu_result    = fdxmw_top1.execute1.alu_result;
   assign tb_x_rs2_out     = fdxmw_top1.execute1.rs2_out;
   assign tb_x_pc_out      = fdxmw_top1.execute1.pc_out;
   assign tb_x_rd_out      = fdxmw_top1.execute1.rd_out;
   assign tb_x_memR        = fdxmw_top1.execute1.memR;
   assign tb_x_memW        = fdxmw_top1.execute1.memW;
   assign tb_x_regW        = fdxmw_top1.execute1.regW;
   assign tb_branch_taken  = fdxmw_top1.execute1.branch_taken;
   assign tb_branch_target = fdxmw_top1.execute1.branch_target;
    
   // Memory
   assign tb_mem_data     = fdxmw_top1.memory1.mem_data;
   assign tb_m_alu_result = fdxmw_top1.memory1.alu_result_out;
   assign tb_m_rd_out     = fdxmw_top1.memory1.rd_out;
   assign tb_m_regW       = fdxmw_top1.memory1.regW_out;
   assign tb_m_func3      = fdxmw_top1.memory1.func3_in;
    
   // Data memory signals
   assign tb_dmem_addr     = fdxmw_top1.memory1.dmem_addr;
   assign tb_dmem_in       = fdxmw_top1.memory1.dmem_in;
   assign tb_dmem_out      = fdxmw_top1.memory1.dmem_out;
   assign tb_dmem_read_en  = fdxmw_top1.memory1.dmem_read_en;
   assign tb_dmem_write_en = fdxmw_top1.memory1.dmem_write_en;
	 
   // Writeback
   assign tb_w_regW = fdxmw_top1.writeback1.regW_out;
   assign tb_w_rd   = fdxmw_top1.writeback1.rd_out;
   assign tb_w_data = fdxmw_top1.writeback1.data_out;

   // Clock generation
   initial begin
      clk = 1'b0;
      forever #5 clk = ~clk;
   end
	 
   
   // Reset (assert for posedges; deassert between edges)
   initial begin
      write_imem_program();
      preload_imem();
      $display("--- Starting RISC-V Pipeline Test (stall/forwarding) ---");
      rst = 1'b1;
      #10;
      rst = 1'b0;
      @(posedge clk);
      $display("Reset complete. Pipeline starting...");
   end
	
   // VCD for quick inspection
   initial begin
      $dumpfile("fdxmw_tb.vcd");
      $dumpvars(0, fdxmw_tb);
   end
	
   initial begin
      if($value$plusargs("CYCLES=%d", cycles)) begin
         $display("Overriding cycles via +CYCLES=%0d", cycles);
      end
   end
	
   always_ff @(posedge clk or posedge rst) begin
      if (rst) begin
         {f_v, d_v, x_v, m_v, w_v} <= '0;
         pc_q <= '0;
      end else begin
         {d_v, x_v, m_v, w_v} <= {f_v, d_v, x_v, m_v};
         f_v  <= !$isunknown(tb_inst);
         pc_q <= tb_pc;
      end
   end

   `ifndef SYNTHESIS
      // SVA: Branch redirect check
      default clocking tb_cb @(posedge clk); endclocking
		
      property p_branch_redirect;
         $rose(tb_branch_taken) |=> ##BR_REDIRECT (tb_pc == tb_branch_target);
      endproperty
		
      assert property (p_branch_redirect)
        else $error("Branch redirect failed: pc=0x%08h target=0x%08h (lat=%0d)",
                    tb_pc, tb_branch_target, BR_REDIRECT);
								
      int flush_cnt;
      always_ff @(posedge clk or posedge rst) begin
         if (rst) begin
            flush_cnt <= 0;
         end else begin
            if ($rose(tb_branch_taken)) begin
               flush_cnt <= FLUSH_WIN;
            end else if (flush_cnt > 0) begin
               flush_cnt <= flush_cnt - 1;
            end
         end
      end
		
      // SVA: No wrong path writebacks during flush 
      property p_no_wb; 
         (flush_cnt > 0) |-> !(w_v && tb_w_regW && tb_w_rd != '0);
      endproperty

      assert property (p_no_wb)
        else $error("Wrong-path writeback observed during flush window");
			
      function automatic bit no_stall_now();
         return f_v; // Replace with stall predicate if available
      endfunction

      property p_pc_plus4_x;
         (no_stall_now() && !tb_branch_taken) |=> (tb_pc == pc_q + 4);
      endproperty

      assert property (p_pc_plus4_x)
        else $warning("PC didn’t advance by +4 (could be a legal stall; verify)");

// SVA: One-cycle stall after LW (load-use hazard) before dependent ADD
property p_load_use_stall;
   (tb_x_pc_out == PC_LW) |-> ##1 (tb_pc == pc_q) ##1 (tb_pc == pc_q + 4);
endproperty
assert property (p_load_use_stall)
  else $error("Expected 1-cycle stall after LW @0x%08h before dependent ADD", PC_LW);

// SVA: Forwarding on ADD->SUB pair (no stall)
property p_alu_forward_no_stall;
   (tb_x_pc_out == PC_ADD) |-> ##1 (tb_pc == pc_q + 4);
endproperty
assert property (p_alu_forward_no_stall)
  else $error("Unexpected stall between ADD and SUB (forwarding should handle it).");

		
      // branch/jump name
      function automatic string branch(input logic [6:0] opcode, input logic [2:0] func3);
         if (opcode == BTYPE) begin
            unique case (func3)
              3'b000: return "BEQ";
              3'b001: return "BNE";
              3'b100: return "BLT";
              3'b101: return "BGE";
              3'b110: return "BLTU";
              3'b111: return "BGEU";
              default: return "B???";
            endcase
         end else if (opcode == JALJTYPE) begin
            return "JAL";
         end else if (opcode == JALRJTYPE) begin
            return "JALR";
         end else begin
            return "";
         end
      endfunction
		
      always_ff @(posedge clk) begin
         if (tb_branch_taken) begin
            string b;
            b = branch(tb_opcode, tb_func3);
            if (b != "") begin
               $display("TAKEN %-4s -> 0x%08h (from pc=0x%08h)", b, tb_branch_target, tb_pc);
            end else begin
               $display("BRANCH/JUMP TAKEN: target=0x%08h (pc_now=0x%08h, inst=0x%08h)",
                        tb_branch_target, tb_pc, tb_inst);
            end
         end
      end
		
      // Branch coverage
      covergroup cg_branches @(posedge clk);
         coverpoint tb_branch_taken { bins taken = {1}; }
         coverpoint tb_func3 iff (tb_branch_taken && tb_opcode == 7'b1100011) {
            bins beq  = {3'b000};
            bins bne  = {3'b001};
            bins blt  = {3'b100};
            bins bge  = {3'b101};
            bins bltu = {3'b110};
            bins bgeu = {3'b111};
         }
         coverpoint tb_opcode iff (tb_branch_taken) {
            bins jal  = {7'b1101111};
            bins jalr = {7'b1100111};
         }
      endgroup
      cg_branches br_cov = new();
   `endif

   // Main monitor + store/load verification with latencies
   initial begin : run_and_check

      // locals
      int k;
      int a;
      logic [31:0] w;

      // counters
      store_count       = 0; 
      load_count        = 0;
      checked_store_idx = 0;
      checked_load_idx  = 0;

      // wait until out of reset
      @(negedge rst);
      @(posedge clk);

      if ($isunknown(tb_pc)) begin
         $fatal("tb_pc is X; PC path or reset is wrong.");
      end

      if ($isunknown(tb_inst)) begin
         $display("Warning: tb_inst is X. If PC is good, check imemory load (file path).");
      end

      for (cycle = 0; cycle < cycles; cycle++) begin
         @(posedge clk);
         #1ps;  // tiny delay

         $display("\n--- Cycle %0d ---", cycle); // PC_prev=0x%08h", pc_q);

         // FETCH
         $display("FETCH  : PC=0x%h, INST=0x%h%s", tb_pc, tb_inst, (tb_pc==pc_q && !tb_branch_taken) ? "  [STALL]" : "");

         // DECODE
         if (d_v) begin
            $display("DECODE : rs1=%0d(0x%h), rs2=%0d(0x%h), rd=%0d, imm=%0d, op=0x%h",
                     tb_rs1, tb_rs1_data, tb_rs2, tb_rs2_data, tb_rd, tb_imm, tb_opcode);
         end else begin
            $display("DECODE : N/A");
         end

         // EXECUTE
         if (x_v) begin
            $display("EXECUTE: ALU=0x%h, memR=%b, memW=%b, regW=%b",
                     tb_alu_result, tb_x_memR, tb_x_memW, tb_x_regW);
         end else begin
            $display("EXECUTE: N/A");
         end

         // MEMORY
         if (m_v && (tb_dmem_read_en || tb_dmem_write_en)) begin
            $display("MEMORY : addr=0x%h, read=%b, write=%b, din=0x%h, dout=0x%h",
                     tb_dmem_addr, tb_dmem_read_en, tb_dmem_write_en, tb_dmem_in, tb_dmem_out);
         end else if (!m_v) begin
            $display("MEMORY : N/A");
         end

         // WRITEBACK
         if (w_v && tb_w_regW && tb_w_rd != 0) begin
            $display("WRITEBACK: rd=%0d <- 0x%h", tb_w_rd, tb_w_data);
         end else if (!w_v) begin
            $display("WRITEBACK: N/A");
         end

         // Store
         if (tb_dmem_write_en) begin
            store_addresses[store_count] = tb_dmem_addr;
            store_data     [store_count] = tb_dmem_in;
            store_ready    [store_count] = cycle + DMEM_WR_VIS;
            $display("STORE_EVENT[%0d]: addr=0x%08h <- data=0x%08h (verify @ C%0d)",
                     store_count, tb_dmem_addr, tb_dmem_in, store_ready[store_count]);
            store_count++;
         end

         // Verify stores whose write should be visible now
         if (checked_store_idx < store_count && cycle >= store_ready[checked_store_idx]) begin
            logic [31:0] saw_s;
            saw_s = dmem_word(store_addresses[checked_store_idx]);
            if (saw_s !== store_data[checked_store_idx]) begin
               $error("DMEM MISMATCH @0x%08h: expected 0x%08h, got 0x%08h",
                      store_addresses[checked_store_idx], store_data[checked_store_idx], saw_s);
            end else begin
               $display("PASS: DMEM[0x%08h] now = 0x%08h",
                        store_addresses[checked_store_idx], saw_s);
            end
            checked_store_idx++;
         end

         // Load
         if (tb_dmem_read_en) begin
            if (tb_m_func3 == LW_f3) begin   
               load_addresses [load_count] = tb_dmem_addr;                       
               load_func3     [load_count] = tb_m_func3;                          
               load_expected  [load_count] = dmem_load_expected(tb_dmem_addr, tb_m_func3);  
               load_rd        [load_count] = tb_m_rd_out;                         
               load_w_pending [load_count] = 1'b1;                                
               load_ready     [load_count] = cycle + DMEM_RD; // log only  
               $display("LOAD_EVENT[%0d]: addr=0x%08h (LW) -> expect=0x%08h, rd=x%0d (verify @ C%0d)",
                        load_count, tb_dmem_addr, load_expected[load_count], tb_m_rd_out, load_ready[load_count]);  
               load_count++;
            end else begin
               $display("LOAD_EVENT: non-LW (f3=0x%0h) — skipping check", tb_m_func3);
            end
         end

         if (w_v && tb_w_regW && tb_w_rd != 0) begin  
            for (int i = 0; i < load_count; i++) begin  
               if (load_w_pending[i] && (tb_w_rd == load_rd[i])) begin  
                  if (tb_w_data !== load_expected[i]) begin  
                     $error("LOAD/WB MISMATCH rd=x%0d addr=0x%08h: expected 0x%08h, got 0x%08h",
                            tb_w_rd, load_addresses[i], load_expected[i], tb_w_data);  
                  end else begin
                     $display("PASS: LOAD/WB rd=x%0d <- 0x%08h (addr=0x%08h)",
                              tb_w_rd, tb_w_data, load_addresses[i]); 
                  end
                  load_w_pending[i] = 1'b0; 
                  break; 
               end
            end
         end
		
         // Register snapshot
         if ((cycle % 5) == 0 && cycle > 0) begin
            $display("\n--- RF Snapshot (Cycle %0d) ---", cycle);
            $display("x1=0x%h, x2=0x%h, x3=0x%h, x5=0x%h",
                     fdxmw_top1.decode1.rf1.RF[1], fdxmw_top1.decode1.rf1.RF[2],
                     fdxmw_top1.decode1.rf1.RF[3], fdxmw_top1.decode1.rf1.RF[5]);
            if (cycle >= 15)
               $display("x8=0x%h, x9=0x%h",
                        fdxmw_top1.decode1.rf1.RF[8], fdxmw_top1.decode1.rf1.RF[9]);
         end
      end

      // Final Checks
      $display("\n--- STORE SUMMARY ---");
      for (k = 0; k < store_count; k++) begin
         a = store_addresses[k];
         w = dmem_word(a);
         $display("DMEM[0x%08h] = 0x%08h (expected 0x%08h)", a, w, store_data[k]);
      end

      $display("\n--- LOAD SUMMARY ---");
      for (k = 0; k < load_count; k++) begin
         $display("LOAD[%0d]: addr=0x%08h f3=0x%0h expected=0x%08h (verify @ C%0d)",
                  k, load_addresses[k], load_func3[k], load_expected[k], load_ready[k]);
      end

      $display("\nTest Complete");
      $finish;	
   end

endmodule : pp_tb
// synthesis translate_onL