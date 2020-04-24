---
layout: post
title: How could we use the stack in Assembly?
subtitle:  An example for printing unsigned integers
date: 2020-04-08
categories: Assembly
---

# How could we use the stack? An example for printing unsigned integers.

The stack as we know is a data structure built on top of the actual memory and that grows downwards towards the zero memory address.
To explore how we could use the stack to store data we need, lets consider a program whose purpose is to print a given unsigned decimal integer.

Have a look at the code section. The idea is to recursively divide the value by 10 and save the reminder anytime. Where do we save the reminder? **The stack is the answer!** Actually, to be more precise, we store the reminders in memory locations next to an address that is stored in the stack.

Since we are executing the program in 64 bit mode we can't push single byte to the stack but the chunk of data pushed has to be of 64 bits. More on this when we discuss about the mistakes made.

So what do we do then?

 The approach is to reduce the stack as much as needed. Two things to remember here.


 - **The stack grows downwards in memory**. Very important and will be of great help in our example
 - **At the end of the procedure the stack has to be the same as it was at the beginning**. When the instruction `ret` is executed what really happens is `pop rip` . It is necessary that the element got from the stack at this point is the same as the one pushed once entering the procedure. Otherwise undefined behavior will occur.

In the components of the stack are **addresses**. `rsp` when we enter the procedure has a value equal to the content of `rip`. Recall that this registry holds either the address where the cpu has to take the next instruction to execute or the one of the instruction just executed (it depends on the architecture).

Therefore at the beginning we have a memory address in `rsp` and the answer to "what do we do then" is: simple! We move `rsp` one byte to the left and pour one byte there. Still digits to save? One byte to the left and repeat the pouring. Continue until no digits are left. We then are free to `mov rsi, rsp` and make `rdx` equals to the number of digits.

To understand why it works lets reconsider the stack as a pile of 8-byte containers. We can take the current address in `rsp`. Recall, as said above, that we enter the procedure with a `call` and such an instruction performs a `push rip` under the hood. So we have this address. For an explanatory sake consider it equals to 0x00000000000A. This means that we are 10 bytes apart from the 0 address.

We can `dec rsp` and have `rsp` equals to 0x000000000009. In this way we have now the memory address where the 9th byte starts. Recall that 1 byte on its right (i.e. at the 10th position) we encounter the data pointed by `rip` so if we are going to pour data here we have to be sure to not override what is in the 10th position. What does it mean?

It means that if we write something like `mov [rsp], a_byte` we are fine, but just type `mov [rsp], more_than_a_byte` and we are in huuuuuge troubles! What the former is saying is: "go to the offset of the memory location stored in rsp (here the 9th byte) and pour a byte of data in it". This doesn't override the data starting at the 10th byte. So far so good.

But the second instruction would resolve in an **undefined behavior**. What is saying is: "go to the offset of the memory location stored in rsp and pour there more than a byte". The boarder of the 10th byte is not respected. As an overflow of concrete, the data there is covered by what we are pouring at the beginning of the 9th byte.

**Here is clear why the stack grows downwards in memory!!!!!** Move on the right and we can affect the address in **rip** that we pushed on the stack. We can't override it otherwise we have undefined behavior when popping rip later. On the other hand, on the "left"( towards zero address), we are free (at this point in the program) to use the memory as we like.

We continue with our algorithm until the dividend is 0.    

At the end of our loop we have an `rsp` that has decreased as many times as are the digits of our number. We stores such information in a counter `rcx`.

We now have everything.

A quick recap on what we got.

 - `rcx` that holds the count of the digits of our number
 - The stack pointer (the address inside it) that has been reduced by `rcx`. Meaning that from the original value and the current one we freed `rcx` bytes of memory
 - We have placed in these freed bytes the binary values representing the Ascii code of the digits    

What we have to do now is printing all that is inside these bytes just allocated and bring back the stack pointer to where it was before applying our algorithm.

To print those values we use the system call **write** (`mov rax, 1`) on the file descriptor for **stdout**(`mov rdi, 1`). According to the documentation such a system call is going to write a buffer starting at the memory location placed inside `rsi` and for `rdx` bytes. Be careful that the buffer starts at the address got in `rsi` but the values written are taken starting from what that memory address actually contains ( `[rsi]`).  Indeed, the first byte considered by the system call is the byte found at such address, i.e what we can refer to as `byte[rsi]`. The latter instruction means "go to `rsi` (positioning the **offset**) and take the first byte of what is there".

So once we do `mov rsi, rsp` and `mov rdx, rcx` we have everything to invoke the system call. Here again is clear why the stack is made to move downwards. The system call will indeed start at the address in `rsp` and move upwards in memory for `rcx` bytes.

Now what is still missing is bringing back the stack to its initial value: `add rsp, rcx`.

Next are some considerations on the mistakes we made.

### The code

<script src="https://gist.github.com/gr0uch0dev/268f650342c427966ecf08281f902305.js"></script>

### Mistakes made

We made several mistakes. Some of them conceptual as far as the stack was concerned.

One was storing the data to be printed directly inside the registers pushed to the stack instead of storing the data at the offset of addresses stored in the stack.

For instance `mov rdx, 10` followed by `push rdx` places a 64bit container on the stack with a value of `10`. While, supposing `num` a "variable" in the data section,  `mov rdx, num` followed by `push rdx` stores into the stack the offset (memory address) of the variable.

The write system call expects its buffer parameter to be a pointer to a memory address where it will find the first piece of data to write into the chosen file descriptor. Therefore `rsi` does not have the target value inside but have the address where the procedure is going to find the value.

Furthermore, we got an other lesson concerning the stack.

Now think about the stack as a pile of 64bit containers.

Recall for a moment that under a 64bit mode memory addresses are indeed represented with 64bits (16 hexadecimal digits).
Therefore to store an address you need a container that can hold such bits.

On the other hand an Ascii representation of a char is 8 bits (1 byte). What if we want to **push this byte to the stack**?

If the stack is comprised of pieces of 64 bits (8 bytes) each **we can't** do something like `push the_byte` because it's expecting to receive a much bigger object. How can we accomplish it? To push such 8 bits onto the stack we need to put them firstly inside a 64-bit envelope and then push. Call X the byte that represents the char we are interested into. We need something like (- - - - - - - X) where the dashes stand for the remaining bytes (7) that we have to put with X before pushing.

If not yet clear suppose to have the digit '12' and that the bytes representing '1' and '2' are respectively X and Y. We put those two bytes in bigger containers like `A = (- - - - - - - X)`  and `B = (- - - - - - - Y)`. Now can `push` A and B and have them near, like  `(- - - - - - - Y)(- - - - - - - X)...`, with `rsp` holding the offset address of the first `-` of B.

Good, it seems we are happy. But wait a sec. Maybe not. We need to print Ascii Y and X. If we give `rsi` the value of `rsp` than the write call will make the buffer starts at the first `-` of B. We are far from Y.

How can we handle it? A cycle with printing one char at the time seems to be the answer. We can indeed position ourselves at the offset of Y by adding 7 bytes to the initial value of `rsp`. With `add rsp, 7`,  `mov rsi, rsp` and `mov rdx, 1` we can then invoke the system call and make it write just the Y byte. But then we need to reach the offset of X and so on.
A comment to this approach? Oh my God! **We are using the stack in the wrong way!**
