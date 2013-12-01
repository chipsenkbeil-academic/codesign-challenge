/*
 * Written by Robert "Chip" Senkbeil
 *         on 11/30/2013
 * Version 1.1
 */

// ============================================================================
// = INCLUDES
// ============================================================================

#include "cinterface.h"
#include "system.h"

#include <stdint.h>
#include <stdio.h>
#include <string.h>

// ============================================================================
// = CUSTOM INSTRUCTION WRAPPERS
// ============================================================================

#define SEND_BASE_BYTES(A,B)            ALT_CI_FIND_COLLISION_0(0,A,B)
#define START_COLLISION_SEARCH(target)  ALT_CI_FIND_COLLISION_0(1,target,0x0)
#define GET_COLLISION()                 ALT_CI_FIND_COLLISION_0(2,0x0,0x0)
#define FOUND_COLLISION()               ALT_CI_FIND_COLLISION_0(3,0x0,0x0)
#define GET_DIGESTS_COMPUTED()          ALT_CI_FIND_COLLISION_0(4,0x0,0x0)

// ============================================================================
// = LOCALS
// ============================================================================

static unsigned int currentTarget;

// ============================================================================
// = PUBLIC API
// ============================================================================

/*
 * Computes the current string (assuming 48 byte length) and determines the
 * actual message length to be placed as the final 64 bits of the 512-bit
 * message. This is sent to the coprocessor via a custom instruction.
 *
 * v: The base string to use to compute hashes
 */
void setsearchstring(char *v) {
    int i;
    
    unsigned char buffer[64];
    
    // Clear the buffer and copy message into first 48 bytes
    memset(buffer, 0, 64);
    strncpy(buffer, v, 48); // TODO: Get rid of warning regarding use of this
    
    // Set the padding after the 48 byte message
    buffer[48] = 0x80;
    
    // Set the size of the message to 48 bytes (0x180)
    buffer[62] = 0x01;
    buffer[63] = 0x80;
    
    // Load in the 64 bytes of information
    for (i = 0; i < 64; i = i + 8) {
        uint32_t a = (buffer[i]   << 24) | (buffer[i+1] << 16) |
                     (buffer[i+2] <<  8) | (buffer[i+3]);
        uint32_t b = (buffer[i+4] << 24) | (buffer[i+5] << 16) |
                     (buffer[i+6] <<  8) | (buffer[i+7]);
                     
        // Send the associated bytes
        SEND_BASE_BYTES(a, b);
    }
}

/*
 * Sets the target, which indicates the total number of zeroes to look for at
 * the beginning of the resulting digest. This is sent to the coprocessor via
 * a custom instruction.
 *
 * n: The target (soft maximum of 32 bits)
 */
void settarget(int n) {
    currentTarget = (n > 0) ? n : 1;
}

/*
 * Returns the number of SHA-1 digests computed thus far.
 */
int shacomputed() {
    return GET_DIGESTS_COMPUTED();
}

/*
 * Attempts to find a collision using the coprocessor, which internally
 * increments a 32-bit counter used for the first 32 bits of the base. The
 * counter value is returned from the custom instruction once a collision
 * is found.
 */
int searchcollision() {
    // Start the search for a collision
    // Target in hardware starts at base 0, so subtract 1 to align correctly
    START_COLLISION_SEARCH(currentTarget-1);
    
    // Spin until we have found a collision
    while (!FOUND_COLLISION());

    // Retrieve the discovered collision value
    return GET_COLLISION();
}
