`include "constants.svh"

module fetch(
	// inputs
	input logic clk,
	input logic rst,
	
	input logic PCSel,
	input logic [DWIDTH - 1:0] pc_target,
	
	// stall
	input logic stall,
	
	// outputs	
	output logic [DWIDTH - 1:0] addr_out,
	output logic [DWIDTH - 1:0] pc_now
);
 	logic [DWIDTH - 1:0] pc;
	logic [DWIDTH - 1:0] pc_next;
	
	// combinational logic for branch
	always_comb begin
		pc_next = PCSel ? pc_target : (pc + WORDSIZE);
	end
	
	// sequential logic for choosing pc + 4 or target
	always_ff @(posedge clk or posedge rst) begin
		if (rst) begin 
			pc <= ZERO; // Reset PC to 0
		end else if (stall) begin
			pc <= pc; 
		end else begin
			pc <= pc_next;
		end
	end
	
	assign addr_out = pc;
	assign pc_now = pc;
	
	
endmodule : fetch