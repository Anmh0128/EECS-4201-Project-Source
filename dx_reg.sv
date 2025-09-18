`include "constants.svh"

module dx_reg(
	// inputs
	input logic clk,
	input logic rst,
	
	// control
	input logic stall,
	input logic flush,
	
	// inputs from decode
	input logic in_valid,
	input logic [DWIDTH - 1:0] pc_in,
	input logic [DWIDTH - 1:0[ pc4_in,
	input logic [DWIDTH - 1:0] rs1_in,
	input logic [DWIDTH - 1:0] rs2_in,
	input logic [DWIDTH - 1:0] imm_in,
	input logic [4:0] rd_in,
	input logic [6:0] opcode_in,
	input logic [2:0] func3_in,
	input logic [6:0] func7_in,
	
	// control logic inputs
	input logic ASel_in,
	input logic BSel_in,
	input logic [3:0] ALUSel_in,
	input logic [1:0] WBSel_in,
	input logic regW_in,
	input logic memR_in,
	input logic memW_in,
	
	// outputs to execute
	output logic out_valid,
	output logic [DWIDTH - 1:0] pc_out,
	output logic [DWIDTH - 1:0] pc4_out,
	output logic [DWIDTH - 1:0] rs1_out,
	output logic [DWIDTH - 1:0] rs2_out,
	output logic [DWIDTH - 1:0] imm_out,
	output logic [4:0] rd_out,
	output logic [6:0] opcode_out,
	output logic [2:0] func3_out,
	output logic [6:0] func7_out,
	
	// control logic outputs
	output logic ASel_out,
	output logic BSel_out,
	output logic [3:0] ALUSel_out,
	output logic [1:0] WBSel_out,
	output logic regW_out,
	output logic memR_out,
	output logic memW_out
);
	
	always_ff @(posedge clk or posedge rst) begin
		if (rst) begin
			out_valid 	<= 1'b0;
			pc_out 		<= ZERO_DW;
			pc4_out 		<= ZERO_DW;
			rs1_out 		<= ZERO_DW;
			rs2_out		<= ZERO_DW;
			imm_out     <= ZERO_DW;
			rd_out      <= '0;
			opcode_out  <= '0;
			func3_out   <= '0;
			func7_out   <= '0;
			ASel_out    <= 1'b0;
			BSel_out    <= 1'b0;
			ALUSel_out  <= ADD;
			memR_out    <= 1'b0;
			memW_out    <= 1'b0;
			regW_out    <= 1'b0;
			WBSel_out   <= 2'b00;
		end else if (flush) begin
			out_valid   <= 1'b0;
			pc_out      <= ZERO_DW;
			pc4_out     <= ZERO_DW;
			rs1_out		<= ZERO_DW;
			rs2_out		<= ZERO_DW;
			imm_out     <= ZERO_DW;
			rd_out      <= '0;
			opcode_out  <= '0;
			func3_out   <= '0;
			func7_out   <= '0;
			ASel_out    <= 1'b0;
			BSel_out    <= 1'b0;
			ALUSel_out  <= ADD;
			memR_out    <= 1'b0;
			memW_out    <= 1'b0;
			regW_out    <= 1'b0;
			WBSel_out   <= 2'b00;
         regW_out 	<= regW_in;
         memR_out 	<= memR_in;
         memW_out 	<= memW_in;
		end else if (!stall) begin
			out_valid	<= in_valid;
			pc_out      <= pc_in;
			pc4_out     <= pc_in + WORDSIZE;
			rs1_out		<= rs1_in;
			rs2_out		<= rs2_in;
			imm_out     <= imm_in;
			rd_out      <= rd_in;
			opcode_out  <= opcode_in;
			func3_out   <= func3_in;
			func7_out   <= func7_in;

			ASel_out    <= ASel_in;
			BSel_out    <= BSel_in;
			ALUSel_out  <= ALUSel_in;
			memR_out    <= memR_in;
			memW_out    <= memW_in;
			regW_out    <= regW_in;
			WBSel_out   <= WBSel_in;
		end
		// else : stall
	end
	
endmodule : dx_reg