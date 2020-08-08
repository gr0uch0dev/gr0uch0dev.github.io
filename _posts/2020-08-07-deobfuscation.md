---
layout: post
title: Malware deobfuscation
subtitle: Reverse Engineering of a deobfuscating procedure
date: 2020-08-07
categories: malware
---
### Intro
This post is dedicated to a deobfuscation procedure found in a malware named `srvcp.exe` and usually used by SANS for explanatory purposes. [Here](https://www.sans.org/security-resources/malwarefaq/srvcp) you can found the SANS report that covers the malware.

The aim of this writing is to go in depth on the reverse engineering of the deobfuscation procedure used by this malware.
We are not focusing on the malware analysis itself but we will use this as an exercise on Assembly code.

Usually malwares obfuscate the strings present in the compiled files. This is done with the aim of avoiding that an analyst could discover the malicious nature of the software just looking at the strings.

Just to set the context, the malicious purpose of `srvcp.exe` is to start an IRC client on the infected machine and connect to a specific server in order to get commands through a given IRC channel. The IRC protocol is therefore used to manipulate the bot that the malware is instantiating on the infected machine.

From the strings analysis of the executable well known IRC protocol commands like `PRIVMSG` are shown.

<a href="https://imgbb.com/"><img src="https://i.ibb.co/SxWFwSw/strings-with-encrypted.png" alt="strings-with-encrypted" border="0"></a>

But none of the strings look like human readable commands that could be used to control the bot. This a hint that the malware is obfuscating the commands. Also the presence of many strange looking strings is an indication in favor of obfuscation.

Notwithstanding in the moment those strings are needed, the program expects to have them in clear "text". This means that somewhere in the executable the non-sense looking strings are going to be deobfuscated.

### Deobfuscating procedure

The following picture shows a repeated call to a procedure that starts at address (srvcp.)004012C6.

<a href="https://imgbb.com/"><img src="https://i.ibb.co/3R6dkdb/deob-resized.png" alt="deob-resized" border="0"></a>

The argument is pushed on the stack before the calling. Such argument is the offset(the address) of a buffer of a null terminating characters' array. What we usually call a **string**. Such a string looks very strange. This is a hint that the subroutine called is going to deobfuscate the string.

We follow the call and get to a relevant code area. We have two ways to proceed now, namely static and dynamic analysis. The former consists of going through the procedure like a text, the latter is an active debugging of the subroutine.

**The question:** what is going on? How does the procedure deobfuscate the strings?

Following the code flow of the entire procedure during active debugging we can see that `EAX` holds, at the end of the subroutine, a pointer to a memory location where the clear string is stored.

<a href="https://ibb.co/CW1j7Fz"><img src="https://i.ibb.co/mSDnq7G/eax-holds-gus-ini.png" alt="eax-holds-gus-ini" border="0"></a>

`EAX` is usually used by compilers or assembly developers as the container for the results of a procedure. Namely either a ready to use value or a memory address where the results are stored.

In the top right of the above picture we have the values of the registers. `EAX` is loaded with a value of `0019F953` that is (as we can also see from the bottom left) a pointer to a memory location where a human readable string (`gus.ini`) is stored.

Furthermore, if we take a look at the stack, on the bottom right, we can see, as expected, the presence of the obfuscated and the clear string.

### Static Analysis of the procedure

We report here the entire procedure with the comments explaining how it works. This is what we usually refer as **static analysis**.

<script src="https://gist.github.com/gr0uch0dev/9565969ed2a0fb20e9bda66e3a09c70f.js"></script>
