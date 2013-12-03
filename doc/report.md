The Codesign Challenge: Hash Collision Search
=============================================

Written by Robert "Chip" Senkbeil

Table of Contents
-----------------

1. Design Decision
    a. What options did I consider?
    b. Why did I choose a custom instruction?
    
2. Architecture Design
    a. What was my first design?
    b. Where did my first design fail?
    c. What was my second design?
    d. Where did my second design fail?
    e. What was my third design?
    
3. Observations
    a. What worked with my final design?
    b. What could be improved?
    
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

FILL ME IN!

### Where did my first design fail? ###

FILL ME IN!

### What was my second design? ###

FILL ME IN!

### Where did my second design fail? ###

FILL ME IN!

### What was my third design? ###

FILL ME IN!

Observations
------------

### What worked with my final design? ###

FILL ME IN!

### What could have been improved? ###

FILL ME IN!

[first_design_drawing]:  ../drawings/hardware-design-1.pdf
[second_design_drawing]: ../drawings/hardware-design-2.pdf
[third_design_drawing]:  ../drawings/hardware-design-3.pdf
