/*
 * Written by Robert "Chip" Senkbeil
 *         on 11/30/2013
 * Version 1.1
 */

/**
 * This module provides the execution of the collision search, which attempts
 * to find a collision by generating SHA-1 digests.
 *
 * Input
 * -----
 *
 * clk:         The clock used to drive the search
 * reset:       Used to reset the state of the search
 * start:       Used to indicate the beginning of a new search
 *
 * target:      The 5-bit target indicating the total zeros that identify a 
                collision
 * message:     The 512-bit message used as the base to compute digests
 * counter:     The 32-bit message counter used as the base start value for
 *              the counter before incrementing
 * increment:   The 32-bit value with which to increment the counter after
 *              each digest computation
 *
 * Output
 * ------
 *
 * digests_computed: The total number of SHA-1 digests computed thus far
 *
 * done:        Used to indicate that the search has finished and the output
 *              of the search is now valid
 * result:      A 32-bit output value returned as a result of the search's
 *              completion
 */
module CollisionSearcher(
    clk, reset, start,                      // Execution inputs
    target, message, counter, increment,    // Data inputs
    digests_computed,                       // Progress outputs
    done, result                            // Result outputs
);

// ============================================================================
// = INPUTS/OUTPUTS
// ============================================================================
input         clk;
input         reset;
input         start;

input [4:0]   target;
input [511:0] message;
input [31:0]  counter;
input [31:0]  increment;

output [31:0] digests_computed;

output        done;
output [31:0] result;

// ============================================================================
// = CONSTANT PARAMETERS
// ============================================================================

// Potential states for internal use
parameter [3:0] STATE_IDLE                  = 5'd0; // Doing nothing, available 
                                                    // for the next instruction
                                                    
parameter [3:0] STATE_LOAD_MESSAGE          = 5'd1; // Loads a word (4 bytes) of
                                                    // the message and
                                                    // increments the data index
                                                    
parameter [3:0] STATE_WAIT_FOR_READY        = 5'd2; // Waits for a ready signal
                                                    // from SHA-1 module
                                                    
parameter [3:0] STATE_CHECK_COLLISION       = 5'd3; // Checks collision checker
                                                    // output to see if a
                                                    // collision has occurred
                                                    
parameter [3:0] STATE_DONE                  = 5'd4; // Sends done bit and the
                                                    // counter value at the
                                                    // collision

// ============================================================================
// = INTERNAL WIRES/REGISTERS
// ============================================================================

// State registers for transitions
reg [3:0]    currentState;
reg [3:0]    nextState;

// Information relative to SHA-1 and collisions
reg [4:0]    rTarget;
reg [31:0]   rMessageCounter;
reg [511:0]  rMessage;
reg [31:0]   rIncrement;

// Counter used for loading data into SHA-1
reg [3:0]    rDataCounter;

// Wires for SHA-1 module
wire         wValid;
wire         wInitial;
wire [31:0]  wData;
wire         wReady;
wire [159:0] wDigest;

// Wires for Collision Checker module
wire [4:0]   wTarget;
wire         wCollision;

// Register to keep track of digests computed
reg [31:0]   rDigestsComputed;
reg [1:0]    rReadyBuffer;

// Flags
reg          flag_Loading;
reg          flag_Ready;
reg          flag_Collision;

// ============================================================================
// = WIRE ASSIGNMENTS
// ============================================================================

assign wInitial = (rDataCounter == 0 & currentState == STATE_LOAD_MESSAGE);
assign wValid   = (currentState == STATE_LOAD_MESSAGE);
assign wData    = (rDataCounter == 0) ? rMessageCounter :
                  rMessage[(511 - rDataCounter * 32)-:32];

assign wTarget  = rTarget;

assign digests_computed = rDigestsComputed;

assign done     = (currentState == STATE_DONE);
assign result   = rMessageCounter;

// ============================================================================
// = MODULE ASSIGNMENTS
// ============================================================================

sha1 SHA(.iClk(clk), .iInitial(wInitial), .iValid(wValid), .iDat(wData),
         .oReady(wReady), .oDat(wDigest));
         
CollisionChecker COLLISION_CHECKER(.iClk(clk), .iTarget(wTarget), 
                                   .iData(wDigest),
                                   .oResult(wCollision));
                                   
// ============================================================================
// = SHA-1 DIGEST TRACKER LOGIC
// ============================================================================

// Simple buffer so we know when ready state of SHA-1 module has changed
always @(posedge clk, posedge reset) begin
    if (reset) begin
        rReadyBuffer <= 2'b11;
    end else begin
        rReadyBuffer <= {wReady, rReadyBuffer[1]};
    end
end

// Increment digests computed when the output of SHA-1 module's ready signal
// changes from 0 to 1 (indicating from not ready to ready for new input)
always @(posedge clk, posedge reset) begin
    if (reset) begin
        rDigestsComputed <= 32'b0;
    end else if (currentState == STATE_IDLE) begin
        rDigestsComputed <= 32'b0;
    end else if (rReadyBuffer[1] == 1 & rReadyBuffer[0] == 0) begin
        rDigestsComputed <= rDigestsComputed + 1'b1;
    end
end

// ============================================================================
// = INTERNAL STATE MACHINE FLAG & DATA LOGIC
// ============================================================================

// Update internal loading flag based on how much data has been loaded
always @(posedge clk, posedge reset) begin
    if (reset) begin
        flag_Loading <= 1'b0;  
    end else begin 
        // Loading up to and including the 16th byte, but
        // need to set loading flag low at index 15
        // TODO: Clean up this handling, shouldn't have to check for
        //       an earlier value like 13 to get timing right
        flag_Loading <= (rDataCounter <= 13);
    end
end

// Update internal ready flag based on ready output of SHA-1 module
always @(posedge clk, posedge reset) begin
    if (reset) begin
        flag_Ready <= 1'b0;  
    end else begin
        flag_Ready <= wReady;
    end
end

// Update internal collision flag based on output of collision checker
always @(posedge clk, posedge reset) begin
    if (reset) begin
        flag_Collision <= 1'b0;  
    end else begin
        flag_Collision <= wCollision;
    end
end

// ============================================================================
// = INTERNAL STATE MACHINE DATA PROCESSING
// ============================================================================

// Update message ONLY if finished with last process
always @(posedge clk, posedge reset) begin
    if (reset) begin
        rMessage <= 512'b0;  
    end else if (currentState == STATE_IDLE) begin
        rMessage <= message;
    end
end

// Update target ONLY if finished with last process
always @(posedge clk, posedge reset) begin
    if (reset) begin
        rTarget <= 5'b0;  
    end else if (currentState == STATE_IDLE) begin
        rTarget <= target;
    end
end

// Update increment ONLY if finished with last process
always @(posedge clk, posedge reset) begin
    if (reset) begin
        rIncrement <= 32'b0;  
    end else if (currentState == STATE_IDLE) begin
        rIncrement <= increment;
    end
end

// Update data counter
always @(posedge clk, posedge reset) begin
    if (reset) begin
        rDataCounter <= 4'b0;  
    end else if (currentState == STATE_LOAD_MESSAGE) begin
        rDataCounter <= rDataCounter + 1'b1;
    end else begin
        rDataCounter <= 4'b0;  
    end
end

// Update message counter if there was no collision
always @(posedge clk, posedge reset) begin
    if (reset) begin
        rMessageCounter <= 32'b0;
        
    // Increment only when we do not find a collision
    end else if (currentState == STATE_CHECK_COLLISION &
                 ~flag_Collision) begin
        rMessageCounter <= rMessageCounter + rIncrement;
        
    // Reset to input base when we are starting over
    end else if (currentState == STATE_IDLE) begin
        rMessageCounter <= counter;
    end
end

// ============================================================================
// = STATE MACHINE TRANSITION HANDLER
// ============================================================================

always @(posedge clk, posedge reset) begin
    if (reset) begin
        currentState <= STATE_IDLE;
    end else begin
        currentState <= nextState;
    end
end

always @(currentState, start, flag_Loading, flag_Ready, flag_Collision) begin
    case (currentState)
        STATE_IDLE: begin
            if (start) nextState = STATE_LOAD_MESSAGE;
            else nextState = STATE_IDLE;
        end
        
        STATE_LOAD_MESSAGE: begin
            if (~flag_Loading) nextState = STATE_WAIT_FOR_READY;
            else nextState = STATE_LOAD_MESSAGE;
        end
        
        STATE_WAIT_FOR_READY: begin
            if (flag_Ready) nextState = STATE_CHECK_COLLISION;
            else nextState = STATE_WAIT_FOR_READY;
        end
        
        STATE_CHECK_COLLISION: begin
            if (flag_Collision) nextState = STATE_DONE;
            else nextState = STATE_LOAD_MESSAGE;
        end
        
        STATE_DONE: begin
            nextState = STATE_IDLE;
        end
        
        // Unknown state: Move to idle
        default: nextState = STATE_IDLE;
    endcase
end



endmodule
