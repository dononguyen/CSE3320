# How to debug the UVA OS

https://github.com/fxlin/uva-os-world1/blob/student/docs/gdb.md


## Table of Contents

- [1. Setup](#1-quick-setup)
- [2. Commands cheatsheet](#2-commands-cheatsheet)
- [3. Kernel debugging](#3-kernel-debugging)
- [4. User program debugging](#4-user-program-debugging)
- [5. Debugging with real hardware](#5-debugging-with-real-hardware)
- [Appendix: the GDB "dashboard" enhancement](#appendix-the-gdb-dashboard-enhancement)
- [Other enhancement (FYI)](#other-enhancement-fyi)
- [Troubleshooting](#troubleshooting)
- [Reference](#reference)

## 1. Setup

### Quick start for UVA-OS VM users:
In one terminal: 
```
./dbg-rpi3qemu.sh
```
In another terminal: 
```
gdb-multiarch
```

### Detailed commands
#### Installation
```
sudo apt install gdb-multiarch gcc-aarch64-linux-gnu build-essential 
```

#### Launch QEMU + GDB

Example commands:

```
qemu-system-aarch64 -M raspi3 -kernel ./kernel8.img -serial null -serial stdio -s -S
```

From another terminal

```
gdb-multiarch build/kernel8.elf 
(gdb) target remote :1234 
(gdb) layout asm 
```

The port number (e.g. 1234) must match what you specified for QEMU.

#### To automate the above
append the following to ~/.gdbinit:

```
file kernel/build-rpi3qemu/kernel8.elf
target remote :1234
```

## 2. Commands cheatsheet

### Breakpoints 

| Action                  | Command                        |
|-------------------------|--------------------------------|
| Set breakpoints         | `b *0xffff0000` or `b my_function` |
| Conditional breakpoints | `b main.c:42 if x == 5` |
| Show breakpoints        | `info b`                       |
| Delete a breakpoint     | `delete 1` or `d 1`            |
| Disable a breakpoint    | `disable 1`                    |

### Single step

| Action                | Command |
|-----------------------|---------|
| Step an instruction   | `si`    |
| Step a statement      | `n`     |

### Stack frame

| Action                | Command       |
|-----------------------|---------------|
| Show stack frame      | `bt`          |
| Select a frame        | `frame 1`     |

### Register

| Action                | Command                          |
|-----------------------|----------------------------------|
| Dump register contents| `info reg`                       |
| Show reg information  | `display/10i $sp`                |

### Memory dump

| Action                                    | Command                |
|-------------------------------------------|------------------------|
| Dump memory at a given symbol as instructions | `x/20i _start`         |
| Dump memory at a given symbol as hex (bytes) | `x/20xb _start`        |
| Dump memory at a given symbol as hex (words) | `x/20xw _start`        |
| Dump memory at a given symbol, as hex (64bit long)   | `x/2gx _start`          |
| Dump memory at a given symbol as a textual string | `x/s _start`         |
| Dump memory with register as base addr    | `x/s $x0`              |
| Dump the current frame record (two 64-bit long at x29/fp)   | `x/2gx $x29`          |
| Dump memory at a given addr, as four instructions               | `x/4i 0x9b8c`          |


### Print out variables/structures

| Action                                      | Command                        |
|---------------------------------------------|--------------------------------|
| Print the value pointed by `mem_map`        | `print *mem_map`               |
| Print the first 10 elements of `mem_map`    | `print (short[10])*mem_map`    |
| Print the 0th task_struct (`struct task_struct *task[NR_TASKS]`) | `print *task[0]` |
| Print the address of task_struct of the current task on cpu0 | `print cpus[0].proc` (and its name `print cpus[0].proc->name`) |

### Disassemble instructions

| Action                                      | Command                        |
|---------------------------------------------|--------------------------------|
| Disassemble at a given address              | `disas 0xffff0000`             |
| Disassemble at a given function             | `disas kernel_main`            |

### One liner - disassemble at given addr (from shell)

| Action                                      | Command                        |
|---------------------------------------------|--------------------------------|
| Disassemble at a given address from shell   | `gdb -nx -batch -ex "disassemble 0x<address>" ./a.out` |

`-nx` prevents GDB from loading `~/.gdbinit`, `-batch` prevents GDB from entering interactive mode, and `-ex` executes the command in quotes.

The command above will disassemble the entire function that contains the given address.


### Function/source lookup

| Action                          | Command                    |
|---------------------------------|----------------------------|
| Look up type of a given symbol  | `ptype mem_map`            |
| Find out function name at a given addr | `info line *0x10000000` |
| List source at a given addr     | `list *0x10000000`         |
| List source at a pointer        | `list *fn`                 |
| Source code of the current instruction | `info source`         |

### Watchpoint (SUPER POWER 🚀)

| Action                          | Command                    |
|---------------------------------|----------------------------|
| Break if the given memory addr is changed | `watch *0xffff0000` |
| (... or watch an variable | `watch  (*idle_tasks[0]).parent `|

watch an address *range* seems unsupported by GDB. 

### Multicores (useful for debugging deadlock)

| Action                          | Command                    |
|---------------------------------|----------------------------|
| Show all cores                  | `info threads`             |
| Switch to a core                | `thread 1`                 |
| Show stack trace on core        | `bt`                       |
| Show registers on core          | `info regs`                |

### Important commandline tools (not GDB)

| Action                          | Command                    |
|---------------------------------|----------------------------|
| Find source location given an address                   | `addr2line -e kernel8.elf 0x1000`             |
| Find a instruction, given an address           | Search in `kernel8.asm` with the address                  |

## 3. Kernel debugging 

Basic tools: printf(); GDB: breakpoint, single step, backtrace (`bt`). 

### Prelim: virtual vs. physical addr

In GDB, when we set up a breakpoint using function names or source lines (e.g., `b start_kernel`), GDB uses the linking information in the ELF file to set up the breakpoint.

- If the kernel completely runs on physical addresses, link addresses are equal to runtime addresses (PA). So there is no ambiguity.

- If the kernel links to virtual addresses, typically it boots running on physical addresses, then switches to virtual addresses.

    - Before the switch, GDB cannot associate the memory address (PA) with debugging info (which is based on VA). Therefore, it cannot list source code or set breakpoints based on source code or function names. We can still set breakpoints based on physical addresses (e.g., `b *0x80000`).

    - After the switch, link addresses are equal to runtime addresses (VA). So we can set breakpoints based on source code or function names.

### Kernel crash with an exception message "Unhandled exception..." 

To debug, we have to find the instruction (and the surrounding code) that caused the exception. 

From the messages, check the following: 

- ELR (Most useful): likely the instruction that causes the problem); 
- ESR (sometimes useful): contains the causes of the exception (e.g bad instruction). Use online decoder
- FAR (sometimes useful): faulty address

Can set a breakpoint directly at the exception handler, and do `bt` to see the call stack.
If there's a meanginful one, we are good and hunt it down; 
if there's no one (e.g. showing repeated stack frames), the stack may be corrupted or we are in repeated exceptions. 

Can find a most recent source location that the kernel is known to be running 
(e.g. based on kernel messages), add more debug messages, and re-run. 
Eventually we can narrow down to one instruction. 

Then understand why it causes the exception. This could be an easy case, e.g., a
program error that results in a bad pointer. Often the fixes are
straightforward.

The problem can be more complex, e.g., some variables have strange values
(corrupted) or instructions in memory are corrupted. These can be identified via
GDB commands. In this case, set a breakpoint at places that precede the crash
site and check if the memory contents are correct. If the memory contents are
still bad, set the breakpoint to a location that was executed earlier. Continue
this process until you find a location where the memory contents are correct.

From there, set a *watchpoint* to the memory location that is corrupted and run
the program. This will break the program when the memory is written. Then you
can find out where the memory is being corrupted.

### Kernel hangs, no error messages

Try to add printf statements and narrow down to the function/code/instruction that hangs.

### Multicore issues?

Mostly race condition and deadlock. 
- Ensure it's a multicore issue by recompiling the kernel with a single core and checking if the problem persists.
- To debug a multicore issue, recompile the kernel with two cores and diagnose.
- Use `info threads` to list all cores and `bt` to show the stack trace for each core.

## 4. User program debugging 

We debug user program with GDB. Our OS has no debugger as a native user program. 

### Make sure your elf have debug info

We need a user program with symbols and debugging info. 
- All programs included in ramdisk are stripped of such things to be small, e.g. "nplayer"
- Their versions with debug info is named as, e.g. "nplayer.debug"

To verify: do `file nplayer.debug` and look for "with debug_info".
```
$ file nplayer
nplayer: ELF 64-bit LSB executable, ARM aarch64, version 1 (SYSV), statically linked, BuildID[sha1]=3dafe6adf5ef14ad3b1bccd42c9f88f029a9c83b, not stripped
```
wheras
```
$ file nplayer.debug 
nplayer.debug: ELF 64-bit LSB executable, ARM aarch64, version 1 (SYSV), statically linked, BuildID[sha1]=3dafe6adf5ef14ad3b1bccd42c9f88f029a9c83b, with debug_info, not stripped
```

### Offline: check instruction given an addr
This can be useful for for "Unhandled exception at EL0". 
We often take the reported ELR and check where is it in the user code. 

Say we know the current running program is "buzz" and ELR=0x1000, then open "buzz.asm" and search for "1000".

### addr2line: find source line given an addr: ``addr2line -e nplayer.debug 0x1000``
The program must have debugging info.

### Offline: disassemble a function given an addr 

(See the gdb "disass" command above) 

### Set breakpoint in a user process

Although the CPU switches between EL0 (user) and EL1, GDB breakpoints are only concerned with addresses.

First, launch the kernel with GDB, then continue ("c") and let the kernel boot into VA.

Once the OS reaches the shell (or even starts running the target app), interrupt GDB (by pressing "Ctrl+C").

Then we can set the breakpoint with user VA if we know the VA in question (by looking at their *.asm or *.sym files).

We can set the breakpoint at source location or function names if we do the following: replace the kernel ELF file with the app's ELF file, e.g., `file nplayer.debug` then confirm. See [screenshot](image-9.png)

Watchpoints also work in this way.

## 5. Debugging with real hardware

Primary means: printf(); find out faulty addresses and look up with offline tools (addr2line, disassembly, etc).

No GDB. No JTAG. 

Try the following things in order: 
- Reproduce the bug in QEMU. Even if the symptoms differ (e.g., hangs vs. crashes), the root cause is often related. Debugging in QEMU can help identify the issue.
- Reduce the core count to 1 (change `param.h`) and re-run. If the problem persists, it is easier to debug; if the problem is resolved, it is likely a race condition.
- Enable additional debugging information for the source that is likely problematic.

### What if things work on QEMU, but break on real hardware? 

A list of factors that could contribute to this discrepancy:

- The non-determinism of multicore. Real multicores are not as deterministic as QEMU. Reduce the core count to 1 and re-run.
- QEMU's emulation of CPU behaviors is simplistic, especially:
    - Cache coherency
    - Cache flush (e.g., not flushing cache is OK with QEMU, not with real hardware)
- Uninitialized memory on QEMU will be filled as 0 (mostly); on real hardware, it's a random mess.
- QEMU's emulation on IO devices is different, e.g., the framebuffer physical addresses are different.

Think if your bug may be related to these factors.

Compare the debug messages between a "good run" and a "bad run". Start from the discrepancy.

### What if things work on real hardware, but break on QEMU?

QEMU's emulation of the framebuffer, especially virtual offsets, is incomplete (as of version 9, unlikely to improve).

Beyond that, I wouldn't worry too much -- the real hardware is the gold benchmark.


## Appendix: the GDB "dashboard" enhancement

The basic GDB UI is too primitive to beginners. We provide you an enhancement called GDB-dashboard. The upstream source is [here](https://github.com/fxlin/gdb-dashboard-aarch64). I adapted it for aarch64. Screenshot: 

See [screenshot](https://raw.githubusercontent.com/fxlin/gdb-dashboard-aarch64/master/gdb-dash-aarch64.png)

### Installation

Grab from my repository: 

```
wget -P ~ https://raw.githubusercontent.com/fxlin/gdb-dashboard-aarch64/master/.gdbinit
```

There's only one file: `.gdbinit`. It's the initial script that GDB will load upon start. The above line download it to your home directory. 

#### Set your port

Open ~/.gdbinit. Go to near line 2500 where you can see initialization commands for GDB, e.g. 

```
file build/kernel8.elf
target remote :1234
```

> The port number (e.g. 1234) must match what you specified for QEMU.

### Usage

*All GDB commands still apply*, e.g. "si" is single step per instruction; "b" is to set a breakpoint; "c" for continuing execution. See below for more. 

The major features here are multiple views: for registers, stack, assembly, and source. 

#### Customize

GDB execute these commands whenever it starts, so you do not have to type them every time. 

In the above example, GDB loads the ELF file kernel8.elf (only for parsing symbols and debugging info); it connects to a remote target at local port 1234. 

Lines below customize gdb-dashboard behaviors, e.g. 

```
dashboard source -style height 15
dashboard assembly -style height 8
```

These lines set the height of the "source" panel and the "assembly" panel. 

The best documentation of gdb-dashboard seems from typing `help dashboard` in the GDB console. e.g. In GDB, type: 

```
>>> help dashboard expressions 
```

Cannot connect? See "troubleshooting" below.

## Other enhancement (FYI)


GEF (https://github.com/hugsy/gef) is also viable. Both GEF and GDB-dashboard: 

* Both enhanced GDB significantly. 

* GEF understands aarch64 semantics (e.g. CPU flags) very well. It can even tell why a branch was taken/not taken. However, GEF does not parse aarch64 callstack properly (at least I cannot get it work). 

* GDB-dashboard nicely parses the callstack. It, however, does not display aarch64 registers properly. 

GEF screenshot (note the CPU flags it recognized)

![image-20210127220750060](exp3/images/gef.png)


## Troubleshooting

**Cannot connect and need help?** Report the following:

* Your QEMU version. i.e. the output of "qemu-system-aarch64  --version"
* Have you tried other kernel binaries, e.g. from p1exp1? And the binaries provided by us? https://github.com/fxlin/p1-kernel/releases
* The full commands you use to launch QEMU. Have you tried different port numbers? 
* Launch GDB w/o loading .gdbinit: 

```
gdb-multiarch -n
```

Then enter GDB commands manually, e.g. load, target remote, etc. Does the problem persist? What's the output? 

* Attach screenshot(s) of the above steps, if possible. 

**WSL caveat:**

"gdbserver: Target description specified unknown architecture “aarch64” 
https://stackoverflow.com/questions/53524546/gdbserver-target-description-specified-unknown-architecture-aarch64 
It seems GDB server does not play well with WSL… be aware! 

## Reference 

Launch qemu with gdb 

https://en.wikibooks.org/wiki/QEMU/Debugging_with_QEMU#Launching_QEMU_from_GDB 

more info about gdb for kernel debugging 

https://wiki.osdev.org/Kernel_Debugging 

Good article

https://interrupt.memfault.com/blog/advanced-gdb#source-files

