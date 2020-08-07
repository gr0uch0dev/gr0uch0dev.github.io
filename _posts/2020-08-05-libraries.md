---
layout: post
title: Static (.lib) and Dynamic (.dll) Libraries
date: 2020-08-05
categories: MASM
---

### Introduction
Anyone who has any experience in programming is used to call procedures that have been implemented elsewhere.
For instance in Python we could import a `bar` function from a module named `foo` by writing something like `from foo import bar`. We are then able to call the procedure by typing something like `bar()`.

We would like to have something similar but at object level.

### Linking Objects

Objects are binary files intended for the machine. They are usually produced as the result of compilation by the compiler.
For instance if we deal with Assembly source code, the compiler will get a `.asm` file with human readable information and will convert it into an object file made by binaries.

With the process of linking two object files we could create a relation within their binaries.
For instance assume that we have two objects, namely `objectA` and `objectB`
If we use a pseudo instruction like `link objectA, objectB` we are telling the linker to look at the objects and fill in the necessary dependencies.
For instance in `objectA` we could have something that reads as "if you want to know what to do here go to `objectB`". When this is found by the linker, this will go to `objectB` and take the necessary binaries. Therefore the output of the linker will be an object that has the binaries of `objectA` but with "go to this X object" replaced with the actual binaries found there.
The result of objects linking is an **executable** file. Like objects also executable files are bunch of binaries intended for the machine.

### Libraries

Now that linking of two objects has been touched, lets dive into the actual concepts of static and dynamic libraries.
Those are nothing more then particular objects (actually indexed concatenation of objects) to be linked.
From here on-wards read to libraries as binary files.

#### A Use case for libraries

To understand them better lets consider a potential use case.
Suppose you ask a programmer to write a procedure for you to be used in your program.
Such a programmer is willing to accept your request but only upon the payment of a little price. Furthermore she does not want to share the source code of the procedure. How can she do that?

She will give you the compiled object of its own procedure and you will call it as a kind of "service". She will write her procedure in her desired programming language. Once done she will create from that a library `.lib` file  (made of binaries) that she will hand to you.

You then write your program calling her procedure but without providing any other information on the actual inner working of the function. We just say to the compiler: " I know I am calling something I did not define but be aware that the linker will receive an object with instructions on how to execute this procedure". Therefore the compiler will create an object leaving a space that will be filled later by the linker.

#### Filling the void with libraries

Assume we are dealing with an Assembly `.asm` program. Suppose also that, during the compiling stage, the compiler finds some procedures that, although declared and called, have never been defined(implemented) into the program itself. For the sake of our argument, refer to them as "external procedures".

As previously said creating the object file, the compiler will leave a space for the binaries that will have instructions on how the external procedures work.
Once the object file (binaries) is created there is a space that has been left to be filled by the linker. The latter has two ways to fill such a space, namely:
i) use all the binaries that define the behavior of the procedure
ii) use a reduced number of binaries that contain just instructions on where to go to find the desired binaries for the actual execution of the procedure

The previous two alternatives represent respectively the concepts of **static** and **dynamic** libraries.

**Static** means that the object will be complemented with all the necessary binaries resulting in a standalone executable. On the other hand with **dynamic** libraries the executable created cannot be used as a standalone file as it depends on some other sources where the instructions for the procedures are going to be found.

Suppose we have a program `myProg.asm` with a structure like the following:
```
declare the signature of the EXTERNAL_PROCEDURE
_____ other code ____
call EXTERNAL_PROCEDURE
_____ other code ____
```
 where we declare and call a procedure named **EXTERNAL_PROCEDURE** without never defining it.

Lets investigate the two ways to have a full program that is able to use such external procedure.

#### Static library (steps)

Assume we have a static library named `myStaticLibrary.lib` that holds all the binaries necessary to execute the procedure that we want to import into the object file created by `myProg.asm`. In order to inject the code into our program we link the compiled object with the static library. All the steps can be summarized as it follows.

1) Compile `myProgram.asm` into an object file

The compiler will see that inside the program there are external procedures not defined locally. The compiler leaves the space into the created object, say `myProgram.obj`, for later filling it with the necessary binaries.

2) Create the `myStaticLibrary.lib`  file

Write a program with procedures that are going to be imported by other objects and create a library file out of it.

3) Link `myProgram.obj` with  `myStaticLibrary.lib` to create a final executable `myProgram.exe`

The process of linking the `.obj` with a static library results into the creation of a standalone executable. This means that the space for the missing binaries that the compiler was not able to produce is filled with those found into the library. The output of the linker is in this case a `.exe` file that has all the information it needs to run the procedures embedded into it.

#### Dynamic libraries (steps)

In dynamic libraries the process is similar but conceptually different.

Suppose we have three files here, namely `myProg.asm`, `myDynamicLibrary.lib` and `myDynamicLibrary.dll`.

Note that also here we have a `.lib` file. But compared to the previous case these files have a conceptual difference. While in the static case it held all the binaries for the procedure, now its content is just informative of where to find the actual binary implementation of the procedure. Such a place holding the operational binaries of the procedure is `myDynamicLibrary.dll`.

Indeed, when using dynamic libraries the `.lib` file is used to tell just **where to find** the procedure rather then **how to execute** as in the static case.

The steps when using dynamic libraries are the followings:

1) Compile `myProgram.asm` into an object file

As in the static case. The compiler is not able, out of `myProgram.asm` alone, to create all the actual binaries needed to execute all the code. Inside the resulting object a **to be filled later** space is placed.

2) Create the `myDynamicLibrary.lib` and `myDynamicLibrary.dll`  files

Here the `.lib` file is not as heavy as in the static case. Indeed, instead of having the procedure's binaries, the `.lib` acts as a pointer to the `.dll`. It is the `.dll` that holds the binaries needed to execute the procedure.

3) Link `myProgram.obj` with  `myDynamicLibrary.lib` to create a final executable `myProgram.exe`

In the linker stage we link the object file previously created with the `.lib` file. Note that no `.dll` is used in the linker stage. Having been said that in this case the `.lib` does not hold the binaries to execute the procedure we should not expect to have a final standalone executable file out of this process. This means that `myProgram.exe` needs to be able to access to `myDynamicLibrary.dll` while executing.

### Conclusion

To conclude, we can say that with static libraries we insert the code at compile time while for dynamic libraries the necessary code is injected at runtime.

For the creation of a static library and its usage check the post [here](../2020-08-06-include_and_libraries).
