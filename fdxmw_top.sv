`include "constants.svh"

module fdxmw_top (
	// inputs
	input logic clk,
	input logic rst,
		
	//outputs	
   output logic        t_stallF,
   output logic        t_stallD,
   output logic        t_stallX,
   output logic        t_stallM,
   output logic        t_stallW,
   output logic        t_flushD,
   output logic        t_flushX,
   output logic [1:0]  t_fwdA,
	output logic [1:0]  t_fwdB
);

   // imemory signals
	logic [DWIDTH - 1:0] imem_addr;
	logic [DWIDTH - 1:0] imem_in;
	logic [DWIDTH - 1:0] imem_out;
	logic imemR;
	logic imemW;
	
	// Fetch signals
	logic [DWIDTH - 1:0] f_pc;
	logic [DWIDTH - 1:0] f_inst;
	logic [DWIDTH - 1:0] f_pc_now;
	
	// Fetch/Decode Register signals
	logic [DWIDTH - 1:0] fd_pc;
	logic [DWIDTH - 1:0] fd_inst;
	logic [DWIDTH - 1:0] fd_pc4;
	
	// Decode Signals
	logic [4:0] d_rs1, d_rs2, d_rd;
	logic [DWIDTH - 1:0] d_imm;
	logic [6:0] d_opcode;
	logic [2:0] d_func3;
	logic [6:0] d_func7;
	logic [DWIDTH - 1:0] d_pc;
	logic [DWIDTH - 1:0] d_rs1_data, d_rs2_data;
	logic d_memR, d_memW, d_regW;
	
	// decode control
	logic d_PCSel;
	logic [2:0] d_ImmSel;
	logic d_ASel, d_BSel;
	logic [3:0] d_ALUSel;
	logic [1:0] d_WBSel;
	
	// Register file Signals
	logic [DWIDTH - 1:0] rf_rs1, rf_rs2;
	
	// Decode/Execute Signals
	logic dx_regW, dx_memR, dx_memW;
	logic [DWIDTH - 1:0] dx_pc, dx_rs1, dx_rs2, dx_imm;
	logic [4:0] dx_rd;
	logic [6:0] dx_opcode;
	logic [2:0] dx_func3;
	logic [6:0] dx_func7;
	logic dx_ASel, dx_BSel;
	logic [3:0] dx_ALUSel;
	logic [1:0] dx_WBSel;
	
	// Execute Signals
	logic [DWIDTH - 1:0] x_pc_out, x_alu_result, x_rs2_out;
	logic [4:0] x_rd_out;
	logic [2:0] x_func3_out;
	logic x_memR, x_memW, x_regW;
	// Branch Signals
	logic x_branch_taken;
	logic [DWIDTH-1:0] x_branch_target;
	
	// Execute/Memory Signals
	logic [DWIDTH - 1:0] xm_pc, xm_alu_result, xm_rs2;
	logic [4:0] xm_rd;
	logic [2:0] xm_func3;
	logic xm_memR, xm_memW, xm_regW;
	logic [1:0] xm_WBSel;
	
	// Memory Signals
	logic [DWIDTH - 1:0] m_pc, m_mem_data_out, m_alu_result_out;
	logic [4:0] m_rd_out;
	logic m_regW_out;

	// Memory/Writeback
   logic [DWIDTH - 1:0] mw_pc, mw_alu_result, mw_mem_data;
   logic [4:0] mw_rd;
   logic mw_regW;
	logic [1:0] mw_WBSel;

   // Writeback
   logic [DWIDTH - 1:0] w_write_data, w_pc_out;
   logic [4:0] w_rd_out;
   logic w_regW_out;
	
	// valid registers
	logic fd_v, dx_v, xm_v, mw_v;
	// Hazard & Forwarding additions
	logic stallF, stallD, stallX, stallM, stallW;
	logic flushD, flushX;
	logic [1:0] fwdA, fwdB;
	logic [4:0] dx_rs1_idx, dx_rs2_idx;
	logic [DWIDTH - 1:0] x_rs1, x_rs2;

	always_ff @(posedge clk or posedge rst) begin
		if (rst) begin
			dx_rs1_idx <= '0;
			dx_rs2_idx <= '0;
		end else if (!stallD) begin
			dx_rs1_idx <= d_rs1;
			dx_rs2_idx <= d_rs2;
		end
	end
	
	imemory #(
		.MEM_DEPTH(1024),
		.LINE_COUNT(64)
	) imemory1 (
		.clk (clk),
		.rst (rst),
		.addr (imem_addr),
		.data_in (imem_in),
		.data_out (imem_out),
		.read_en (imemR),
		.write_en (imemW)
	);
	
	assign imem_in = '0;
	assign imemR = 1'b1;
	assign imemW = 1'b0;

	// Fetch
	// Hazard & Forwarding
	hazard_unit hz1 (
		.d_ASel(d_ASel),
		.d_BSel(d_BSel),
		.d_rs1(d_rs1),
		.d_rs2(d_rs2),
		.x_memR(dx_memR),
		.x_rd(dx_rd),
		.branch_taken(x_branch_taken),
		.stallF(stallF),
		.stallD(stallD),
		.stallX(stallX),
		.stallM(stallM),
		.stallW(stallW),
		.flushD(flushD),
		.flushX(flushX)
	);

	forwarding_unit fwd1 (
	  .dx_rs1_idx(dx_rs1_idx),
	  .dx_rs2_idx(dx_rs2_idx),
	  .xm_regW(xm_regW),
	  .xm_memR(xm_memR),
	  .xm_rd(xm_rd),
	  .mw_regW(w_regW_out),
	  .mw_rd(w_rd_out),
	  .fwdA(fwdA),
	  .fwdB(fwdB)
	);
	
	always_comb begin
		x_rs1 = dx_rs1;
		x_rs2 = dx_rs2;
		unique case (fwdA)
			2'b10: x_rs1 = xm_alu_result;
			2'b01: x_rs1 = w_write_data;
			default: ;
		endcase
		unique case (fwdB)
			2'b10: x_rs2 = xm_alu_result;
			2'b01: x_rs2 = w_write_data;
			default: ;
		endcase
	end
	fetch fetch1 (
		.clk(clk),
		.rst(rst),
		//branch
		.PCSel(x_branch_taken),
		.pc_target(x_branch_target),
		.stall(stallF),
		.addr_out(imem_addr),
		.pc_now(f_pc_now)
	);
	
	assign f_pc = f_pc_now;
	assign f_inst = imem_out;
	
	// Fetch/Decode Register
	fd_reg fd_reg1 (
		.clk(clk),
		.rst(rst),
		.stall(stallF | stallD),
		.flush(flushD),
		.pc_in(f_pc),
		.inst_in(f_inst),
		.pc4_in(f_pc + WORDSIZE),
		.in_valid(1'b1),
		.pc_out(fd_pc),
		.inst_out(fd_inst),
		.pc4_out(fd_pc4),
		.out_valid(fd_v)
	);
	
	// Decode
	decode decode1 (
		.clk(clk),
		.rst(rst),
		.pc_in(fd_pc),
		.pc_out(d_pc),
		.inst(fd_inst),
		
		.rs1(d_rs1),
		.rs2(d_rs2),
		.rd(d_rd),
		.imm(d_imm),
		.opcode(d_opcode),
		.func3(d_func3),
		.func7(d_func7),
		.rf_rs1_data(rf_rs1),
		.rf_rs2_data(rf_rs2),
		.memR(d_memR),
		.memW(d_memW),
		.regW(d_regW),
		// writeback signals
		.w_regW(w_regW_out),
		.w_rd_in(w_rd_out),
		.w_data(w_write_data),
		// control signals
		.PCSel(d_PCSel),
		.ImmSel(d_ImmSel),
		.ASel(d_ASel),
		.BSel(d_BSel),
		.ALUSel(d_ALUSel),
		.WBSel(d_WBSel)
	);
	
	
	// Decode/Execute
	dx_reg dx_reg1 (
		.clk(clk),
		.rst(rst),
		.stall(stallX),
		.flush(flushX),
		.regW_in(d_regW),
		.memR_in(d_memR),
		.memW_in(d_memW),
		.in_valid(fd_v),
		.pc_in(d_pc),
		.pc4_in(fd_pc4),
		.rs1_in(rf_rs1_data),
		.rs2_in(rf_rs2_data),
		.imm_in(d_imm),
		.rd_in(d_rd),
		.opcode_in(d_opcode),
		.func3_in(d_func3),
		.func7_in(d_func7),
		.ASel_in(d_ASel),
		.BSel_in(d_BSel),
		.ALUSel_in(d_ALUSel),
		.WBSel_in(d_WBSel),
		
		.regW_out(dx_regW),
		.memR_out(dx_memR),
		.memW_out(dx_memW),
		.out_valid(dx_v),
		.pc_out(dx_pc),
		.pc4_out(),
		.rs1_out(dx_rs1),
		.rs2_out(dx_rs2),
		.imm_out(dx_imm),
		.rd_out(dx_rd),
		.opcode_out(dx_opcode),
		.func3_out(dx_func3),
		.func7_out(dx_func7),
		.ASel_out(dx_ASel),
		.BSel_out(dx_BSel),
		.ALUSel_out(dx_ALUSel),
		.WBSel_out(dx_WBSel)
	);
	
	// Execute 
	execute execute1 (
		.clk(clk),
		.rst(rst),
		.pc_in(dx_pc),
		.rf_rs1(x_rs1),
		.rf_rs2(x_rs2),
		.imm(dx_imm),
		.rd(dx_rd),
		.opcode(dx_opcode),
		.func3(dx_func3),
		.memR_in(dx_memR),
		.memW_in(dx_memW),
		.regW_in(dx_regW),
		// control signals
		.ASel(dx_ASel),
		.BSel(dx_BSel),
		.ALUSel(dx_ALUSel),
		// branch
		.branch_taken(x_branch_taken),
		.branch_target(x_branch_target),
		
		.pc_out(x_pc_out),
		.alu_result(x_alu_result),
		.rs2_out(x_rs2_out),
		.rd_out(x_rd_out),
		.func3_out(x_func3_out),
		.memR(x_memR),
		.memW(x_memW),
		.regW(x_regW)
	);

	// Execute/Memory Register
   xm_reg xm_reg1 (
      .clk(clk),
      .rst(rst),
		.stall(stallM),
		.flush(1'b0),
		.in_valid(dx_v),
      .pc_in(x_pc_out),
     	.alu_result_in(x_alu_result),
		.rs2_in(x_rs2_out),
      .rd_in(x_rd_out),
      .func3_in(x_func3_out),
      .memR_in(x_memR),
      .memW_in(x_memW),
      .regW_in(x_regW),
		.WBSel_in(dx_WBSel),
		
		.out_valid(xm_v),
      .pc_out(xm_pc),
      .alu_result_out(xm_alu_result),
		.rs2_out(xm_rs2),
      .rd_out(xm_rd),
      .func3_out(xm_func3),
      .memR_out(xm_memR),
      .memW_out(xm_memW),
      .regW_out(xm_regW),
		.WBSel_out(xm_WBSel)
   );
	
	logic [DWIDTH-1:0] xm_store_data;

	always_comb begin
	  xm_store_data = xm_rs2;
	  // forward from XM result
	  if (xm_regW && (xm_rd != '0) && (xm_rd == dx_rs2_idx)) begin
		 xm_store_data = xm_alu_result;
	  end
	  // or from WB
	  if (w_regW_out && (w_rd_out != '0) && (w_rd_out == dx_rs2_idx)) begin
		 xm_store_data = w_write_data;
	  end
	end

	// Memory Stage
   memory memory1 (
     	.clk(clk),
      .rst(rst),
      .pc_in(xm_pc),
      .alu_result(xm_alu_result),
      .rs2_in(xm_store_data),
      .rd_in(xm_rd),
      .func3_in(xm_func3),
      .memR(xm_memR),
      .memW(xm_memW),
      .regW_in(xm_regW),
		
      .pc_out(m_pc),
      .mem_data(m_mem_data_out),
      .alu_result_out(m_alu_result_out),
      .rd_out(m_rd_out),
      .regW_out(m_regW_out)
   );
    
   // Memory/Writeback Register
   mw_reg mw_reg1 (
      .clk(clk),
      .rst(rst),
		.stall(stallW),
		.flush(1'b0),
		.in_valid(xm_v),
      .pc_in(m_pc),
      .alu_result_in(m_alu_result_out),
      .mem_data_in(m_mem_data_out),
      .rd_in(m_rd_out),
      .regW_in(m_regW_out),
		.WBSel_in(xm_WBSel),
		
		.out_valid(mw_v),
      .pc_out(mw_pc),
      .alu_result_out(mw_alu_result),
      .mem_data_out(mw_mem_data),
      .rd_out(mw_rd),
      .regW_out(mw_regW),
		.WBSel_out(mw_WBSel)
   );
    
   // Writeback Stage
	writeback writeback1 (
      .clk(clk),
      .rst(rst),
      .pc_in(mw_pc),
      .alu_result(mw_alu_result),
      .data_in(mw_mem_data),
      .rd_in(mw_rd),
      .regW_in(mw_regW),
		// wbsel
		.WBSel(mw_WBSel),
      .pc_out(w_pc_out),
      .data_out(w_write_data),
      .rd_out(w_rd_out),
      .regW_out(w_regW_out)
   );

endmodule : fdxmw_top