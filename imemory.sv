// imemory, which is the instruction memory, models a byte-addressable memory block, used in a processor to store and retrieve instructions

`define MEM_PATH "memory_file.mem"
`include "constants.svh"

module imemory #(
  // parameters
  parameter int MEM_DEPTH = 1024,   // Total bytes in this memory module
  parameter int LINE_COUNT = 256   // Number of 32-bit words to load initially
) (
  // inputs
  input logic clk,
  input logic rst,
  input logic [31:0] addr,       // Input address from outside the module
  input logic [31:0] data_in,    // Data to write
  input logic read_en,		 // Read enable
  input logic write_en,		 // Write enable
  // outputs
  output logic [31:0] data_out  // Instruction output
);

  logic [31:0] temp_memory [0:LINE_COUNT-1]; // Holds 32-bit words from file
  logic [7:0] main_memory [0:MEM_DEPTH-1];  // Byte-addressable memory
  logic [31:0] pc = ZERO;

  initial begin
    $readmemh(`MEM_PATH, temp_memory);

    // Load data from temp_memory into main_memory
    for (int i = 0; i < LINE_COUNT; i++) begin
      main_memory[pc]     = temp_memory[i][7:0];
      main_memory[pc + 1] = temp_memory[i][15:8];
      main_memory[pc + 2] = temp_memory[i][23:16];
      main_memory[pc + 3] = temp_memory[i][31:24];
      pc = pc + 4;
    end
      $display("IMEMORY: Loaded %0d 32-bit words from %s", LINE_COUNT, `MEM_PATH);
		$display("Main Memory Content %p", main_memory);
  end
  


  // Combinational logic for reading data based on the input 'addr'
  always_comb begin
    if (addr >= MEM_DEPTH - 3 || addr[31]) begin
        data_out = 32'hdead_beef; // Return a default/error value for out-of-bounds access
        $display("IMEMORY: Out-of-bounds access at address 0x%h, returning 0x%h", addr, data_out);
    end else begin
        // Reconstruct 32-bit word from 4 bytes 
        data_out = {main_memory[addr + 3],
                    main_memory[addr + 2],
                    main_memory[addr + 1],
                    main_memory[addr]};
    end
  end

  // Synchronous logic for writing data to memory
  always_ff @(posedge clk) begin
    if (write_en) begin // If write enable is high
      if (addr < MEM_DEPTH - 3 && !addr[31]) begin
          // Write 32-bit data byte-wise
          main_memory[addr]     <= data_in[7:0];
          main_memory[addr + 1] <= data_in[15:8];
          main_memory[addr + 2] <= data_in[23:16];
          main_memory[addr + 3] <= data_in[31:24];
          $display("IMEMORY: Wrote 0x%h to address 0x%h", data_in, addr);
      end else begin
          $display("IMEMORY: Attempted write out-of-bounds at address 0x%h", addr);
      end
    end
  end

endmodule : imemory