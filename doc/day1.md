Codesign Challenge: Day 1
=========================

This is a brief explanation of my progress through the first full day of
work I spent on the codesign challenge. It includes a summary of the task at
hand as well as my thoughts on how I would approach the problem.

Why write this online?
----------------------

So, first off, I have always found that the best way I can confirm that I
understand something is by explaining it to others. So, I am going to start
by explaining the codesign challenge provided by [Dr. Schaumont][professor],
one of my favorite professors from Virginia Tech. I am quite sad to have only
learned of him during my final semester, but I am also quite grateful to have
experienced his class.

What is ECE 4530?
-----------------

For those of you not familiar with the course structure at Virginia Tech, the
number format is four-digits. Typically, the most significant digit is the
level with 1000s being freshman, 2000s being sophomore, 3000s being junior,
and 4000s (and some 5000s) being senior. The hundreds, from what I have seen,
denote a category of courses. The last two digits are simply used to identify
the specific course.

So, the course 4530 denotes a senior-level course with the 5XX associating
with computer systems and system design. Other courses include
[Digital Design II][other_class], which is being revamped to focus on the
applications of FPGAs instead of simply teaching the fundamentals of Verilog.

So, what is this challenge?
---------------------------

The short answer is that this is a challenge where all students taking
ECE 4530 are competing against one another to see who can create the best
hardware/software design for a given problem. The specific problem changes
from year to year; so, I will be describing the problem presented to the
fall class of 2013.

The problem revolves around the SHA-1 algorithm, or more specifically the
collisions associated with it. For those of you unfamiliar with the algorithm,
the gist is that you feed into it 512 bits of data, known as a message, and it 
produces a 160 bit hash value, called a digest. This represents a one-way 
function as SHA-1 maps a 512-bit value to a 160-bit digest, not the other way 
around. A _collision_ is a case where two different messages generate the same
digest.

WRITE MORE OF THIS TO EXPLAIN!!!

Custom Instruction Interface
----------------------------

EXPLAIN WHAT THIS IS!!!

![Custom Instruction Types][custom_instruction_types]

EXPLAIN MY THOUGHTS ON THE BENEFITS!!!

One downside of the custom instruction interface for the Nios II is that the
input is fairly limited. Combinational and multi-cycle instructions only have
two 32-bit inputs (dataa and datab). In my case, I need to transmit 512 bits
of data, which means that I would need to perform eight custom instruction
calls focusing on sending data to my custom hardware _before_ a ninth
instruction that begins the process to calculate the digest.

Luckily for me, the custom instruction interface as an additional type: 
extended. An extended instruction uses an additional port labelled _n_, which
can be anywhere from one bit to eight bits wide and signifies the number of
different operations the instruction performs. Using an extended custom
instruction, I could have one (or multiple) operations that load data as well
as an additional operation that begins the SHA-1 digest calculation.

For more information about Nios II custom instructions, see the
[reference manual][altera_custom_instruction] from Altera.

Memory-Mapped Coprocessor
-------------------------

EXPLAIN WHAT THIS IS!!!

![Avalon Memory-Mapped System][avalon_mm_system]

EXPLAIN MY THOUGHTS ON HOW I WOULD USE THIS!!!

EXPLAIN MY THOUGHTS ON THE BENEFITS!!!

When reading through the reference for memory-mapped interfaces (referenced
below), I noticed that data transfers could range from 8 bits up to 1024 bits.
This means that I could transfer the full 512-bit message through one line of
C code, which is appealing; however, Altera notes that transfers can take
multiple cycles. Because of this, I want to check the time it would take to
perform a transfer of 512 bits of data versus alternatives such as using
multiple custom instruction calls to transfer data.

One concern I have with memory-mapped coprocessors is dealing with cached
registers. Earlier, we used the volatile keyword to _hint_ that the compiler
should not optimize reads/writes to that address; however, from what I have
read, this is not guaranteed. In order to make sure to avoid the cache, we
used provided macros IORD (to read) and IOWR (to write). The downside is that
these have a cap of 32-bit transfers.

For more information about Avalon interfaces, see the
[reference manual][altera_memory_mapped] from Altera.

For a discussion on IORD and IOWR, see the Altera forum discussion
[here][altera_iord_iowr_discussion].

Multi-core Nios II Processor
----------------------------

Another alternative, which was discussed during the first week of our codesign
challenge, is to provide multiple Nios II cores that run in parallel. The
implementation we were shown involved a master Nios II core and one or more
slave cores. The master core would communicate with other cores via shared
memory available to specific slave cores.

The advantage is obviously that one of the largest bottlenecks, software, is
broken up and parallelized such that the perform can up to double by simply 
adding a single core. Of course, this depends on how you design your software.
The code needs to be written such that the master and slave cores can work at
the same time with different tasks.

The issue is that we are still working with software, which is much slower
than a direct hardware solution. From what I have seen the optimal solution is
to provide as much work in parallel through a hardware implementation as well
as provide the simplest software initialization possible where the least number
of cycles are spent with software passing control over to hardware and vice
versa.

Analysis of Data Transfer
-------------------------

With the alternatives described above, I came to the conclusion that if I
wanted to provide a hardware implementation of SHA-1, I would need to figure
out which approach, custom instruction or memory-mapped, is better for a
transfer of 512-bit value _as well as_ receiving a 160-bit value.

With the custom instruction interface, I was limited to sending 64 bits of
information at a time through ports dataa and datab, each of which is 32 bits
wide. I decided to have a single bit extended custom instruction - in other
words _n_ is a single bit. When the instruction is set to receiving data, it
shifts internal registers to append the latest 64 bits of data. When the
instruction is set to calculate, it passes on the 512 bits stored in internal
registers to the SHA-1 Verilog module.

![Results of Custom Instruction][results_custom_instruction]

With the memory-mapped interface, I was able to set FINISH THIS!!!

![Results of Memory-Mapped Interface][results_memory_mapped]

Final Thoughts for the Day
--------------------------

So, with all of these different routes to consider, I think that I have come
up with my own implementation. My hope is that I can work on this in stages,
where finishing one stage provides a level of improvement over the previous.

So, 

[professor]:                    http://www.ece.vt.edu/schaum/
[class]:                        http://www.ece.vt.edu/schaum/teachcodesign.html
[other_class]:                  http://www.ece.vt.edu/ugrad/viewcourse.php?number=4514-49
[altera_custom_instruction]:    http://www.altera.com/literature/ug/ug_nios2_custom_instruction.pdf
[altera_memory_mapped]:         http://www.altera.com/literature/manual/mnl_avalon_spec.pdf
[altera_iord_iowr_discussion]:  http://www.alteraforum.com/forum/showthread.php?t=25299

[reference_results]:            ../img/reference_results.png
[custom_instruction_types]:     ../img/custom_instruction_types.png
[avalon_mm_system]:             ../img/avalon_mm_system.png
[results_custom_instruction]:   http://TODO
[results_memory_mapped]:        http://TODO

