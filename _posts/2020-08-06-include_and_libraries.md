---
layout: post
title: Includes and static libraries in Assembly
date: 2020-08-06
subtitle: A step by step process in Visual Studio 2019
categories: MASM
---

For a general discussion on libraries check the post [here](../2020-08-05-libraries).


In this tutorial we want to

1) create a static library `.lib` using an object built from an Assembly `.asm` file

2) create a `.inc` file holding the macros that are going to be used in the main program

3) crate the main assembly program that includes the `.inc` file just made

The actual files we are going to deal with are the following:

 - `groucho32.asm` -> This will be compiled into an object. Out of the object the `groucho32.lib` is going to be built

 - `groucho32.inc` -> This includes macros that will be included into our main program. In turn, these macros use the procedures defined into `groucho32.asm` and compiled into `groucho32.lib`

 - `useGroucho32.asm` -> This is our main program. It includes the macros defined in `groucho32.inc` and will, therefore, call the procedures compiled in `groucho32.lib`

### The programs

**useGroucho32.asm**
<script src="https://gist.github.com/gr0uch0dev/8833ded87804ce439abd8d05f108318b.js"></script>

**groucho32.inc**
<script src="https://gist.github.com/gr0uch0dev/40ee69be4974da69422068e4c7876cb4.js"></script>


**groucho32.asm**
<script src="https://gist.github.com/gr0uch0dev/937001f4e4c004e92eb26d749093c8b1.js"></script>


### All the steps in Visual Studio 2019

#### Creating the static library

The first step is to create a new **static library** project.

<a href="https://ibb.co/37bxvMW"><img src="https://i.ibb.co/SPgkcd0/static-lib-option.png" alt="static-lib-option" border="0"></a>

We clean the initial project of all the unnecessary components that VS has included due the project template we chose. Since we are not working with a library built out of C++ source code we can get rid of some stuff.

<a href="https://ibb.co/9ZrX7sG"><img src="https://i.ibb.co/Y0L9xpb/clean-initial.png" alt="clean-initial" border="0"></a>

Right clicking on the solution, we go to `build dependencies -> build customizations` and make sure that `masm` is included into the dependencies.

<a href="https://ibb.co/S6PcptG"><img src="https://i.ibb.co/WH601kj/build-masm-dependency.png" alt="build-masm-dependency" border="0"></a>

We then add a new file to our solution and name it `groucho32.asm`. The object that the compiler will create out of this file is going to be part of the `groucho32.lib` library.

<a href="https://ibb.co/q7Xb0LP"><img src="https://i.ibb.co/PF3BTsf/groucho32-asm-creation.png" alt="groucho32-asm-creation" border="0"></a>

We make some adjustments to the project solution properties. We want the `.lib` output to be saved into a subfolder of the `C:` root and change the target name to `groucho32.lib`

<a href="https://ibb.co/T2Y5rjW"><img src="https://i.ibb.co/XLjTV0Y/groucho32-properties-solution.png" alt="groucho32-properties-solution" border="0"></a>

We are now set for the building of the project. Once built we find that our `.lib` static library has been created into the desired destination.

<a href="https://ibb.co/wYL65Wd"><img src="https://i.ibb.co/DLbK0C1/groucho32-lib-created.png" alt="groucho32-lib-created" border="0"></a>


#### Creating the main program

We now setup a new empty project and clean all the unnecessary components as done in the previous case.

<a href="https://ibb.co/vzFvFd7"><img src="https://i.ibb.co/0J7V79g/empty-project-new.png" alt="empty-project-new" border="0"></a>

We add `useGroucho32.asm` to our solution. We make sure that `masm` is included into the build dependencies. We also right click on `useGroucho32.asm` file and check that it has been included into the building process.

What are the peculiarities of `useGrucho32.asm`?
Let us leave aside for a moment the importing of the Irvine library, we see that the program is including `groucho32.inc` and `groucho32.lib`.

From `groucho32.inc` our program is going to take the `mWriteStringToConsole` macro. The text in the macro's body will be expanded into `useGroucho32.asm` before compilation at the place where it has been used.

This means that we need to tell our project where to go to find `groucho32.inc`.

In turn `mWriteStringToConsole` is calling a procedure, namely `GetLenString`, that is just declared but not defined. Where is the body of the procedure been implemented? In `groucho32.asm`!

But this file was created in our previous project. Suppose we do not have access to the source code but just to the `.lib` library that has been created out of it. We then need to `include groucho32.lib` into our `useGroucho32.asm` and to tell the building process where to look for such a library.

For explanatory sake lets have both the `.lib` and `.inc` files in the same folder. We take `groucho32.inc` and save it into the same location where the process of library creation produced `groucho32.lib`.

We then go to the solution properties and tell all the required information for the building to occur.

Our program also depends on the **Irvine** library. Therefore together with the information about the **Groucho** library we tell the build manager where to look for all the dependencies (includes and libraries).

The first thing we do is telling the Assembler where to look for **include** files. We do it in the `MASM` tab of the solution properties

<a href="https://ibb.co/60vdcZY"><img src="https://i.ibb.co/VYHK0NV/include-assembler.png" alt="include-assembler" border="0"></a>

We fill the information in

<a href="https://ibb.co/R9WrM2K"><img src="https://i.ibb.co/6m59pYS/groucho-irvine-32-inc-propreperties.png" alt="groucho-irvine-32-inc-propreperties" border="0"></a>

Recall that **includes** are a matter of the Assembler due to the fact that everything happens before compilation. On the other hand **libraries** are food for the linker, which creates an executable file out of compiled objects.

Once done with include files we move on the libraries. We go to the `Linker -> General` tab in solution properties and specify the location for additional directories where dependencies could be found.

<a href="https://ibb.co/GJkpb7T"><img src="https://i.ibb.co/MhpS3n6/linker-additional.png" alt="linker-additional" border="0"></a>

<a href="https://ibb.co/1KCxdvB"><img src="https://i.ibb.co/ft37n1Z/additional-directories-with-info.png" alt="additional-directories-with-info" border="0"></a>

We are not set yet. We need to specify which additional libraries are going to be imported from the directories just referenced.
We go to the `Linker -> Input` tab of the solution properties and add the `groucho32.lib` and `irvine32.lib` file.

<a href="https://ibb.co/Xxgp50f"><img src="https://i.ibb.co/8gp2xvn/additional-dependencies-library.png" alt="additional-dependencies-library" border="0"></a>

Now everything is ready for the build to run.
The following output is telling us that the process was successful.

<a href="https://ibb.co/swr0Vjb"><img src="https://i.ibb.co/k8FRSK5/build-success-final.png" alt="build-success-final" border="0"></a>

We can debug the programm and see the following Console output.

<a href="https://ibb.co/PDMdDTk"><img src="https://i.ibb.co/sWCZW57/final-output.png" alt="final-output" border="0"></a>
