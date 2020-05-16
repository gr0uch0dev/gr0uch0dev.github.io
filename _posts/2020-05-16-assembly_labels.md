---
layout: post
title: The Assembly journey
date: 2020-05-16
subtitle: An high-level introduction on some of the main concepts
categories: MASM
---


Before starting any discussion about Assembly is mandatory to give a quick reference to what is know as the Von Neumann (VN) architecture, being the starting point of all our current machines today.

Such architecture answers to the question of "how we could organize computational operations and data in a machine given a specific task that the instructor(programmer) wants to accomplish".

In its simplest form a VN machine is made up by: CPU, memory and input/output sources.
In this post we are dealing with the Intel x86 architecture. Way more complex that this simple schema but the ideas behind are the same.

First thing to say is that **machines** speak in binaries. Binaries do not carry any implicit particular value. This is to say that we can look at a bunch of binaries as we would do with letters pronounced by someone. If those letters do not have any sense to the receiver (for instance if they form words of language not spoken by him) then those words can't be processed.
The idea with binaries and architecture is the same. We are not going into the details of which component is responsible for what, but it is sufficient to say that the CPU has been developed to understand specific **binary patterns**. Think about an English speaker that know how to process the word "hello".

The manufacturer, indeed, selected a set of instructions and made the CPU able to execute them. These instructions are encoded in bits and saved into memory spaces. Therefore the CPU knows that when it receives a binary-encoded instruction has to perform a specific operation that the manufacturer assigned to that bit string.

Memory holds both instructions and data. They are both in a binary form, therefore we can't tell the difference by just looking at it.

We are going to consider a 32-bit mode execution. Meaning that memory addresses are represented by 32 bits. Typically when dealing with memory we are made to think of it as a collection of blocks of 32 bits. But there is no physical separated block in memory. Addresses are actually an **abstraction**.

Memory is a pool of binary numbers placed in sequence, like `11110101010...`. Then we have addresses like `0x00000000` or `0x00000001`. The difference between the previous two addresses is 1. Where 1 stands for a single byte (8 bits). This makes the byte the smallest unit when dealing with addresses. Since we have 32-bit addresses and a byte is the smallest unit we have 2^32 (around 4GB) of usable addresses. The previous idea of address as abstraction on top of memory data is shown by the following picture.

<a href="https://ibb.co/j3S2VGh"><img src="https://i.ibb.co/RQqmhP2/memoryaddresses.png" alt="memoryaddresses" border="0"></a>

The CPU takes time to access memory therefore the manufacturers decided to place inside the CPU some blocks of space called registries. These blocks have a space for 32 bits (considering a 32-bit architecture). This information can be accessed way faster than the one stored in memory. Typically when we save data into a registry we use the word **load** (to load a registry). On the other hand, when data is placed into memory the term **store** (to store into memory) is used.

Some of these registers can be modified by a running program, others cannot. For instance there is a register called `EIP`. The 32 bits loaded into this register hold an address. This is the memory address the CPU has to go to find the next instruction to be executed. Technically we say **to fetch an instruction**.

Others registries are used to load values so that the CPU can dispose of them faster. For instance an instruction like `mov EAX, 5` is going to load the registry `EAX` with a value of the number 5 represented using 32 bits. After the instruction is executed the value of `EAX` will be `0000000000000000000000000101`. Instead of using the binary form is convenient to opt for an hexadecimal representation( here `0x00000005`) where two digits of an hexadecimal represent a byte. Indeed one single hexadecimal character represent a **nibble** (4bits) being able to encode numbers from 0 (0000b) up to 15 (1111b).

One example where the usefulness of registries is clear is into holding the value of a loop counter. Indeed such a counter is expected to be changed frequently by the CPU. Accessing it in less time is strongly desirable.

When we encounter something like `mov EAX, 5` we say that "an immediate value was loaded into the register `EAX`". But we are not limited to load immediate values. We can, indeed, use (assuming the first is a register) for the second operand of `mov` a memory address, the value of an other registry or a value stored into memory at a particular address.
Something like `mov EAX, EBX` copies the value of `EBX` into `EAX`. Therefore after this instruction both the registers hold the same 32-bit value.

Where things become interesting is when we want to load into the register a memory address or some data that is stored into memory. We have previously said that memory addresses are 32-bit values, therefore given an address like `0x00112233`, loading it into a registry should be the same as loading an immediate value. To load this address into `EAX` we could do `mov EAX, 0x00112233`. But what if we want to load into `EAX` not the address `0x00112233` rather what is in memory at that address. In other words we would like to go into the memory, reach address `0x00112233` and from there taking the desired bits of memory.

Just imagine what we would like to order the CPU to execute: "`please, go to address 0x00112233 and take there 32 bits and load them into the EAX registry`".

We need to **dereference** the address. We think of the address `0x00112233` as **referencing** something in memory. Therefore to get the value that is in memory at that address the prefix **de** is used. How could we tell that to the CPU?

This introduce the concept of **pointers**. But to better grasp this one lets consider an other abstraction: **labels**.

Without going into further details for now, just be aware that Assembly divides the program into different **sections**. Among these we find the section of **data** and **code**. What are sections? Other abstractions! Assembly is the realm of abstractions, in fact the purest ones. Think of having a paper full of bits  and to collect all of them into non overlapping rectangles of different sizes.

<a href="https://imgbb.com/"><img src="https://i.ibb.co/TWMS6BM/sections.png" alt="sections" border="0"></a>

In an Assembly program we write something like
```
.data
	aVariable dw 0x12345678
	anOtherVariable db 0x11
```
With the previous we are saying "please put in the data section a value of `0x12345678` followed by `0x11` ". Actually in memory (not in registries) the least significant bytes are stored first. This is what is know as **little endianess**. What is basically meant by the latter is that storing a value like `0x12345678` in memory is done in an ascending order with respect to the order relation of byte-significance. In other words, if we go into the memory address where `0x12345678` is stored we find that the first byte available in memory is taken by `0x78` rather than `0x12`. The latter is indeed occupying the last available byte (out of four).

What about the names we have just used, namely `aVariable` and `anOtherVariable`? They are labels. A label is an alias for a memory address.

This is the idea: "while you are putting the value into memory, like `0x12345678`, look what is the address at which you start pouring this data into memory and give to that address an **alias**, a label". We can therefore reference to that address using the label just chosen. This is what happens in Assembly languages like NASM. In others, MASM in particular, an other layer of abstraction is inserted and the name `aVariable` is actually used with the actual concept of a **variable**(holding the value). But for the sake of understanding we focus for now just on what happens in NASM.

Therefore we have now a label named `aVariable` that we defined in the `.data` section. As humans we can now read `aVariable` as the same as `the memory address where we placed a 4-byte value, namely 0x12345678`.

But we want to load in `EAX` what in human's language reads as `the 4-byte value that is stored into memory starting at the memory address that is aliased by "aVariable"`.

By using the double square brackets `[]`, that in NASM stand for the dereference operator, we can indeed accomplish our aim with the following:
```
mov EAX, [aVariable]
```

This is it! We have loaded into `EAX` the 4-bytes (`0x12345678`) stored into memory.

To sum up.
To a machine understanding humans' protocol we would say:
```
1) Take a memory address, give it an alias equal to "aVariable". Go there and pour into memory the 4-byte value of 0x12345678.
2) Go to the memory address aliased by "aVariable". From there take 4 bytes (considering the bytes at subsequent addresses).Once you got the bytes, place them into EAX.

```

To a machine whose language protocol is NASM we accomplish the previous with the following:
```
1) .data
	aVariable dw 0x12345678

2) mov EAX,[aVariable]
```

We could read the label used in 1) as just a **pointer** that we are **dereferencing** in 2) to get the value that it is pointing to. But the word **pointer** here could seem somewhat misleading. Who is used to high level languages like C knows that, by definition a pointer is a "variable" that holds a particular memory address. But here in NASM we do not have the concept of a "variable", we do have "labels" though. Since we said that labels are nothing more than memory addresses aliases we can easily look at it as a pointer.

Above we stressed the fact that although this is the case in NASM, what happens in MASM is different. Although the difference seems minimal, it is **conceptually** relevant. One of MASM's aims is to be closer to the logic of an high level language programmer. It is not a surprise then if MASM implements the concept of **variable**.
We can easily think of variables as a second layer of abstractions, just reasoning about the conceptual meaning of variable. It is indeed a container of some value. Such value need to be somewhere in memory. That "somewhere in memory" is traduced into an actual address.

In MASM we can declare and define variables in a similar way to what we did in NASM for labels.
```
.data
	aVariable DWORD 0x12345678
	anOtherVariable BYTE 0x11
```
The following instructions bring to the same result, that is loading `EAX` with a value of  `0x12345678`:
```
i) mov EAX, aVariable
ii) mov EAX, [aVariable]
```
Somehow in `i)` MASM "thinks" that we are not interested in "aVariable" as a label (a memory address) but rather to the actual value that is in memory. This why MASM conceptually treats it as a variable holding some value.

If we are interested into getting the address in MASM we use the `OFFSET` operator:
 ```
 mov EAX, OFFSET aVAriable
 ```
 This moves the address of "aVariable" into the `EAX` registry.

What if we want to **dereference it** ?
```
mov EBX, DWORD PTR [EAX]
```
It is more verbose but nearer to the high level languages. It is saying `go into memory at the address pointed by the value you have in EAX, take a DWORD (4 bytes) and load it into EBX`.

### Conclusion

This was just an initial introductory journey into the realm of (in our opinion) the most beautiful abstractions out there.
