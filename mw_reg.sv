`include "constants.svh"

module mw_reg(
    	// inputs
    	input logic clk,
    	input logic rst,
		
		// control 
		input logic stall,
		input logic flush,
		
		// inputs from memory
		input logic in_valid,
		input logic [DWIDTH - 1:0] pc_in,
    	input logic [DWIDTH - 1:0] alu_result_in,
   	input logic [DWIDTH - 1:0] mem_data_in,
   	input logic [4:0] rd_in,
    	input logic regW_in,
		input logic [1:0]WBSel_in,
    
    	// outputs to writeback
		output logic out_valid,
    	output logic [DWIDTH - 1:0] pc_out,
    	output logic [DWIDTH - 1:0] alu_result_out,
    	output logic [DWIDTH - 1:0] mem_data_out,
    	output logic [4:0] rd_out,
    	output logic regW_out,
		output logic [1:0]WBSel_out
);

    	always_ff @(posedge clk or posedge rst) begin
        	if (rst) begin
            out_valid      <= 1'b0;
				pc_out        <= ZERO_DW;
				mem_data_out   <= ZERO_DW;
				alu_result_out <= ZERO_DW;
				rd_out         <= '0;
				regW_out       <= 1'b0;
				WBSel_out      <= 2'b00;
        	end else if (flush) begin
            out_valid      <= 1'b0;
				pc_out         <= ZERO_DW;
				mem_data_out   <= ZERO_DW;
				alu_result_out <= ZERO_DW;
				rd_out         <= '0;
				regW_out       <= 1'b0;
				WBSel_out      <= 2'b00;
        	end else if (!stall) begin
				out_valid      <= in_valid;
				pc_out        <= pc_in;
				mem_data_out   <= mem_data_in;
				alu_result_out <= alu_result_in;
				rd_out         <= rd_in;
				regW_out       <= regW_in;
				WBSel_out      <= WBSel_in;
			end
			// else: stall
    	end

endmodule : mw_reg
