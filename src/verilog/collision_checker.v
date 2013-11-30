/*
 * Written by Robert "Chip" Senkbeil
 *         on 11/28/2013
 * Version 1.0
 */

/**
 * This module checks for "collisions" by looking at X number of bits
 * represented by the provided target. The clock controls the updated
 * output of the checker.
 *
 * Input
 * -----
 *
 * iClk:    The clock used to update the internal register used to pipe output
 * iTarget: Used to indicate the amount of bits to check starting with the MSB
 *          and moving right (assuming big endian), needs to be in the format
 *          of 32-1. In other words, 0 means 1 bit, 31 means 32 bits of checking
 * iData:   The data whose first 32 bits to potentially check
 *
 * Output
 * ------
 *
 * oResult: The result of the check with 0 being no collision and 1 being a
 *          collision
 */
module CollisionChecker (
    iClk, iTarget, iData,
    oResult
);

// =============================================================================
// = INPUTS/OUTPUTS
// =============================================================================
input         iClk;
input [4:0]   iTarget; // Supports up to 32 bits, but needs to be 0 to 31
input [159:0] iData;
output        oResult;

// =============================================================================
// = INTERNAL WIRES/REGISTERS
// =============================================================================
wire [31:0] wResult;
reg rResult;
genvar i;

// =============================================================================
// = LOGIC
// =============================================================================
assign oResult = rResult;

//
// Setup the 32-bit check for zeros as the MSBs of the incoming data.
//
assign wResult[0] = ~iData[159];
generate
	for (i = 1; i < 32; i = i + 1) begin : AND_FOR_LOOP
		 assign wResult[i] = wResult[i-1] & ~iData[159-i];
	end
endgenerate

//
// Sync the results with the clock, which should be the oReady output from the
// SHA-1 module connected.
//
always @(posedge iClk) begin
    rResult <= wResult[iTarget];
end

endmodule
