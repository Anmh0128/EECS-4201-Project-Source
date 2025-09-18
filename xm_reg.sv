`include "constants.svh"

module xm_reg(
	// inputs
	input logic clk,
	input logic rst,
	
	// control 
	input logic stall,
	input logic flush,
    
   // Data signal inputs from execute
	input logic in_valid,
   input logic [DWIDTH - 1:0] pc_in,
	input logic [DWIDTH - 1:0] pc4_in,
   input logic [DWIDTH - 1:0] alu_result_in,
   input logic [DWIDTH - 1:0] rs2_in,
   input logic [4:0] rd_in,
   input logic [2:0] func3_in,
	
	// Control signal inputs
	input logic [1:0] WBSel_in,
   input logic regW_in,
   input logic memR_in,
   input logic memW_in,
    
	// Data signal outputs
	output logic out_valid,
   output logic [DWIDTH - 1:0] pc_out,
	output logic [DWIDTH - 1:0] pc4_out,
   output logic [DWIDTH - 1:0] alu_result_out,
   output logic [DWIDTH - 1:0] rs2_out,
   output logic [4:0] rd_out,
   output logic [2:0] func3_out,
	
	// Control signal outputs
	output logic [1:0] WBSel_out,
   output logic regW_out,
   output logic memR_out,
   output logic memW_out
);

	always_ff @(posedge clk or posedge rst) begin
		if (rst) begin
			out_valid      <= 1'b0;
			pc_out         <= ZERO_DW;
			pc4_out 			<= ZERO_DW;
			alu_result_out <= ZERO_DW;
			rs2_out        <= ZERO_DW;
			rd_out         <= '0;
			func3_out      <= '0;
			memR_out       <= 1'b0;
			memW_out       <= 1'b0;
			regW_out       <= 1'b0;
			WBSel_out      <= 2'b00;
		end else if (flush) begin
			out_valid      <= 1'b0;
			pc_out        	<= ZERO_DW;
			pc4_out 			<= ZERO_DW;
			alu_result_out <= ZERO_DW;
			rs2_out        <= ZERO_DW;
			rd_out         <= '0;
			func3_out      <= '0;
			memR_out       <= 1'b0;
			memW_out       <= 1'b0;
			regW_out       <= 1'b0;
			WBSel_out      <= 2'b00;
		end else if (!stall) begin
         out_valid      <= in_valid;
			pc_out         <= pc_in;
			pc4_out 			<= pc4_in;
			alu_result_out <= alu_result_in;
			rs2_out        <= rs2_in;
			rd_out         <= rd_in;
			func3_out      <= func3_in;
			memR_out       <= memR_in;
			memW_out       <= memW_in;
			regW_out       <= regW_in;
			WBSel_out      <= WBSel_in;
       end
		 // else: stall
	end

endmodule : xm_reg