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
 * clk:    The clock used to drive the instruction
 * clk_en: Used as an additional enable of the clock driver
 * reset:  Used to reset the state of the instruction
 * start:  Used to indicate the beginning of an instruction
 *
 * dataa:  A 32-bit input value to be used with the instruction
 * datab:  A 32-bit input value to POSSIBLY be used with the instruction
 *
 * n:      The selection input used to identify the task of the instruction
 *
 * Output
 * ------
 *
 * done:   Used to indicate that the instruction has finished and the output
 *         of the instruction is now valid
 * result: A 32-bit output value returned as a result of the instruction's
 *         completion
 *
 * Instruction Selection
 * ---------------------
 *
 * 0:      Indicates that the base value is being loaded and appends the input
 *         dataa and datab to the existing base message
 *
 *         dataa: The left 32 bits to append
 *         datab: The right 32 bits to append
 *
 *         Return value is a "don't care" of 32 bits
 *
 * 1:      Indicates that the base value is complete, loads the target, and
 *         starts process to find a collision
 *
 *         dataa: The target value to use for this collision search 
 *         datab: UNUSED
 *
 *         Return value is a "don't care" of 32 bits
 *
 * 2:      Retrieves the last collision found
 *
 *         dataa: UNUSED
 *         datab: UNUSED
 *
 *         Return  value is the 32-bit counter value used for the collision
 *
 * 3:      Returns whether or not the most recent collision search has found
 *         a collision
 *
 *         dataa: UNUSED
 *         datab: UNUSED
 *
 *         Return value is "1" if found and "0" if not
 *
 * 4:      Returns the number of SHA-1 digests computed thus far
 *
 *         dataa: UNUSED
 *         datab: UNUSED
 */
module CollisionInstruction(
    clk, clk_en, reset, start,  // Execution inputs
    dataa, datab,               // Data inputs
    n,                          // Instruction selection inputs
    done, result                // Instruction outputs
);

// ============================================================================
// = INPUTS/OUTPUTS
// ============================================================================
input         clk;
input         clk_en;
input         reset;
input         start;

input [31:0]  dataa;
input [31:0]  datab;

input [2:0]   n;

output        done;
output [31:0] result;

// ============================================================================
// = CONSTANT PARAMETERS
// ============================================================================

// Efficiency scaling parameters (increase the number of searchers we have)
parameter       TOTAL_SEARCHERS             = 1;
parameter       SEARCH_CHUNK                = 32'hFFFFFFFF / TOTAL_SEARCHERS;

// Types associated with the selection bits
parameter [2:0] TYPE_BASE_ADDRESS           = 3'd0;
parameter [2:0] TYPE_START_SEARCH           = 3'd1;
parameter [2:0] TYPE_RETRIEVE_COLLISION     = 3'd2;
parameter [2:0] TYPE_HAS_FOUND_COLLISION    = 3'd3;
parameter [2:0] TYPE_RETRIEVE_TOTAL_DIGESTS = 3'd4;

// ============================================================================
// = INTERNAL WIRES/REGISTERS
// ============================================================================

// Clock/clock_enable combined
wire            wClock;

// Custom start signals for our message accumulator and searchers
wire            wMessageStart;
wire            wSearchStart;

// Output of the message collector
wire [511:0]    wMessage;

// Outputs of collision searchers
wire [31:0]     wDigestsComputed    [0:TOTAL_SEACHERS-1];
wire            wSearchDone         [0:TOTAL_SEACHERS-1];
wire [31:0]     wSearchResult       [0:TOTAL_SEACHERS-1];

// Represents the collective status of the search progress
wire            wAnyDone;

// ============================================================================
// = WIRE ASSIGNMENTS
// ============================================================================

// Combine clock and clock enable for real clock signal
assign wClock   = clk & clk_en;

// Only enable start signal for message if instruction is that of message
assign wMessageStart = (n == TYPE_BASE_ADDRESS) & start;

// Only enable start signal for searchers if instruction is that of searching
assign wSearchStart = (n == TYPE_START_SEARCH) & start;

// Combine all done signals to see if any searcher has finished
assign wAnyDone = (| wSearchDone);

// Passing on the instruction does not take any time, so we can simply say we
// are finished when we get the start bit
assign done     = start;

// Result is assigned to a value based on the selection bits, indicating what we
// would want to return
assign result   = (n == TYPE_BASE_ADDRESS)              ? 32'd1         :
                  (n == TYPE_EXECUTE)                   ? 32'd1         :
                  (n == TYPE_RETRIEVE_COLLISION)        ? rSearchResult :
                  (n == TYPE_HAS_FOUND_COLLISION)       ? rHasCollision :
                  (n == TYPE_RETRIEVE_TOTAL_DIGESTS)    ? rDigests      :
                                                          32'd0;

// ============================================================================
// = MODULE ASSIGNMENTS
// ============================================================================

MessageCollector MESSAGE_COLLECTOR (
    .clk(wClock), .reset(reset), 
    
    // Only send a start pulse if the instruction type indicates that we are
    // loading new data into the collector
    .start(wMessageStart),
    
    // Instruction inputs dataa and datab should be used as the collector words
    .a(dataa), .b(datab),
    
    .message(wMessage)
);

generate
    genvar i;
    for (i = 0; i < TOTAL_SEARCHERS; i = i + 1) begin :SEARCHER_GENERATION
        CollisionSearcher COLLISION_SEARCHER(
            .clk(wClock), 
            
            // Custom reset for the searchers, so that all will stop searching 
            // after a collision is found
            .reset(reset | wAnyDone),
            
            // Only send a start pulse if the instruction type indicates a
            // search should be started
            .start(wSearchStart),
            
            // The target data should be found in dataa for starting a search
            .target(dataa), 
            
            // The message comes from the accumulation made from earlier
            // base message instruction calls
            .message(wMessage),

            // To parallelize the search, start each searcher at a different
            // position in the counter (evenly spaced)
            .counter(i * SEARCH_CHUNK),
            
            .digests_computed(wDigestsComputed[i]),
            .done(wSearchDone[i]), 
            .result(wSearchResult[i])
        );
    end
endgenerate

endmodule
