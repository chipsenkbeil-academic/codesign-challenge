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

// Types associated with the selection bits
parameter       TYPE_BASE_ADDRESS           = 0;
parameter       TYPE_START_SEARCH           = 1;
parameter       TYPE_RETRIEVE_COLLISION     = 2;
parameter       TYPE_HAS_FOUND_COLLISION    = 3;
parameter       TYPE_RETRIEVE_TOTAL_DIGESTS = 4;

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
// NOTE: wSearchDone must NOT be a net array since we use a unary operation
//       on it!
wire [31:0]     wDigestsComputed    [0:TOTAL_SEARCHERS-1];
wire [TOTAL_SEARCHERS-1:0] wSearchDone; // ANNOYING THAT IT BREAKS OUR ALIGN
wire [31:0]     wSearchResult       [0:TOTAL_SEARCHERS-1];

// NOTE: This may be an unnecessarily-large expense, but couldn't think of
//       a better way to get just one result
wire [31:0]     wFilteredResult     [0:TOTAL_SEARCHERS-1];

// NOTE: This may be an unnecessarily-large expense, but couldn't think of
//       a better way to get a nice sum without making custom adders and
//       generating a lot of them
// Wires that keep track of the digest sum progressively
wire [31:0]     wDigestSum          [0:TOTAL_SEARCHERS-1];

// Represents the collective status of the search progress
wire            wAnyDone;

// Memory for our search results
reg [31:0]      rLastResult;        // Contains the last result acquired
reg             rSearching;         // Indicates whether currently searching
reg [31:0]      rTotalDigests;      // Indicates how many digests have been
                                    // calculated
reg             rAnyDone;           // Value of wAnyDone, used to provide a
                                    // clock cycle of delay before wiping our
                                    // searchers

// Simple wire to avoid Quartus confusing rAnyDone register as a clock
wire            wResetSearchers;
                                    
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

// Determine if searchers should be reset
assign wResetSearchers = (reset | rAnyDone);

// Only allow one result to be piped through if multiple searchers find a
// solution at the same time (we will use the lowest searcher's result)
generate
    genvar j;
    
    // Work backwards since we want to keep the result of the earliest searcher
    // who has acquired a collision
    for (j = TOTAL_SEARCHERS - 1; j >= 0; j = j - 1) begin :FILTER_GENERATION
        // 1. If the current searcher finished, we want to use that value since
        //    it is from an earlier searcher than the last value
        // 2. If the current searcher was the first to be checked, we want to
        //    return zero to provide a base value for the other filters
        // 3. Carry the previous accepted result forward
        assign wFilteredResult[j] = (wSearchDone[j]) ? wSearchResult[j] :
                                    (j == TOTAL_SEARCHERS - 1) ? 32'd0  :
                                    wFilteredResult[j + 1];
    end
endgenerate

// Passing on the instruction does not take any time, so we can simply say we
// are finished when we get the start bit
assign done     = start;

// Result is assigned to a value based on the selection bits, indicating what we
// would want to return
assign result   = (n == TYPE_BASE_ADDRESS)              ? 32'd1         :
                  (n == TYPE_START_SEARCH)              ? 32'd1         :
                  (n == TYPE_RETRIEVE_COLLISION)        ? rLastResult   :
                  (n == TYPE_HAS_FOUND_COLLISION)       ? (!rSearching) :
                  (n == TYPE_RETRIEVE_TOTAL_DIGESTS)    ? rTotalDigests :
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
            .reset(wResetSearchers),
            
            // Only send a start pulse if the instruction type indicates a
            // search should be started
            .start(wSearchStart),
            
            // The target data should be found in dataa for starting a search
            .target(dataa[4:0]), 
            
            // The message comes from the accumulation made from earlier
            // base message instruction calls
            .message(wMessage),

            // To parallelize the search, start each searcher at a different
            // position (all set at close as possible to the front)
            .counter(i),
            
            // Set increment to make sure none of the searchers run into each
            // other
            .increment(TOTAL_SEARCHERS),
            
            .digests_computed(wDigestsComputed[i]),
            .done(wSearchDone[i]), 
            .result(wSearchResult[i])
        );
        
        // First sum wire does not have anything but itself
        if (i == 0) begin
            assign wDigestSum[i] = wDigestsComputed[i];
        end else begin
            assign wDigestSum[i] = wDigestSum[i-1] + wDigestsComputed[i];
        end
    end
endgenerate

// ============================================================================
// = REGISTER LOGIC
// ============================================================================

// Update the last result when at least one searcher has finished
always @(posedge wClock, posedge reset) begin
    if (reset) begin
        rLastResult <= 32'b0;
    end else if (wAnyDone) begin
        rLastResult <= wFilteredResult[0]; // Contains the earliest result
    end
end

// Update search status based on a request to start searching and any indicator
// that we have finished searching
always @(posedge wClock, posedge reset) begin
    if (reset) begin
        rSearching <= 1'b0;
    end else if (wSearchStart) begin
        rSearching <= 1'b1;
    end else if (wAnyDone) begin
        rSearching <= 1'b0;
    end
end

// Only update our digest counter while we are still searching
always @(posedge wClock, posedge reset) begin
    if (reset) begin
        rTotalDigests <= 32'b0;
    end else if (rSearching) begin // TODO: Check that this doesn't get reset because of delay in searching register
        rTotalDigests <= wDigestSum[TOTAL_SEARCHERS - 1];
    end
end

// Update our done register based on the output signal
always @(posedge wClock, posedge reset) begin
    if (reset) begin
        rAnyDone <= 1'b0;
    end else begin
        rAnyDone <= wAnyDone;
    end
end

endmodule
