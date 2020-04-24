---
layout: post
title: Masm is Not Nasm
date: 2020-04-24
categories: MASM
---

**Disclosure**: These are notes written by myself, a newbie in learning Assembly. I like to study by writing notes and make assumptions on what is going on. The former because I can retrieve them better and I would also like if they could be of any help to somebody. The latter because I love learning by making assumptions on what I read/experience and have more experienced people correcting me. So if you find something wrong here, **PLEASE** and I say **PLEASE** write in the comments or create a pull request for the article with your own considerations.
As you would see when I encounter something curious I like to pause and ponder. Although most of my speculations at the ends turn out to be wrong I found out that this is the best way in which I could learn a topic.

## A procedure to compute the length of a string

Everything started when we were trying to implement a procedure whose main functionality was to determine the length of a null terminated string placed somewhere into memory.

It seems to us that there is a **subtle** difference between MASM and NASM. With subtle we mean **conceptually** relevant.

Is MASM doing some assumptions on the instructions that could make the NASM reader confused?

### Accessing a byte into memory

To put in context suppose we are dealing with MASM and we have a data segment like the following:

    .data
    var BYTE "This is just a null terminated string", 0

Our aim is to write a procedure `GetStringLen` that, as the name implies, computes the length of a null terminated string.
Before exploring the procedure lets ask a question: how could we get the char (Ascii byte) 'T', i.e. the first element of `var`?

Just for a matter of comparison consider firstly the NASM case.

**Quick parentheses on NASM**

In **NASM** we are taught that **variables do not exist, labels do**. Therefore we need to interpret `var` as a label, that is nothing more than an alias of a memory address. In NASM,`var` holds the address where the first byte of the string appears. Be careful to the above **"holds"**. We should read it as **is**. Indeed `var` is an address (just aliased by a name).

Therefore if we want to get "T" in `al` we type `mov al, byte[var]` that means "go to the address that you get from `var`. From what you find placed in memory at that address (`[var]`) take just one byte".

**Back to MASM**

In **MASM** the same is achieved with `mov al, var` that for NASM sounds **strange**. MASM automatically thinks that we are interested into what is in memory at that adress( labeled with `var`) rather than the address itself.
Does it really help us? We don't know! Yes, it is true that it is nearer to the language of an high-level programmer who is used to the concept of variables. It is easy to think at `var` like holding the value of the string(or part of it). **But** we are at Assembly level, behind the hood, breathing the air of the engine room. In our view we prefer the way NASM works.

Furthermore in MASM getting the Ascii byte code for 'T' could be also achieved with this `mov al, BYTE PTR [var]`. In the latter MASM is interpreting `var` as an address label as we would expect comparing it with NASM. Indeed here `BYTE PTR[var]` is equivalent to what we would have done in NASM with `byte[var]`.

To sum up, in order to have two equivalent instructions (for NASM and MASM respectively) we should consider using the OFFSET operator in MASM. `NASM: var`and `MASM: OFFSET var` are conceptually the same. But still, what we are doing in MASM smells something you would do in C typing `&var`.

After this digression lets continue with our procedure implemented for MASM.

We make  `GetStringLen PROTO, lp_string:DWORD` be the prototype of the function. Therefore we expect to call the procedure by passing to it a pointer to the string (i.e. the OFFSET of lp_string). Using the invoke directive we would type `Invoke GetStringLen, ADDR var`. Where `ADDR` is the operator in place of `OFFSET` when dealing with `Invoke`. We are using **directives**(like Invoke and Proc) in this example to make it less verbose. Notwithstanding we need to remember that directives are the language of the preprocessor and that they will be expanded into Assembly code. They are in other words, what somebody could see as kind of **syntactic sugars**.

Just for the sake of explanation lets put some numbers got from the actual execution of the program. Before invoking the procedure we have `OFFSET var` that is equal to `0x00404028`. If we were going now to see what is in memory at that address we would find `54 68 69 73`, where 0x54 is the hex Ascii code for 'T', the first character of our string.

#### In the procedure body

Now we invoke the procedure  `GetLenString`. Suppose for a moment of being in the body of the procedure. The parameter `lp_string` gets the value of the argument passed (`ADDR var`). Here a question arises. `lp_string` is equal to `ADDR var` or contains it? Very very subtle difference! But when we work with Assembly is very useful to ask ourselves those questions. Actually since MASM was playing with a concept of "variable", as seen above, those questions are far from stupid. How do we answer them? Dump memory!

Inside the procedure we can do `mov edx, lp_string` and check the register value. Inspecting `edx` we find a value of  `0x00404028`. This means that `lp_string` **is** `ADDR var`.

Here the beauty happens.

With this just said we would expect inside the procedure to be able to do something like `movzx edx, BYTE PTR [lp_string]` to get the first byte( Ascii "T"). Why do we expect it to work? Check above when we used OFFSET var outside the procedure. **But** whatever our assumption is, **it doesn't work!**.

**Very strange behavior**

Why strange? Because, as previously said, when we are outside the procedure and we run:

`  mov edi, OFFSET var
   mov al, BYTE PTR [edi]`

everything work as expected. The above snapshot of code means "take the address of `var` and copy it into `edi`, then go to the memory location stored inside `edi` and check what is at that address `[edi]`. From the data you find there take just the first byte." So far so good, everything works.

 We said that `lp_string` holds an address, that is the same we get with `OFFSET var` and so the same that we stored in `edi`. Therefore `lp_string` and `edi` should hold the same value (an address to a location we are interested into).  But  `BYTE PTR [edi]`and `BYTE PTR [lp_string]` return two different values.

Notwithstanding if we try something like this in the body of the procedure
`mov ecx, lp_string
 movzx edx, BYTE PTR [ecx]`

 it works like a charm and we get the desired value in `edx`.

Therefore some feature of MASM is going to cause our misunderstanding. What does MASM do when it encounters `BYTE PTR [lp_string]` ?

Recalling form the numbers of our example that we had lp_string = 0x00404028 that was the offset of these 4 bytes in memory   `54 68 69 73`.

Lets considering the following lines of code.

    1- mov ecx, [lp_string];
    2- mov eax, lp_string
    3- mov esi, [ecx]
    4- movzx edx, BYTE PTR [lp_string]

At line 1 `ecx` gets a value of ` 0x00404028` that is the same got by `eax` at line 2. This means that the `[]` operator is not doing anything on lp_string.

At line 3 `esi` gets a value of `0x73696854` (as expected) since data in memory is stored in little endianess. With this meaning that if we want to get 4 bytes from memory the first byte we are going to see is the LSB of the block (here 0x73).

But at the 4th line we get `EDX = 00000028` instead of `00000054` as we were expecting.

What is this **0x28**? It seems to be the last byte in `lp_string` and it actually is! `lp_string` is indeed equal to `0x00404028`. MASM with `BYTE PTR [lp_string]` is not dereferencing `0x00404028` but rather interpreting it as a block to where extrapolate the byte( BYTE PTR). Recall that little endianess is in place so MASM seeing `0x00404028` like a block of memory it knows that the first byte to encounter is 0x28. Indeed if we are going to look at this block into memory we would see `0x28 0x40 0x40 0x00`.

### Final implementation of the procedure

Therefore we could implement a procedure to get the length of a string like the following:
```
GetLenString PROC USES esi edx ebx, lp_string:DWORD
    xor esi, esi
    L1:
      mov ebx, [lp_string]
      movzx edx, BYTE PTR [ebx + esi]
      cmp dl, 0
      je quit
      inc esi
      jmp L1
    quit:
      mov ecx, esi; save the length of the string into ecx
      ret
GetLenString ENDP


```

**Lesson to take home: Masm is not Nasm!** As stupid as it sounds we should be very careful conceptually.
