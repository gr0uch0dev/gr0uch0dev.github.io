---
layout: post
title: Table-driven technique in Assembly
subtitle: A commented example
date: 2020-08-21
categories: MASM
---

In this program we explore the **table driven** technique to decide which procedure to use.

We have a two-column table where the first column holds the index while the second the procedure to be used.


The program we want to write performs logical operations on integers provided in hexadecimal form.

The user can decide among different options:
```
1. x AND y
2. x OR y
3. NOT x
4. x XOR y
5. Exit program
```

The table used to manage which procedure is to be called is the following
```
  table BYTE '1'
        DWORD op_and
  entrySize = ($-table)
        BYTE '2'
        DWORD op_or
        BYTE '3'
        DWORD op_not
        BYTE '4'
        DWORD op_xor
        BYTE '5'
        DWORD op_exit
  tableNumEntries = ($ - table)/entrySize
```

`entrySize` is equal to the space occupied by an index in the table (here a single BYTE) and the address of the procedure (4 bytes if in 32-bit model). `entrySize` is then used to compute `tableNumEntries` that is the number of table entries (considering index and value).

The idea is easy. The user makes a choice. The program then compares it with the indexes in the table. The procedure next to the first index that matches with the choice is the one to be called. We have to manage the occurrence of no matches between the user's choice and the indexes.

Suppose, for instance, the user inputs `3`. We then expect the procedure performing logical not (`op_not`) to be executed.

The program iterates over the table and as soon as the index `'3'` is found it calls the procedure stored at the address next to it.

Since the user has inputted a valid character, i.e. one that is in the table indexes, the flow of execution is moved into the code area labeled with `L2_entry_found`. Here we find the following code

```
  L2_entry_found:
      ; the entry has been found in the table indexes
      ; user has chosen '3'
      ; ebx is therefore pointing to the OFFSET of the index '3'
      call NEAR PTR [ebx + 1] ; call the procedure just next to it (here is op_not to be called)
      ; we expect the result into eax (STDCALL convention)
      mov result, eax
```

What the procedure does is not the main interest of this post. We wanted to focus here on how conditionals procedures calls are managed through a table-driven technique.

The overall code with comments follows.

<script src="https://gist.github.com/gr0uch0dev/c5c8856b0cd1242118a4ad2df219e9e3.js"></script>
