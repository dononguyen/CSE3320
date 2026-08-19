# Quest Description for Lab1:"Baremetal"

Total SLoC changed: <100; estimated time: 10 hours

<!-- convert image-1.png -resize 500x image-1-resized.png -->

![alt text](image-1-resized.png)

| Quest Name | Description | Credits |
|------------|-------------|---------|
| [Quest01: setup](#quest01-setup) | Install necessary tools and set up the environment | 0 |
| [Quest02: kernel image](#quest02-kernel-image) | Build and inspect the kernel image | 5 |
| [Quest03: boot](#quest03-boot) | Understand boot.S, which boots the kernel | 15 |
| [Quest04: UART](#quest04-uart) | Understand UART bring-up for kernel debugging | 15 |
| [Quest05: textual donut](#quest05-textual-donut) | Understand the system timer for timed animation | 10 |
| [Quest06: OS logo](#quest06-os-logo) | Understand how the OS logo and name are displayed on the screen | 10 |
| [Quest07: debug level](#quest07-debug-level) | Control debug messages using macros | 0 |
| [Quest08: framebuffer offsets](#quest08-framebuffer-offsets) | Explore framebuffer virtual offsets | 5 |
| [Quest09: sys_timer irq](#quest09-sys_timer-irq) | Enable system timer interrupt | 0 |
| [Quest10: pixel donut](#quest10-pixel-donut) | Implement pixel donut animation | 15 |
| [Quest11: virtual timers](#quest11-virtual-timers) | Implement virtual timers for animations | 15 |
| [Quest12: UART rx irq](#quest12-uart-rx-irq) | Enable UART receive interrupts | 10 |

## Preface

### About this document

A document like this (quest description): 
- provides a high-level overview of the quests;
- tells you the goals and major steps; 
- points you to the corresponding source code. 

This document does NOT: 
- provide detailed instructions.

The detailed instructions are always as comments in the source
code. Search for "quest:" in the source code, or highlight them using vscode's
TODO Tree plugin.

### What's the lab structure?
Each lab comprises a sequence of "quests." 

Within a lab, quests may have dependencies, so you are advised to complete quests in order. 

A quest comprises multiple steps; these steps are largely sequential.

### What are CHECKPOINTS? 

You will see "CHECKPOINTS" in the quest description from time to time. 
They mean that you should have accomplished a major feature, e.g. a syscall. 
You should test the feature. 
The feature may not be easily demonstratable. 

There is nothing to submit for CHECKPOINTS.

### What are DELIVERABLES? 

You will see "DELIVERABLES" in the quest description from time to time.
They mean that you need to demonstrate a feature, e.g., showing an animation on screen. 

In this course, DELIVERABLES are mostly 📷 videos or photos, or sometimes 📝 writeups, for which we have specific requirements.

Not all quests have DELIVERABLES. For instance, a quest without DELIVERABLE can be prerequisite for the later ones. 

### What are DEMOs? 

A DEMO is a **peer explanation checkpoint**, done *before* you start writing
code for a quest group. You need to walk other students through the specific
code listed for that DEMO in class: what it
does, why it's structured that way, and how the pieces fit together. This is
not about having working code; it's about proving to yourself (via a
listener) that you understand the existing code well enough to start
implementing.

### How does a lab submission look? 

A submission has two parts, which go to two different places: 

- **DELIVERABLES** (videos, photos, writeups) are submitted on **Canvas**.

- **Implementation** (your code) is pushed to the `main` branch of **your own** GitHub repo (your fork/clone of this lab -- not the shared class repo).

For each quest that has coding STEPS (i.e. asks you to write code, not just read/understand it), use a standard branch workflow: 

1. create a branch off `main`, named after the quest, e.g. `quest04-uart`
2. implement the quest on that branch, committing as you go (reference the quest in your commit messages, e.g. "quest04: implement uart_send")
3. push the branch to your GitHub repo
4. open a pull request from the branch into `main` and merge it (use a merge commit rather than squashing, so the history still shows each quest's commits)
5. do **not** delete the branch after merging -- keep it so the TA can trace which commits implement which quest

Quests with no coding STEPS (e.g. read-and-understand quests, or setup/inspection quests) don't need a branch -- just commit directly to `main` if there's anything to commit at all.

In your Canvas submission for each quest, include a link to the corresponding commit, PR, or branch on GitHub next to the required video/photo/writeup, so the TA can match your deliverable to your code. Type these links into the Canvas **Text Entry** box for the submission -- don't just paste them into a video/photo file or a separate doc, since the TA needs them directly on the submission page.

## Quest01: setup 

### How to choose?  
- All: try VMWare first; 
- If VMWare does not work for you (e.g. your machine is slow):
  - Windows users: try WSL2
  - Linux users: try native. 

In writing below, we will refer to users using VMware Player/Fusion as "VM users". 

| Your local machine: | Can run ...    |
| ------------------------ | ---------------------- |
| Windows                  | VMware Player or WSL2 (WSL won't work) |
| Mac                      | VMware Fusion |
| Linux                    | Ubuntu 22.04 native or VMware Player               |


### Instructions for VM users

* [instructions](vmware.md): How to install VMware Workstation Player on Windows or Mac. 

#### install toolchain 

````bash
sudo apt update

# Install gcc and g++ compilers for ARM/AARCH
# If your processor architecture is not ARM, run 
sudo apt install -y gcc-9-aarch64-linux-gnu g++-9-aarch64-linux-gnu
# Otherwise, run this command 
sudo apt install -y gcc-9 g++-9

sudo apt install -y gdb-multiarch
# other useful goodies
sudo apt install -y tmux build-essential git
````

NB: Must be gcc-9. Newer gcc is known to break some kernel code. 

Set up gcc-9 as the default compiler: 
````
sudo update-alternatives --install /usr/bin/aarch64-linux-gnu-gcc aarch64-linux-gnu-gcc /usr/bin/aarch64-linux-gnu-gcc-9 100
sudo update-alternatives --config aarch64-linux-gnu-gcc
````


Verify:
````
aarch64-linux-gnu-gcc-9 --version

aarch64-linux-gnu-gcc-9 (Ubuntu 9.5.0-1ubuntu1~22.04) 9.5.0
Copyright (C) 2019 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
````

#### install gdb
VM users: skip the "apt" command. 
````
sudo apt install -y gdb-multiarch
````

Install the "dashboard" enhancement
````
wget -P ~ https://raw.githubusercontent.com/fxlin/uva-os-main/main/.gdbinit
````

#### install qemu 
VM users: skip the "apt" command
````
sudo apt install -y qemu-system-aarch64
````

Verify: 
````
qemu-system-aarch64 --version

QEMU emulator version 6.2.0 (Debian 1:6.2+dfsg-2ubuntu6.18)
Copyright (c) 2003-2021 Fabrice Bellard and the QEMU Project developers
````

**Bug fix.**
In addition, you may want to build qemu from source with our fixes. 
cf quest "pixel donut" below. 

#### test toolchain & qemu

The command below tests your QEMU installation with Rpi3 emulation (NOTE: this repo is for validating your
toolchain & QEMU build; it is NOT our course project)

````
git clone https://github.com/fxlin/raspi3-tutorial.git
cd raspi3-tutorial
git checkout master
cd 05_uart0
make 
qemu-system-aarch64 -M raspi3b -kernel kernel8.img -serial stdio
````

Expected output: 
````
My serial number is: 0000000000000000
````

![alt text](image.png)

>  Note: the test program runs an infinite loop which will cause high CPU usage
>  on your host machine. Use ctrl-c to kill QEMU. 

#### vscode

install vscode on your local machine. 

| User type | Install vscode ...   |
| ------------------------ | ---------------------- |
| WSL2                  | on Windows; use vscode to connect to the WSL target       |
| Linux native           | natively  |
| VM                    |  inside the VM |

recommended vs plugins: 

- Arm Assembly
- Bookmarks (for navigating in large codebases)
- C/C++ Themes
- Project Manager (for managing multiple codebases) 
- Remote Development (Windows WSL target)
- Remote Explorer
- WSL (Windows only)
- C/C++
- GitHub Copilot
- Todo Tree (highlight todo keywords) 

useful hotkeys: 

- ctrl+p go to files
- ctrl+t go to a symbol
- ctrl+shift+f search text in all files 
- ctrl+\ open the current file in a split view
- ctrl+j toggle bottom panel
- ctrl+b toggle left panel
- ctrl+alt+click open the function in the other split view

😀 DELIVERABLE: This quest has no deliverables.

### rpi3 hardware setup (optional for lab1)

Read this [rpi-setup.md](rpi-setup.md)

## Quest02: kernel image

OVERVIEW: you will build the kernel image (kernel8.img) and inspect it.

Create a *private* github repo for lab1. Push the entire project to the repo. 

On your VM, assume the path of lab 1 to be under your home path, e.g. 
`~/uva-os-world1/`. 

````
export PLAT=rpi3qemu
./makeall.sh
````

Verify: the output kernel (elf): 
````
file kernel/build-rpi3qemu/kernel8.elf
````

Inspect the kernel elf file. Refer to our short [writeup](dump.md) or ask
ChatGPT questions, e.g.,

- "Help me understand boot.S or show me the full flow in one picture"

Make sure you understand the difference between .elf and .img files

😀 DELIVERABLE. In 1-2 sentences, answer the questions below: 

- What is the elf file?

- What are these sections in the elf file?

- What are EL1, EL2, and EL3?

- What is the address of symbol kernel_main? What are the first 8 bytes at the
    symbol? What are the corresponding instructions? 

- How many bytes does each aarch64 instruction contain? 

- How is kernel8.img generated out of kernel8.elf?

- Now examine kernel8.img (use the hexdump command or the VSCode plugin). Search
    for the first 8 bytes of kernel_main(). Can you find it? At which offset of
    kernel8.img? 

## Quest03: boot 

OVERVIEW: boot.S is already complete and boots the kernel to kernel_main() in
kernel.c. This quest is about reading and understanding how it does so, and
shows how to use GDB (important). 

### Launch GDB

In a window: 
````
./dbg-rpi3qemu.sh
````

In a different terminal window: 

````
gdb-multiarch
````

which shall read ~/.gdbinit and loads `kernel/build-rpi3qemu/kernel8.elf`
because that is what is inside .gdbinit. To override that path, do 
````
gdb-multiarch mypath/kernel8.elf
````

<!-- ![alt text](gdb-launch.gif){width=200px} -->

<img src="gdb-launch.gif" alt="description" width="300">

More info on GDB (common commands, etc): 
we will cover in lectures;
refer to our short [writeup](gdb.md); 
ask ChatGPT. 

### Debug the kernel: single step

With GDB, start from the kernel `_start`, single step (per instruction). Compare
the instructions displayed on GDB to the assembly code in `boot.S`.  

Do the single step until you execute the instruction `eret`. Have you observed change in the EL displayed by GDB? 

😀 DELIVERABLE: Take a photo of the GDB screen.

### Read and understand boot.S

**NOTE**. In the description below (and in the future), we will refer to C function names and assembly
labels. We do not always give out the full file paths. 
To quickly locate them, use vscode `ctrl+t` for C functions and `ctrl+shift+f` for assembly labels.

**NOTE**. For quests that still require you to write code, always see the
comments in the code for hints and instructions.

**NOTE**. If you configured vscode and Todo-tree as described above, you can see all the remaining coding quests lighlighted and listed in the Todo-tree panel.

![alt text](image-3.png)

STEPS

- read and understand the code at `el1_entry`, which zeroes out the BSS region

- read and understand the code at `setup_sp`, which sets up the stack pointer
above the kernel image

- set a breakpoint at the first printf() call in kernel_main(). run the kernel
until the breakpoint is hit. 

😀 DELIVERABLE: take a photo of the GDB screen.

## Quest04: UART 

This quest is about bringing up the UART (which does poll only at this time). 
UART is our primary I/O device for kernel debugging. The UART bring-up code is
already complete; this quest is about reading and understanding it.

Grasp the high-level idea of `mini_uart` (mini_uart.c) and `printf()` (printf.c).

In `mini_uart.c`, read and understand `uart_send()`. 

In `kernel_main()`, note that `uart_init()` and `init_printf()` are called
before the first call to `printf()` -- understand why this ordering matters. 

😀 DELIVERABLE: take a photo of kernel printing the following messages: 
````
------ kernel boot ----- core 0
build time (kernel.c) ...
````

## Quest05: textual donut

OVERVIEW: sys_timer is already brought up, providing delays for timed animation. But no interrupts enabled yet. This quest is about reading and understanding the timekeeping code.

- in `timer.c`, read and understand the core function of kernel timekeeping: `current_counter()`, which
returns the current value of the system timer. 
This function allows us to determine the values of `cycles_per_ms` etc (which however may already be set for you);
it is also vital to later quests;

- read and understand the delay functions (through busy waiting): `ms_delay()` and
`us_delay()`.

- read `donut_text()` and roughly understand what it does. 

- in `kernel_main()`, uncomment the call to `donut_text()` to see the timed
    animation on uart output. 

![donut-text](donut-text.gif)

### Change luminance of Donut (optional)

- in `donut_text()`, change the luminance of the donut by modifying how it fills
    buffer b with different characters. 

😀 DELIVERABLE: 
shoot a short video of the donut animation. 
Reference: 


## Quest06: OS logo

OVERVIEW: the framebuffer, needed for graphical display, is already brought
up. This quest is about reading and understanding how it works.

- Read `mbox.c`, grasp how framebuffer works in general. 

- in `mbox.c`, read and understand the framebuffer initialization function `do_fb_init()`.

- read and understand the function that displays the OS logo and name: `fb_showpicture()`.

### change the OS logo and name (optional)

😀 DELIVERABLE: take a photo of the OS logo and name displayed on the
screen.

## Quest07: debug level

- in mbox.c, switch the KERNEL DEBUG_XXX macro to show different sets of debug
    messages.

- in Makefile, toggle CONFIG_GLOBAL_DEBUG_LEVEL to control different sets of
    debug messages.

- Read the comments in Makefile and debug.h, understand how these two work together to control the
    debug messages.

There is no DELIVERABLE for this quest. 


## Quest08: framebuffer offsets

Explore the framebuffer virtual offsets.

- read the code `test_fb_voffset()` in (unittest.c)  and understand its intended drawing behaviors.

The expected behavior as running on the actual rpi3 hardware:

https://github.com/user-attachments/assets/45a9220d-042f-458a-9658-d2d086915057

- try out the code on qemu: place a call to `test_fb_voffset()` in `kernel_main()`.

- understand what the virtual offsets are

😀 DELIVERABLE: shoot a short video. 

## Quest09: sys_timer irq

OVERVIEW: bring up the sys_timer irq, needed for timed animation.

- understand the table of exception vectors (`vectors:` in `entry.S`).

- in the vector table, place `el1_irq` at the right place.

- in entry.S, complete the assembly macro `kernel_entry`, with the help of GDB and AI.

- in kernel_main(), enable the CPU irq. Look for an existing function in `util.S`.

CHECKPOINT. with the help of GDB or debug print, verify that the timer irq is fired:
    i.e. `handle_irq()` (irq.c) is called. Understand why is `handle_irq()` called just one-shoot or periodically. 

There is no DELIVERABLE for this quest. Continue below to enable animation. 

## Quest10: pixel donut

OVERVIEW: bring up the pixel donut animation.

- Understand the key functions of the Donut: 
`donut_simple()`, `sys_timer_irq_simple()` and `draw_frame()` (donut.c).

- complete the function `sys_timer_irq_simple()` (donut.c).

- in the system's irq handler (irq.c), place the call to `sys_timer_irq_simple()` (donut.c).

- Place a call to `donut_simple()` in `kernel_main()`.

### change the donut's color tone to your like (optional)

- by modifying `draw_frame()` (donut.c), change the color tone of the donut.


😀 DELIVERABLE: shoot a short video (5-10sec) of the donut animation.

Reference below.

![donut-pixel](donut-pixel.gif)

NOTE: you may see qemu crash occasionally with a segmentation fault (segfault) like this. 
After that, the terminal becomes unusable, not echoing any key inputs. 

![qemu-crash](qemu-crash.jpg)

It's a QEMU bug. Interested readers can see my analysis in this [doc](fb-bug/notes-qemu-fb-bug.md); 
VM users should be fine: I already applied my fix to the QEMU9 shipped with the VM image. 
For WSL2 users, you just kill the faulty QEMU and start a new one
(the segfault won't happen every time, and it seems less frequent than on VM/Linux); 
if it really bothers you, just compile QEMU from source with my [fixes](fb-bug).


## Quest11: virtual timers

- complete `sys_timer_irq()` and `adjust_sys_timer()` (timer.c).

- CHECKPOINT. test the virtual timers with `test_ktimer()` (unittest.c); place a call to
    `test_ktimer()` in `kernel_main()`.

- in `handle_irq()`, replace the call to `sys_timer_irq_simple()` with
    `sys_timer_irq()`, which is a generic timer irq handler.

- understand `donut()` (donut.c) and how it uses the virtual timers. Place a call to `donut()` in `kernel_main()`.

- see the donut animation with the virtual timers.

😀 DELIVERABLE: shoot a short video (5-10sec) of the donut animation. visually, the donut would not appear different than the previous quest. your video can include debug messages or GDB screen showing that `donut()` was invoked to render the donut.   

## Quest12: UART rx irq (receive interrupts)

- understand what `test_ktimer2()` (unittest.c) does.

- complete the function `uart_init()` (mini_uart.c) to enable the UART receive
    interrupt.

- complete the function `uart_irq()` (mini_uart.c) to handle the UART receive
    interrupt. Place a call to `test_ktimer2()` in `uart_irq()`.

- Try: use terminal keystroke to start/kill periodic kernel messages as driven by virtual timers.

😀 DELIVERABLE: shoot a short video (5-10sec)

## Demos

This lab has four required DEMOs (see [What are DEMOs?](#what-are-demos)
above). Each one is done *before* you start the coding steps of the
corresponding quest group -- it checks that you understand the existing
code well enough to start implementing, not that you've implemented
anything yet.

### DEMO 1 -- before Quest02-04 (kernel image, boot, UART)

Explain to a peer:
- **ELF vs IMG**: what `kernel8.elf` contains (sections, symbols) vs. how `kernel8.img` is derived from it; what EL1/EL2/EL3 are.
- **`boot.S`**: the flow from `_start` through the EL2/EL3->EL1 `eret` switch, `el1_entry` (BSS zeroing), and `setup_sp` (stack pointer setup).
- **UART bring-up**: `mini_uart.c`'s `uart_send()`, the high-level role of `printf.c`, and why `uart_init()`/`init_printf()` must run before the first `printf()` call in `kernel_main()`.

### DEMO 2 -- before Quest05-06 (textual donut, OS logo)

Explain to a peer:
- **`timer.c`**: what `current_counter()` returns and why it's the basis for timekeeping; how `ms_delay()`/`us_delay()` busy-wait using it.
- **`donut_text()`**: roughly how it renders the ASCII donut over UART using the delay functions.
- **`mbox.c`**: the general framebuffer concept (mailbox protocol to VideoCore), `do_fb_init()`, and `fb_showpicture()`.

### DEMO 3 -- before Quest08-10 (framebuffer offsets, sys_timer irq, pixel donut)

Explain to a peer:
- **`test_fb_voffset()`** (`unittests.c`) and what a framebuffer virtual offset is / why it matters.
- **`entry.S`**: the `vectors:` exception vector table layout, where `el1_irq` belongs in it, and the role of the `kernel_entry`/`kernel_exit` macros (save/restore registers around an IRQ).
- **`irq.c`**: how `handle_irq()` dispatches on an interrupt.
- **`donut.c`**: `donut_simple()`, `sys_timer_irq_simple()`, and `draw_frame()` -- how a timer IRQ drives one animation frame.

### DEMO 4 -- before Quest11-12 (virtual timers, UART rx irq)

Explain to a peer:
- **`timer.c`**: the intended behavior of `sys_timer_irq()` and `adjust_sys_timer()`, and how they differ from the single-purpose `sys_timer_irq_simple()` from DEMO 3 (i.e., what "virtual timer multiplexing" means).
- **`unittests.c`**: what `test_ktimer()` and `test_ktimer2()` each verify.
- **`donut.c`**: how `donut()` schedules itself using virtual timers, contrasted with `donut_simple()`.
- **`mini_uart.c`**: the intended behavior of `uart_init()` (enabling the RX interrupt) and `uart_irq()` (handling a received byte).
