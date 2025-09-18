`include "constants.svh"

module memory(
	//inputs
	input logic clk,
	input logic rst,
	input logic [DWIDTH - 1:0] pc_in,
   input logic [DWIDTH - 1:0] alu_result,
   input logic [DWIDTH - 1:0] rs2_in,
   input logic [4:0] rd_in,
  	input logic [2:0] func3_in,
   input logic memR,
   input logic memW,
   input logic regW_in,
	
	// outputs
   output logic [DWIDTH - 1:0] pc_out,
   output logic [DWIDTH - 1:0] alu_result_out,
  	output logic [DWIDTH - 1:0] mem_data,
   output logic [4:0] rd_out,
   output logic regW_out,
	
	// data memory instance
	output logic [DWIDTH - 1:0] dmem_addr,
	output logic [DWIDTH - 1:0] dmem_in,
	output logic [DWIDTH - 1:0] dmem_out,
	output logic dmem_read_en,
	output logic dmem_write_en	
);

	assign dmem_addr = alu_result;
	assign dmem_in = rs2_in;
	assign dmem_read_en = memR;
	assign dmem_write_en = memW;

	assign pc_out = pc_in;
   assign alu_result_out = alu_result;
  	assign rd_out = rd_in;
   assign regW_out = regW_in;

	
	assign mem_data = memR ? dmem_out : alu_result;
	
	dmemory #(
		.MEM_DEPTH(1024),
		.DATA_WIDTH(32),
		.MEM_WORDS(1024)
	) dmemory1 (
		.clk(clk),
		.rst(rst),
		.addr(dmem_addr),
		.data_in(dmem_in),
		.data_out(dmem_out),
		.read_en(dmem_read_en),
		.write_en(dmem_write_en)
	);
endmodule : memory
