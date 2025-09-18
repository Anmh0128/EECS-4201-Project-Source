`include "constants.svh"

module dmemory #(
	parameter int MEM_DEPTH = 1024,                                
	parameter logic DATA_WIDTH = 32,
	parameter int MEM_WORDS = 1024
) (
	// Inputs
	input logic clk,
	input logic rst,
	input logic [DWIDTH - 1:0] addr,        // Address input
	input logic [DWIDTH - 1:0] data_in,     // Data to be written
	input logic read_en,                    // Read enable
	input logic write_en,                   // Write enable

	// Outputs
	output logic [DWIDTH - 1:0] data_out    // Data output
);

	logic [7:0] main_memory [0:MEM_DEPTH-1];  // Byte-addressable memory
//  logic [DWIDTH - 1:0] temp_memory [0:MEM_DEPTH]; 

	// Initialize memory contents
	initial begin
		for (int i = 0; i < MEM_DEPTH; i++) begin
			main_memory[i] = 8'h00;
		end
		$display("DMEMORY: Initialized %0d bytes of data memory", MEM_DEPTH);
	end

	// Combinational read logic
	always_comb begin
		if (addr >= MEM_DEPTH - 3 || addr[31]) begin
			data_out = ZERO;
			$display("DMEMORY: Out-of-bounds read access at address 0x%h", addr);
		end else if (read_en) begin
			data_out = {main_memory[addr + 3],
							main_memory[addr + 2],
							main_memory[addr + 1],
							main_memory[addr]};
		end else begin
			data_out = ZERO;
		end
	end

	// Sequential write logic
	always_ff @(posedge clk) begin
		if (write_en) begin
			if (addr < MEM_DEPTH - 3 && !addr[31]) begin
				main_memory[addr]     <= data_in[7:0];
				main_memory[addr + 1] <= data_in[15:8];
				main_memory[addr + 2] <= data_in[23:16];
				main_memory[addr + 3] <= data_in[31:24];
				$display("DMEMORY: Wrote 0x%h to address 0x%h", data_in, addr);
			end else begin
			$display("DMEMORY: Attempted write out-of-bounds at address 0x%h", addr);
			end
		end
	end

	
endmodule : dmemory
