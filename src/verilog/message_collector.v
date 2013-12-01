/*
 * Written by Robert "Chip" Senkbeil
 *         on 11/30/2013
 * Version 1.1
 */
 
/**
 * This module provides the interface for the Nios II custom instruction for
 * collision checks. It is an extended instruction, meaning that it can perform
 * several different tasks based on a selection input.
 *
 * Input
 * -----
 *
 * clk:    The clock used to drive the collector
 * reset:  Used to reset the contents of the collector
 * start:  Used to indicate that two 32-bit inputs should be collected
 *
 * a:  A 32-bit input value to be collected
 * b:  A 32-bit input value to be collected
 *
 * Output
 * ------
 *
 * message: The 512-bit message currently stored within the collector
 *
 */
module MessageCollector(
    clk, reset, start,  // Execution inputs
    a, b,               // Data inputs
    message             // Instruction outputs
);

// ============================================================================
// = INPUTS/OUTPUTS
// ============================================================================

input               clk;
input               reset;
input               start;

input       [31:0]  a;
input       [31:0]  b;

output reg  [511:0] message;

// ============================================================================
// = LOGIC
// ============================================================================

always @(posedge clk, posedge reset) begin
    if (reset) begin
        message <= 512'b0;
    end else if (start) begin
        message <= {message[447:0], a, b};
    end
end

endmodule
