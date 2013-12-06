The Codesign Challenge: Hash Collision Search
=============================================

Written by Robert "Chip" Senkbeil

Date is December 3rd, 2013.

Table of Contents
-----------------

1. Summary

    a. What optimizations did I use?
    
    b. What was the performance of the final design?

2. Design Decision

    a. What options did I consider?

    b. Why did I choose a custom instruction?
    
3. Architecture Design

    a. What was my first design?

    b. Where did my first design fail?

    c. What was my second design?

    d. Where did my second design fail?
    
    e. What was my third design?
    
    f. Where did my third design fail?
    
    g. What was my final design?
    
    h. How did I get more performance?
    
4. Observations

    a. What worked with my final design?
    
    b. What could be improved?
    
    c. What would I do differently?
    
5. Final Thoughts

Summary
-------

The following is a summary of the overall report since I realized this report
got a little out of hand. I wrote it as a series of blog posts that I later
compiled.

### What optimizations did I use? ###

I used an implementation of the SHA-1 digest calculation in hardware versus the
provided software solution. Furthermore, I implemented the test of a collision
in hardware such that I could use the software to simply start the process of
finding a collision, checking the number of digests calculated, and get the
counter value associated with a collision.

I used a custom instruction interface since my hardware design allowed me to
limit the returned values to 32-bit values: the number of digests calculated
and the counter value associated with a custom instruction.

Finally, after my final design, I realized I could increase the clock speed
using PLLs. My maxed out design using 46 seachers and 95% of my FPGA failed
with a 100 MHz clock; however, reducing the searchers to 32 - using less
chained combinational logic - provided me with correct counter values and
a greater digest calculation (essentially the same as if I could fit 64
searchers in a 50 MHz design).

### What was the performance of the final design? ###

Overall, my final design ran with a 100 MHz clock using one PLL to increase
the clock from 50 MHz to 100 MHz.

The average number of digests computed per second was ~38,091,000 (rounded
down).

The total logic elements used was 76,310, which used 67% of my board. I could
actually fit additional searcher logic into my design, but it could not handle
the faster clock (see what could be improved to understand why).

![Faster Run with 32 Searchers][faster_run_max]
    
Design Decisions
----------------

### What options did I consider? ###

In terms of options, there were three main topics we had discussed in ECE 4530
along with an additional optimization that could be added.

The first option was to use a custom instruction that interfaced with the 
Nios II processor. With this setup, I could have a C program that could execute
a request for a counter value that provides a digest that matches the target 
with a very simple and quick command.

The second option was to use a memory-mapped coprocessor, which the Nios II
would obviously access using registers made available to it. This would need
to be handled with care to avoid having the exposed registers cached. The
advantage is that more optimizations could be made through the much less rigid
interface compared to the custom instruction.

The third option was to use a multi-core setup with the provided software
implementation of the digest calculation and collision test. This is obviously
not the fastest approach as the DE2-115 can only handle a few processors when
you add the additional memory and bus infrastructures. It can also get much
more complicated connecting the processors together and managing them. A
positive is that less hardware design would need to be taken into consideration
and the software implementation could be fairly well divided between multiple
Nios II cores.

The optimization - well, one of them - that could be applied that we also
briefly mentioned in class was to add a pipeline system for a provided SHA-1
implementation in Verilog. The reference implementation runs at 80 clock
cycles, which is a pretty hefty delay when thinking in terms of hardware.
Adding a pipeline could potentially speed up the process tremendously.

### Why did I choose a custom instruction? ###

My thoughts were that I wanted a simple design that I could understand quickly.
The custom instruction interface was very simple for me to understand. The
limitation of two 32-bit data inputs - one being optional - and a single 32-bit
output for a return value was not an issue in this design as the only value I
planned to receive was the 32-bit counter that resulted in the collision.

My goal was to implement the entire process of both computing SHA-1 digests and
testing them in hardware rather than leaving any of the work to software. One
reason was that the delay in having to poll memory-mapped registers would be
costly, whereas the result of a collision would be nearly immediate since the
custom instruction lies in custom logic blocks adjacent to the ALI in the
Nios II's datapath. The second reason was that I wanted only one side to be
even remotely complex. In this case, I wanted the hardware to handle the
entire process of collision and leave the software to initialize the hardware
to start the next search.

Architecture Design
-------------------

### What was my first design? ###

My first design was to write an extended custom instruction. I learned of this
while reading through Altera's documentation on custom instructions and found
it to be a perfect fit for my needs. In my design, I needed to be able to load
my base message - XXXX Keep your FPGA spinning! - into the hardware behind the
custom instruction. Afterwards, I would need to be able to receive a request
for a collision given a target and be able to return one.

Because of these requirements - keep in mind that I both forgot something
important and was unaware of a consequence - I set out to design an extended
custom instruction with two possible instruction inputs. In other words, the
extended instruction wire 'n' was set to be a single bit. I began to draw out
my design ([found here][first_design_drawing], but the pages are backwards).

Essentially, if my custom instruction received an 'n' of 0, it would attempt
to add the two words of input data to the internally stored 512-bit register.
This way, I could have a loop on the software side that loaded in data, two
words at a time.

If my custom instruction received an 'n' of 1, it would begin the process of
setting the target internally from the first word of input (dataa), load in
the 512-bit message one word at a time into the reference SHA-1 implementation,
test if the resulting digest had at least _target_ number of zeros at the
beginning, and either return the discovered collision or begin the process of
loading the message again after incrementing an internal counter.

### Where did my first design fail? ###

First of all, I did not realize that this instruction blocked _everything_.
Because of the way the collisions.c was written, I assumed that a timer
interrupt would still execute; therefore, it did not matter if the function
searchcollision took over 100 seconds as the callback routine would be
executed anyway. After learning that this was not the case, I knew that I
would have to rework my design.

Second of all, I had forgotten to take into consideration that there was no
way to get the total number of SHA-1 computations completed. I had not added
any form of internal counter nor had I designed a way for such a value to be
returned while a search was still being processed. The done bit from the
search would not be high until the search had completed, meaning that another
custom instruction call to retrieve a digest would not be able to happen.

Because of the blocking nature of my first design combined with the fact that
I had no knowledge of how many computations had been completed, I was not able 
to get any feedback to tell me how much my design had improved over the
reference implementation's 549 SHA-1 computations per second.

### What was my second design? ###

My second design was a complete overhaul. I decided to split up the majority of
the custom instruction into different modules that would be placed inside of it.
Furthermore, the state machine I designed earlier was altered slightly such that
there was no state to handle determining an instruction (that is now done through
some combinational logic mixed with the start bit).

After realizing my mistake, I now had five separate instructions that the
extended instruction could handle:

1. Receiving words of data to be placed in the 512-bit base message
2. Start a search for a collision with the target provided as input and using
   internally-stored base message along with an internal counter for the first
   32-bits of the message
3. Check whether or not the current search had finished
4. Retrieve the counter value of the last collision found
5. Retrieve the total number of digests computed since the search began

The software implementation was also updated. The `shacomputed()` function
now had a call to a custom instruction (instead of doing nothing). The
`searchcollision()` function would now begin by calling a custom instruction to
start a search with the given target, spin endlessly while a custom instruction
to determine if the search had finished returned false, and then returned with
the counter value retrieved with a final custom instruction call.

While I had also considered the possibility of scaling my design by having many
searcher modules that each internally computed digests and tested them, I did
not design my hardware to scale. In other words, it could only run a single
SHA-1 implementation and test it.

### Where did my second design fail? ###

The second design didn't fail as much as it wasn't as fast as I had hoped. The
second design achieved roughly 17,359 computations per second. While this was
much better than the software implementation (over 30 times faster), I felt
that I could improve it much more.

![Second Design Single Results Closeup][tdr_single_closeup]

_Note: The results above are using my third design with a single searcher and
achieve the same performance as with the second design._

### What was my third design? ###

My third design did not vary much from the second design aside from replacing
some definitions with more scalable versions. To this end, I used Verilog's
generate functionality to replicate parts of my design, specifically the number
of searchers that would be running at once.

To do this, I needed to be able to generate not only multiple collision
searcher modules but also an adder that could add a variable number of 32-bit
inputs (the digest count of each searcher) and a filter that could determine
which counter should be used when one _or more than one_ searcher found a
collision.

This was a bit of a hack in my opinion as I ended up using wire assignments
that chained off one another to perform additions and the filtering. The entire
design can be found in my third design's drawings, [here][third_design_drawing].

Below are the results for my design, when I maxed out the DE2-115 using 46
parallel searchers. This used 95% (108,371) of the DE2-115's logic elements. 
The performance improvement is roughly 46/1 over using a single searcher, 
resulting in roughly 798,578 computations per second. Just shy of being fast 
enough to find a collision for 27 bits of zero in under 100 seconds!

![Third Design Maximum Results Closeup][tdr_maximum_closeup]

### Where did my third design fail? ###

Having skimmed over some documentation, I did not realize that the clock enable
signal was only high for the duration of an instruction. Because of the way I
designed my hardware, the clock would only be active for a single cycle per
instruction since each instruction returns immediately, deactivating clock
enable.

The only reason my design progressed was because of my software, where I
continuously poll the hardware to see if it was finished. This polling ended
up acting as the clock for the hardware since the clock and clock enable were
tied together.

The true performance for a single searcher was:

![Final Run Single][normal_run_single]

### What was my final design? ###

The solution to this issue was obviously to untie the clock and clock enable.
I then added the clock enable to my start logic for both receiving message
words and initializing the search, ensuring that those two operations were
synced to a clock pulse.

The internal hardware continued to operate with the normal clock signal.

Maxing out my design with 46 searchers (like in design 3), the performance
is ~27,476,000 digests computed per second! This, like with design 3, was
roughly a 46/1 ratio improvement!

![Final Run Maximum][normal_run_max]

### How did I get more performance? ###

After maxing out my board in terms of logic elements, I looked into other
solutions. The most obvious to me was to simply increase the clock speed used
in my design. Initially, a 50 MHz clock was used; however, I was able to boost
my clock to 100 MHz using one of the four PLLs available on the board.

The result for a single searcher was the following:

![Faster Single Run][faster_run_single]

As you can see, this was basically double the digests computed from using a
single searcher on a 50 MHz clock.

I then proceeded to build my design with the maximum supported searchers (46);
however, because of limitations in my design (described below), the tests and
result filtering of the searchers failed. Thinking back to my design, I examined
the timing requirements and found that I could still get a larger number of
searchers in my design without failing with a 100 MHz clock. To this end, I
used 32 searchers for 67% of my board:

![Faster Run with 32 Searchers][faster_run_max]

Observations
------------

### What worked with my final design? ###

Overall, I would say that my design had some success, especially in 
parallelizing the process of computing digests and testing them. As seen from
the results for my third design, using multiple searchers drastically improved
the performance of my design.

Furthermore, using the generate blocks to create this parallel design - rather
than hard coding a parallel implementation - allowed me to have an easier time
scaling my design to max out the available logic elements of the DE2-115. Given
my design, you could theoretically add even more parallel searchers to give
better performance.

### What could have been improved? ###

So, one aspect I noticed that could pose a problem was how I handled the sum of
the total digests outputted from each searcher. By using a chain of wire
assignments with combinational adders, I was limiting the scalability by the
speed of the clock. My maximum design was still able to function correctly;
however, if you increased the number of searchers to 1024, I am unsure if the 
total sum would be able to reach the register that will store it before the 
next clock cycle. This could be improved (in terms of stability) by having a
series of clocked adders. The total digest output of a custom instruction
request would be a few cycles off, but given the time between SHA-1 digest
computations, it wouldn't be  huge issue.

Furthermore, each searcher was outputting a 32-bit running total of the digests
computed. Instead, the searchers could be written to take a parameter that
indicates the output size of the running counter. This would decrease as more
searchers were introduced.

Another issue that is similar to the first focuses on how I filter the results
of the searchers. My process was to generate a chain of wire assignments that
used multiplexers to load in either the result of the previous searcher or the
current searcher based on which searchers had found collisions. Obviously, 
chaining a huge number of multiplexers to do this isn't the best idea, either.

Finally, I am sure that there are aspects of Verilog that I did not understand
well while working on this project. I learned Verilog from Digital Design II at
the same time that I took Hardware/Software Codesign and had to look up various
functionality such as the generate block on my own.

### What would I do differently? ###

I had planned to look into piping the SHA-1 reference module that was provided
to us and reduce the number of searchers. My thoughts were that I could add
piping to reduce the 80-cycle computation to 40 or 20 cycles with a better
hardware-to-performance ratio than increasing my searchers.

Improving the main bottleneck would drastically increase the speed of all of
the currently-implemented searchers; therefore, if I needed to reduce the
number of searchers to 32 (random number), I would probably still get better
performance by having a faster SHA-1 module (if I could reduce it to 40 cycles
or some other large improvement).

However, given that I was approaching the third week of this assignment, I did
not want to risk trying another optimization given that my current design
provided me with a improvement of ~50,000 times faster.

Final Thoughts
--------------

I enjoyed this challenge more than I would have first believed. I have never
been one to enjoy direct competitions as they make me quite nervous; however,
I ignored the competition aspect of this assignment when working on it and
focused more on the different designs and what I could do to provide an easy
software-to-hardware interface (minimal work on the side of the software)
while also having a very robust hardware design - in terms of scalability -
that could be expanded without rewriting a lot of the code. Granted, there are
some limitations mentioned in the improvement section that would need to be
worked out, but the majority of the design can be expanded without issue.

It was a fun assignment that challenged (no pun intended) me to think of how
I could _apply_ what I _learned_ in class, something that I find to be very
rare in what seems to be a very theoretically-taught field.

[first_design_drawing]:  http://senkbeil.org/ece4530/hardware-design-1.pdf
[second_design_drawing]: http://senkbeil.org/ece4530/hardware-design-2.pdf
[third_design_drawing]:  http://senkbeil.org/ece4530/hardware-design-3.pdf

[tdr_single_closeup]:  ../img/third_design_single_searcher_results_closeup.png
[tdr_maximum_closeup]: ../img/third_design_maximum_searcher_results_closeup.png
[normal_run_single]:    ../img/single_searcher_results_closeup.png
[normal_run_max]:       ../img/maximum_searcher_results_closeup.png
[faster_run_single]:    ../img/100mhz_single_searcher_results_closeup.png
[faster_run_max]:       ../img/100mhz_32_searcher_results_closeup.png

[usage]:                ../img/usage.png

