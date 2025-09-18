`include "constants.svh"

module execute(
	// inputs
	input logic clk,
	input logic rst,
	input logic [DWIDTH - 1:0] pc_in,
	input logic [DWIDTH - 1:0] rf_rs1,		// data from rf
	input logic [DWIDTH - 1:0] rf_rs2,		// data from rf
	input logic [DWIDTH - 1:0] imm,
	input logic [4:0] rd,
	input logic [6:0] opcode,
	input logic [2:0] func3,
	
	// control logic inputs
	input logic ASel,
	input logic BSel,
	input logic [3:0] ALUSel,
	
	input logic memR_in,
	input logic memW_in,
	input logic regW_in,
	
	// outputs
	output logic [DWIDTH - 1:0] pc_out,
   output logic [DWIDTH - 1:0] alu_result,
  	output logic [DWIDTH - 1:0] rs2_out,
   output logic [4:0] rd_out,
	output logic [2:0] func3_out,
	output logic memR,
	output logic memW,
	output logic regW,
	
	// branch outputs
	output logic branch_taken,
	output logic [DWIDTH-1:0] branch_target
);
	// pass-throughs
	assign pc_out = pc_in;
	assign rd_out = rd;
	assign rs2_out = rf_rs2;
	assign func3_out = func3;
	assign memR = memR_in;
	assign memW = memW_in;
	assign regW = regW_in;
	
	// ALU
	logic [DWIDTH - 1:0] alu_input1;
	logic [DWIDTH - 1:0] alu_input2;

	// operand muxes
	always_comb begin
		alu_input1 = (ASel) ? pc_in : rf_rs1;
		alu_input2 = (BSel) ? imm : rf_rs2;
	end
	
	logic is_branch;
	logic is_jal;
	logic is_jalr;
	
	assign is_branch = (opcode == BTYPE);
	assign is_jal = (opcode == JALJTYPE);
	assign is_jalr = (opcode == JALRJTYPE);

	// branch comparators
	logic eq_en, lt_en;
	logic brun_en;
	
	branchcond branchcond1 (
		.brun_en (brun_en),  
		.op1 (rf_rs1),
		.op2 (rf_rs2),
		.breq_en (eq_en),
		.brlt_en (lt_en)
	);

	assign brun_en = is_branch && ((func3 == 3'b110) || (func3 == 3'b111)); //BLTU/BGEU
	
	logic [DWIDTH-1:0] target_b, target_jal, target_jalr, sum_jalr;
	
	assign target_b = pc_in + imm;             // B-type
	assign target_jal = pc_in + imm;             // JAL
	assign sum_jalr = rf_rs1 + imm;
	assign target_jalr = {sum_jalr[DWIDTH-1:1], 1'b0}; // JALR
	
	logic take_b, take_jal, take_jalr;

	always_comb begin
		take_b = 1'b0;
		take_jal = is_jal;
		take_jalr = is_jalr;
		
		if (is_branch) begin
			unique case (func3)
				BEQ : take_b = eq_en;
				BNE : take_b = ~eq_en;
				BLT : take_b = lt_en;   
				BGE : take_b = ~lt_en;   
				BLTU : take_b = lt_en;  
				BGEU : take_b = ~lt_en;  
				default : take_b = 1'b0;
			endcase
		end
	end
	
	assign branch_taken = take_b | take_jal | take_jalr;
	assign branch_target = take_jal ? target_jal : take_jalr ? target_jalr : target_b;

	// ALU
	always_comb begin
		if (opcode == LUIUTYPE) begin
			alu_result = imm;                     // LUI: rd = imm_u
		end else begin
			unique case (ALUSel)
				ADD : alu_result = alu_input1 + alu_input2;
				SUB : alu_result = alu_input1 - alu_input2;
				AND : alu_result = alu_input1 & alu_input2;
				OR  : alu_result = alu_input1 | alu_input2;
				XOR : alu_result = alu_input1 ^ alu_input2;
				SLL : alu_result = alu_input1 <<  alu_input2[4:0];
				SRL : alu_result = alu_input1 >>  alu_input2[4:0];
				SRA : alu_result = $signed(alu_input1) >>> alu_input2[4:0];
				SLT : alu_result = ($signed(alu_input1) <  $signed(alu_input2)) ? 32'b1 : 32'b0;
				SLTU: alu_result = (alu_input1 <  alu_input2) ? 32'b1 : 32'b0;
				default: alu_result = alu_input1 + alu_input2;
			endcase
		end
	end
    

	
endmodule : execute