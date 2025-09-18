`include "constants.svh"

module fd_reg(
	// input 
	input logic clk,
	input logic rst,
	
	// input control
	input logic stall,
	input logic flush,
	
	// from fetch
	input logic [DWIDTH - 1:0] pc_in,
	input logic [DWIDTH - 1:0] inst_in,
	input logic [DWIDTH - 1:0] pc4_in,
	input logic in_valid,
	
	// output to decode
	output logic [DWIDTH - 1:0] pc_out,
	output logic [DWIDTH - 1:0] inst_out,
	output logic [DWIDTH - 1:0] pc4_out,
	output logic out_valid
);


  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      out_valid <= 1'b0;
      pc_out <= ZERO_DW;
      inst_out <= NOP;
      pc4_out <= ZERO_DW;
    end else if (flush) begin
      out_valid <= 1'b0;
      inst_out <= NOP;
      pc_out <= ZERO_DW;
      pc4_out <= ZERO_DW;
    end else if (!stall) begin
      out_valid <= in_valid;
      pc_out <= pc_in;
      inst_out <= inst_in;
      pc4_out <= pc4_in;
    end
    // else: stall
  end

endmodule : fd_reg
		