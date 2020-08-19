---
layout: post
title: The stack and the stackframe
subtitle: A graphical explanation of how the stack is used in Assembly
date: 2020-08-19
categories: MASM
---

In general terms the stack is a **data abstraction** that works as a **LIFO** container for objects.

In this post we consider the stack that is used by the CPU. This is built on top of memory addresses and is managed by a mechanism in which the `ESP` register is used.

This register acts as a pointer, holding a memory address that works as the basis for the stack.
The following picture shows how the `ESP` register that seat on the CPU points to a memory address.

<div class="text-center">
<a href="https://i.ibb.co/S31qJrd/cpu.png"><img src="https://i.ibb.co/S31qJrd/cpu.png" alt="cpu" border="0"></a>
</div>

Stacks are modified by **push** and **pop** instructions. These, respectively, add and remove data from the stack.

In our case **pushing** an object onto the stack means:

 1. Take the address that is in `ESP`
 2. Reduce it by a fixed amount of bytes (depending on the memory model of the architecture)
 3. Go to the address just computed `[ESP]` (dereference)
 4. Pour the data into the memory starting from that address

We see that pushing onto the stack reduces the address to which the stack pointer is referencing to. This is the reason we usually say that "the stack grows **backwards** in memory".

Take for instance the memory model that deals with 32-bit addresses. Here **pushing** an object on the stack translates into:

- i) decreasing the value of `ESP` by 4 bytes (it grows backwards in memory)

- ii) placing the object in the memory location pointed by the just reduced `ESP`

Suppose that `ESP` holds a starting value of `0x00401004`. This means that the stack basis is positioned at memory location `0x00401004`.  The following picture illustrates the current situation.
<div class="text-center">
<a href="https://i.ibb.co/6tzyBKc/detailed.png"><img src="https://i.ibb.co/6tzyBKc/detailed.png" alt="detailed" border="0"></a>
</div>
Say that we now want to push on the stack the content of the `EAX` register that we assume to be  `0x12345678`. The opcode to achieve this is:`push eax`. What does actually happen behind the scenes?

We just said that **pushing** translates into reducing the stack pointer and placing the data into memory.
When the CPU executes `push eax` the `ESP` is decremented by 4(bytes) since the memory model is 32-bit.
Now we have `ESP = 0x00401000`. The CPU then places the value of `EAX` (what we are pushing onto the stack) at the memory address `0x00401000`.
Recall that values in memory are stored using **little eandianess**. This means that the least significant byte is stored first. In our example we are going to find byte `0x78` at address `0x00401000`, byte `0x56` at address `0x00401001` and so on.

The `push` can be seen as a two-step operation.

**Step 1**. Reduce `ESP` by four bytes in order to get the memory address where the object is going to be stored.
<div class="text-center">
<a href="https://i.ibb.co/F5vxnm1/sub-esp.png"><img src="https://i.ibb.co/F5vxnm1/sub-esp.png" alt="sub-esp" border="0"></a>
</div>
**Step 2**. Take the content of `ESP` (a memory address) and dereference it (`[ESP]`) in order to store the object in memory.
<div class="text-center">
<a href="https://i.ibb.co/QKQ9Cmw/mov-eax.png"><img src="https://i.ibb.co/QKQ9Cmw/mov-eax.png" alt="mov-eax" border="0"></a>
</div>
### The stackframe

We now want to explore how the stack is used by procedures.
We refer to the **stackframe** as the part of the stack used by the procedure including the space in which arguments and local variables are stored.

For this post we consider that the x86 STDCALL convention is in place. This results into passing the procedure's arguments (in reverse order) through the stack and posing the responsibility to clean the stack on the **callee**.

Suppose we have a procedure named `addTwo` that takes two 4-byte arguments (`num1, num2`) and performs simple arithmetic addition.
Accordingly to the convention here used, the result of the procedure is expected to be stored into `EAX`, the accumulator register.

Calling a procedure translates, in terms of Assembly instructions, into performing a `push eip` (in order to be able to come back to the current execution line later) followed by `jmp PROCEDURE_ADDRESS`.
Where with `PROCEDURE_ADDRESS` we refer to the address label where the beginning of the procedure is set.

MASM gives us useful directives to be used for writing procedures, `PROC` among these. But directives are instructions for the Assembler. As such they will be translated into Assembly code to be compiled later. Under the hood of `PROC` are memory labels to be jumped at when calling the procedure.

Our interest here is in what happens behind the scenes. We are used to `call` while writing our Assembly program. But what such `call` instruction does is actually pushing the instruction pointer on the stack and jumping to a memory location where the procedure has been defined.

```
push num2 ; num1 and num2 are two 4-byte integers
push num1 ; pushing of the arguments in reverse order
call PROCEDURE_ADDRESS
```

At the time when the `EIP` reaches the  `call` opcode assume that the stack pointer (`ESP`) is equal to `0x00451000`. According to the convention used the arguments have already been pushed on the stack once the CPU is ready to execute the `call`. The stackframe (just stack from here onward) is made by the objects represented in pink in the following picture. Blocks that are not part of the stack are shown in violet.
<div class="text-center">
<a href="https://i.ibb.co/Xxnc5PN/stack-before-call.png"><img src="https://i.ibb.co/Xxnc5PN/stack-before-call.png" alt="stack-before-call" border="0"></a>
</div>
In the previous picture 4-byte blocks are presented. This justifies the difference of 4 between the addresses displayed. In the other cases we were presenting the bytes one by one.  

Leave aside for a moment the actual addresses and just consider blocks made by 4 bytes.

When the `call` instruction is reached and the first lines of the procedures are executed the stack is
<div class="text-center">
<a href="https://i.ibb.co/qDNc4HK/initial-stack.png"><img src="https://i.ibb.co/qDNc4HK/initial-stack.png" alt="initial-stack" border="0"></a>
</div>
As previously said, calling means `push eip` and `jmp` to the procedure address.
Generally a procedure in its first lines of the body pushes on the stack the base pointer (`push ebp`), copies the value of `esp` into `ebp` (`mov ebp, esp`) and  decreases the stack pointer by a desired amount of bytes (`dec esp, X_BYTES`). In this way the procedure can use `ebp` and `esp` to refer to the objects on the stack. The original value of `ebp` is then restored at the end of the procedure.

The next picture shows the stack while the CPU is executing the main body of the procedure.
<div class="text-center">
<a href="https://i.ibb.co/8sY5MW1/final-stack.png"><img src="https://i.ibb.co/8sY5MW1/final-stack.png" alt="final-stack" border="0"></a>
</div>

When the procedure reaches the end of its body all these pink blocks labeled with `4 BYTES` are cleaned from the stack. **Cleaning** here means that the stack pointer has moved forwards in memory **freeing** the memory.
Indeed, once all the stack bytes below `EBP` are used, the stack pointer goes back to the offset of the memory address where `EBP` is stored.
The following pictures shows the stack once the procedure has used and freed all the blocks that were needed for the execution of its functional body.
<div class="text-center">
<a href="https://i.ibb.co/WyDf4qk/stack-end.png"><img src="https://i.ibb.co/WyDf4qk/stack-end.png" alt="stack-end" border="0"></a>
</div>

We are used to read `ret` followed by a number of bytes at the end of a procedure. What an instruction like `ret 8` performs behind the scenes is `add esp, 8` followed by `pop eip`. On the one hand, the addition on `esp` cleans the stack of the arguments that were passed to the procedure. On the other hand `pop eip`  allows the CPU to go back to where the `call` to the procedure took place.

What happens to the stack when `ret 8` is executed by the CPU is shown in the next picture.
<div class="text-center">
<a href="https://ibb.co/tDrgyqS"><img src="https://i.ibb.co/PgHKBcR/final.png" alt="final" border="0"></a>
</div>


## Conclusion

We have seen that in the STDCALL convention is the **callee** to clean the stack. In our case this is done with an instruction like `ret 8`.
The presence of `ret` tells the CPU to `pop` the instruction pointer so that it can go back where the jump took place in order to reach the procedure. Now the CPU is ready to execute what followed the `call` instruction. **But** the argument `8` used with `ret` tells the CPU that before moving on to the opcodes following `call` it has to execute an other additional instruction. Namely `add esp, 8`. This performs the cleaning of the stack from the arguments that were passed to the procedure. Now that the stack has been cleaned the CPU is ready to go on with the instructions following the procedure's `call`.
