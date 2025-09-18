`include "constants.svh"

module writeback(
    // inputs
    input  logic clk,
    input  logic rst,
    input  logic [DWIDTH-1:0] pc_in,
    input  logic [DWIDTH-1:0] alu_result,
    input  logic [DWIDTH-1:0] data_in,
    input  logic [4:0] rd_in,
    input  logic regW_in,
    input  logic [1:0] WBSel,

    // outputs
    output logic [DWIDTH-1:0] pc_out,
    output logic [DWIDTH-1:0] data_out,
    output logic [4:0] rd_out,
    output logic regW_out
);

    // pass-throughs
    assign pc_out = pc_in;
    assign rd_out = rd_in;
    assign regW_out = regW_in;

    // writeback mux
    logic [DWIDTH-1:0] pc_4;
    assign pc_4 = pc_in + WORDSIZE;

    always_comb begin
        // default: ALU
        data_out = alu_result;
        case (WBSel)
            2'b00: data_out = alu_result; // ALU result
            2'b01: data_out = data_in;    // Data memory
            2'b10: data_out = pc_4;       // PC + 4 
            default: /* ALU */;
        endcase
    end

endmodule : writeback