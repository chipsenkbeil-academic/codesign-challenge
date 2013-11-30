#include "system.h"
#include "io.h"
#include "altera_avalon_pio_regs.h"
#include <sys/alt_alarm.h>
#include <stdio.h>
#include <string.h>
#include "sha1.h"
#include "cinterface.h"

// selects interval, in seconds, for search status updates
const int updateeach = 10;

void printdigest(unsigned char d[20]) {
  unsigned i;
  for (i=0; i<20; i++) {
    printf("%02x", d[i]);
	if (!((i+1)&3)) printf(" ");
  }
  printf("\n");
}

void printcollision(unsigned u, unsigned char digest[20]) {
    // dump counter value on HEX display
    IOWR_32DIRECT(PIO_0_BASE, 0, u);
    printf("Collision found at Counter Value %x!\n", u);
	printf("Digest: ");
	printdigest(digest);
}

void reportcollision(char *secretkernel, unsigned c) {
   unsigned char digest[20];  
   char s[48];
   sha1_context ctx;

   memset(s, 0, 48);
   strncpy(s, secretkernel, 48);

   s[0] = (char) (c >> 24);
   s[1] = (char) (c >> 16);
   s[2] = (char) (c >>  8);
   s[3] = (char) (c      );
   sha1_starts( &ctx );
   sha1_update( &ctx, (unsigned char *) s, 48 );
   sha1_finish( &ctx, digest );

   printcollision(c, digest);
}

typedef struct {
  int prevcount;
  int callbackcount;
} cbcontext;
typedef cbcontext * cbcontextptr;

alt_u32 updatecallback(void *context) {
  ((cbcontextptr) context)->callbackcount++;
  printf("Count %d, SHA1 per sec %d\n", 
			 shacomputed(), 
			(shacomputed() - ((cbcontextptr) context)->prevcount) / updateeach);
  ((cbcontextptr) context)->prevcount = shacomputed();
  
  return updateeach * alt_ticks_per_second();
}

int main() {
    alt_alarm alarm;
    char *secretkernel = "XXXX Keep your FPGA spinning!";
			
	printf("Collision string:                  %s\n",  secretkernel);
	printf("Display update interval (seconds): %4d\n", updateeach);
	printf("Sysclock ticks per second:         %4d\n", (int) alt_ticks_per_second());
	
    unsigned iteration = 0;
	cbcontext cb;
	do {
		iteration++;
		printf("--------- Iteration %d\n", iteration);
		printf("Target collision (bits):           %4d\n", iteration);
        settarget(iteration);
	    setsearchstring(secretkernel);

		cb.prevcount = 0;
		cb.callbackcount = 0;
	    alt_alarm_start(&alarm, 
				    updateeach * alt_ticks_per_second(), 
					updatecallback, &cb);
    
        unsigned cnt;
        cnt = searchcollision(secretkernel);
        alt_alarm_stop(&alarm);    
	    reportcollision(secretkernel, cnt);
	} while ((cb.callbackcount < 10) && (iteration < 32));
	
	printf("Terminating Search\n");
	
    return 0;	
}
