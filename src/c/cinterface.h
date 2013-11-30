#ifndef CINTERFACE_H
#define CINTERFACE_H

/* setsearchstring(char *) defines the baseline message for which
   collisions need to be identified.
   
   The string will ALWAYS start with four 'X' characters.
   The string can be up to 48 bytes long and is padded with 0 bytes
   if it is shorter than that.
   
   Examples:
     "XXXX Collision string"
     "XXXX Keep your head cool and your FPGA spinning!"
     "XXXX"
*/	 
void setsearchstring(char *);

/* settarget(int) defines the target digest for the collision search
   It indicates the number of zeroes expected at the start of the digest
   to define a proper collision.
   
   Example: 
      settarget(14) defines a collision target with 14 leading zeroes
 */ 
void settarget(int);

/* searchcollision() performs the collision search.
   The function substitutes the four X at the start of the search string
   with a counter value and tests if the SHA1 computed over the resulting
   string has n zeroes, with n = the argument of the most recent settarget call.
   
   The return value of searchcollision is a 32-bit counter value identifies
   the collision. If no collisions can be found for any 32-bit value, the function
   aborts the collision search while returning 0.
*/
int searchcollision();

/* 
   shacomputed() returns the number of sha computed since searchcollision was called
   The function is called asynchronously
*/

int shacomputed();

#endif
