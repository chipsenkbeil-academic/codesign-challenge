/*
 * Written by Robert "Chip" Senkbeil
 *         on 11/28/2013
 * Version 1.0
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
 *         Return value is a "don't care" of 32-bits
 *
 * 1:      Indicates that the base value is complete, loads the target, and
 *         attempts to find a collision
 *
 *         dataa: The target value to use for this collision search 
 *         datab: UNUSED
 *
 *         Return value is the counter of the collision that is found
 */
module CollisionInstruction(
    clk, clk_en, reset, start,  // Execution inputs
    dataa, datab,               // Data inputs
    n,                          // Instruction selection inputs
    done, result                // Instruction outputs
);

// =============================================================================
// = INPUTS/OUTPUTS
// =============================================================================
input         clk;
input         clk_en;
input         reset;
input         start;

input [31:0]  dataa;
input [31:0]  datab;

input         n;

output        done;
output [31:0] result;

// =============================================================================
// = CONSTANT PARAMETERS
// =============================================================================

// Types associated with the selection bits
parameter       TYPE_BASE_ADDRESS           = 1'd0;
parameter       TYPE_EXECUTE                = 1'd1;

// Potential states for internal use
parameter [4:0] STATE_IDLE                  = 5'd0; // Doing nothing, available 
                                                    // for the next instruction
                                                    
parameter [4:0] STATE_DETERMINE_INSTRUCTION = 5'd1; // Determines which path to
                                                    // progress based on 'n'
                                                    
parameter [4:0] STATE_APPEND_BYTES          = 5'd2; // Appends dataa and datab
                                                    // to message and increments
                                                    // the message position
                                                    
parameter [4:0] STATE_SET_TARGET            = 5'd3; // Sets the internal target
                                                    // using dataa's value
                                                    
parameter [4:0] STATE_LOAD_MESSAGE          = 5'd4; // Loads a word (4 bytes) of
                                                    // the message and
                                                    // increments the data index
                                                    
parameter [4:0] STATE_WAIT_FOR_READY        = 5'd5; // Waits for a ready signal
                                                    // from SHA-1 module
                                                    
parameter [4:0] STATE_CHECK_COLLISION       = 5'd6; // Checks collision checker
                                                    // output to see if a
                                                    // collision has occurred
                                                    
parameter [4:0] STATE_DONE                  = 5'd7; // Sends done bit and the
                                                    // counter value at the
                                                    // collision

// =============================================================================
// = INTERNAL WIRES/REGISTERS
// =============================================================================

// Clock/clock_enable combined
wire         wClock;

// State registers for transitions
reg [4:0]    currentState;
reg [4:0]    nextState;

// Internal input data/selection registers
reg [31:0]   rDataA;
reg [31:0]   rDataB;
reg          rInstruction;

// Internal output registers
//reg          rDone;
//reg [31:0]   rResult;

// Information relative to SHA-1 and collisions
reg [4:0]    rTarget;
reg [31:0]   rMessageCounter;
reg [511:0]  rMessage;

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

// Flags
reg          flag_Loading;
reg          flag_Ready;
reg          flag_Collision;

// =============================================================================
// = WIRE ASSIGNMENTS
// =============================================================================

assign wClock   = clk & clk_en;

assign wInitial = (rDataCounter == 0 & currentState == STATE_LOAD_MESSAGE);
assign wValid   = (currentState == STATE_LOAD_MESSAGE);
assign wData    = (rDataCounter == 0) ? rMessageCounter :
                  rMessage[(511 - rDataCounter * 32)-:32];

assign wTarget  = rTarget;

assign done     = (currentState == STATE_DONE);
assign result   = rMessageCounter;

// =============================================================================
// = MODULE ASSIGNMENTS
// =============================================================================

sha1 SHA(.iClk(wClock), .iInitial(wInitial), .iValid(wValid), .iDat(wData),
         .oReady(wReady), .oDat(wDigest));
         
CollisionChecker COLLISION_CHECKER(.iClk(wClock), .iTarget(wTarget), 
                                   .iData(wDigest),
                                   .oResult(wCollision));

// =============================================================================
// = INTERNAL STATE MACHINE FLAG & DATA LOGIC
// =============================================================================

// Update internal dataa with dataa
always @(posedge clk, posedge reset) begin
    if (reset) begin
        rDataA <= 32'd0;  
    end else if (currentState == STATE_IDLE) begin
        rDataA <= dataa;
    end
end

// Update internal datab with datab
always @(posedge clk, posedge reset) begin
    if (reset) begin
        rDataB <= 32'd0;  
    end else if (currentState == STATE_IDLE) begin
        rDataB <= datab;
    end
end

// Update internal instruction with n
always @(posedge clk, posedge reset) begin
    if (reset) begin
        rInstruction <= 1'b0;  
    end else if (currentState == STATE_IDLE) begin
        rInstruction <= n;
    end
end

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

// =============================================================================
// = INTERNAL STATE MACHINE DATA PROCESSING
// =============================================================================

// Load data into message
always @(posedge clk, posedge reset) begin
    if (reset) begin
        rMessage <= 512'b0;  
    end else if (currentState == STATE_APPEND_BYTES) begin
        rMessage <= {rMessage[447:0], rDataA, rDataB};
    end
end

// Set target
always @(posedge clk, posedge reset) begin
    if (reset) begin
        rTarget <= 5'b0;  
    end else if (currentState == STATE_SET_TARGET) begin
        rTarget <= rDataA;
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
        rMessageCounter <= rMessageCounter + 1'b1;
        
    // Reset when we are starting over
    end else if (currentState == STATE_IDLE) begin
        rMessageCounter <= 32'b0;
    end
end

// =============================================================================
// = STATE MACHINE TRANSITION HANDLER
// =============================================================================

always @(posedge clk, posedge reset) begin
    if (reset) begin
        currentState <= 1'b0;
    end else begin
        currentState <= nextState;
    end
end

always @(currentState, start, rInstruction, flag_Loading, flag_Ready, flag_Collision) begin
    case (currentState)
        STATE_IDLE: begin
            if (start) nextState = STATE_DETERMINE_INSTRUCTION;
            else nextState = STATE_IDLE;
        end
        
        STATE_DETERMINE_INSTRUCTION: begin
            if (rInstruction == TYPE_BASE_ADDRESS) begin
                nextState = STATE_APPEND_BYTES;
            end else if (rInstruction == TYPE_EXECUTE) begin
                nextState = STATE_SET_TARGET;
            end else begin // Unknown state: Move to idle
                nextState = STATE_IDLE;
            end
        end
        
        STATE_APPEND_BYTES: begin
            nextState = STATE_DONE;
        end
        
        STATE_SET_TARGET: begin
            nextState = STATE_LOAD_MESSAGE;
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
