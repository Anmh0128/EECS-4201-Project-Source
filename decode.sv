`include "constants.svh"

module decode(
	// inputs
	input logic clk,
	input logic rst,
	input logic [DWIDTH - 1:0] inst,		// Instruction in
	input logic [DWIDTH - 1:0] pc_in,		// PC in
	
	// writeback inputs
	input logic w_regW,
	input logic [4:0] w_rd_in,
	input logic [DWIDTH - 1:0] w_data,
	// outputs		
	output logic [DWIDTH - 1:0] pc_out, 		// PC out
	output logic [4:0] rs1,			// Source operand 1
	output logic [4:0] rs2,			// Source operand 2
	output logic [4:0] rd,			// Destination operand
	output logic [DWIDTH - 1:0] imm,		// Immediate
	output logic [6:0] opcode,		// Opcode
	output logic [2:0] func3,		
	output logic [6:0] func7,
	
	// register file outputs
	output logic [DWIDTH - 1:0] rf_rs1_data,
	output logic [DWIDTH - 1:0] rf_rs2_data,
	
	// Control signal outputs
	output logic memR,
	output logic memW,
	output logic regW,
	
	// control signals
	output logic PCSel,
	output logic [2:0] ImmSel,
	output logic ASel,
	output logic BSel,
	output logic [3:0] ALUSel,
	output logic [1:0] WBSel
);
	
	// Instruction assignments
	assign pc_out = pc_in;
	assign rs1 = inst[19:15];
	assign rs2 = inst[24:20];
	assign rd = inst[11:7];
	assign opcode = inst[6:0];
	assign func3 = inst[14:12];
	assign func7 = inst[31:25];
	
	logic rf_write_en;
	assign rf_write_en = w_regW & (w_rd_in != 5'd0);
	
	rf #(
		.DATAWIDTH(DWIDTH),
		.LOG2NUMREGS(5),
		.NUMREGS(32)
	) rf1 (
		.clk(clk),
		.rst(rst),
		.rs1(rs1),
		.rs1_en(1'b1),
		.rs2(rs2),
		.rs2_en(1'b1),
		.rd(w_rd_in),
		.rd_en(rf_write_en),
		.data_in(w_data),
		.rs1_data(rf_rs1_data),
		.rs2_data(rf_rs2_data)
	);
	
	
	wire [DWIDTH-1:0] imm_i = {{20{inst[31]}}, inst[31:20]};
	wire [DWIDTH-1:0] imm_s = {{20{inst[31]}}, {inst[31:25], inst[11:7]}};
	wire [DWIDTH-1:0] imm_b = {{19{inst[31]}}, {inst[31], inst[7], inst[30:25], inst[11:8], 1'b0}};
	wire [DWIDTH-1:0] imm_u = {inst[31:12], 12'b0};
	wire [DWIDTH-1:0] imm_j = {{11{inst[31]}}, {inst[31], inst[19:12], inst[20], inst[30:21], 1'b0}};

	
	always_comb begin
		// defaults
		PCSel = 1'b0;        // execute decide
		ASel = 1'b0;         // 0=rs1
		BSel = 1'b0;         // 0=rs2
		ALUSel = ADD;
		memR = 1'b0;
		memW = 1'b0;
		regW = 1'b0;
		WBSel = 2'b00;
		ImmSel = 3'd0;
		imm = '0;

    unique case (opcode)
      // R-type
      RTYPE: begin
        ASel = 1'b0;    // uses rs1
        BSel = 1'b0;    // uses rs2
        regW = 1'b1;
        WBSel = 2'b00;   // ALU
        unique case ({func7,func3})
          {7'b0000000,3'b000}: ALUSel = ADD;
          {7'b0100000,3'b000}: ALUSel = SUB;
          {7'b0000000,3'b111}: ALUSel = AND;
          {7'b0000000,3'b110}: ALUSel = OR;
          {7'b0000000,3'b100}: ALUSel = XOR;
          {7'b0000000,3'b001}: ALUSel = SLL;
          {7'b0000000,3'b101}: ALUSel = SRL;
          {7'b0100000,3'b101}: ALUSel = SRA;
          {7'b0000000,3'b010}: ALUSel = SLT;
          {7'b0000000,3'b011}: ALUSel = SLTU;
          default: ALUSel = ADD;
        endcase
      end

      // I-type 
      ITYPE: begin
        ASel = 1'b0;    // uses rs1
        BSel = 1'b1;    // uses imm
        imm = imm_i;   
		  ImmSel = 3'd0;
        regW = 1'b1;    
		  WBSel = 2'b00;
        unique case (func3)
          3'b000: ALUSel = ADD;   // ADDI
          3'b010: ALUSel = SLT;   // SLTI
          3'b011: ALUSel = SLTU;  // SLTIU
          3'b111: ALUSel = AND;   // ANDI
          3'b110: ALUSel = OR;    // ORI
          3'b100: ALUSel = XOR;   // XORI
          3'b001: ALUSel = SLL;   // SLLI
          3'b101: ALUSel = SRL;   // SRLI/SRAI 
          default: ALUSel = ADD;
        endcase
      end

      // Load WB = MEM
      LWITYPE: begin
        ASel = 1'b0;    // uses rs1
        BSel = 1'b1;    // uses imm
        imm = imm_i;   
		  ImmSel = 3'd0;
        ALUSel = ADD;
        memR = 1'b1;
        regW = 1'b1;    
		  WBSel = 2'b01; // memory
      end

      // Store no WB
      STYPE: begin
        ASel = 1'b0;    // uses rs1
        BSel = 1'b1;    // uses imm
        imm = imm_s;   
		  ImmSel = 3'd1;
        ALUSel = ADD;
        memW = 1'b1;
      end

      // Branch: compare rs1 vs rs2 in execute
      BTYPE: begin
        ASel = 1'b0;    // uses rs1
        BSel = 1'b0;    // uses rs2
        imm = imm_b;   
		  ImmSel = 3'd2; 
        // no mem, no wb
      end

      // LUI: rd = imm_u
      // Use ASel=1 (no rs1) and BSel=1 (imm)
      LUIUTYPE: begin
        ASel = 1'b1;    // NOT using rs1
        BSel = 1'b1;    // using imm
        imm = imm_u;   
		  ImmSel = 3'd3;
        ALUSel = ADD;
        regW = 1'b1;    
		  WBSel = 2'b00; // execute outputs imm
      end

      // AUIPC: rd = PC + imm_u
      AUIPCUTYPE: begin
        ASel = 1'b1;    // x_pc
        BSel = 1'b1;    //  imm
        imm = imm_u;   
		  ImmSel = 3'd3;
        ALUSel = ADD;
        regW = 1'b1;    
		  WBSel = 2'b00; // ALU
      end

      // JAL: rd = PC+4
      JALJTYPE: begin
        ASel = 1'b1;    // x_pc
        BSel = 1'b1;    // imm_j
        imm = imm_j;   
		  ImmSel = 3'd4;
        ALUSel = ADD;
        regW = 1'b1;    
		  WBSel = 2'b10; // PC+4
      end

      // JALR: rd = PC+4
      JALRJTYPE: begin
        ASel = 1'b0;    // uses rs1
        BSel = 1'b1;    // uses imm
        imm = imm_i;   
		  ImmSel = 3'd5;
        ALUSel = ADD;
        regW = 1'b1;    
		  WBSel = 2'b10; // PC+4
      end

      default: begin
			// default
      end
    endcase
  end
	// create a constant file that uses ITYPE instead of 7'b0010011
	// create tasks for like rs1, rs2, rd so I can just call it when I need it
	// create a design wrapper that will be exposed to public with inputs clk and rst 
	// codes should be named in the file called src(source)
	// don't forget to make notes
	// test benches should be located in a different folder
	// execute support AND, OR, XOR, SL, SR, ADD, SUB, SLT, LW, SW
	// execute 2 inputs one reset and one output
	// create register file for WB
	// create rf.sv (only talks to decode and writeback)
	// no branches for now
	// output of execute changes pc
	// [31:0] logic rf[RFNUM - 1:0]
	// Value = rf[rs1]
	// get the output from the register file to do the execute
	// go to the lecture notes and check the control paths	

endmodule : decode