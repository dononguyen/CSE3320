
# Notes on a QEMU rpi framebuffer bug
nov 2024, jan 2025

## Solution - build from source with our fixes

to install prerequisite 
```
sudo apt remove qemu-system-arm
sudo apt install gdb-multiarch build-essential pkg-config
sudo apt install libglib2.0-dev libfdt-dev libpixman-1-dev zlib1g-dev libgtk-3-dev
pip install tomli
```
libgtk-3-dev is needed; otherwise qemu build will fall back to SDL which seems to result in a UI with blank screen.


clone the code with our fixes
```
cd $HOME
git clone --branch uva-os-2025-01-10 --depth 1 git@github.com:fxlin/qemu-9.1.1.git
```

to configure and build qemu.
```
cd ~/qemu-9.1.1/
mkdir build
cd build
# ../configure --target-list=aarch64-softmmu --enable-debug-info
../configure --target-list=aarch64-softmmu 
make -j$(nproc)
```

Simply run our script `run-rpi3qemu.sh` as usual, 
which already contains the logic for locating the new qemu binary. cf:

```bash
# (run-rpi3qemu.sh)
# sp25, containing our own fix
QEMU9=${HOME}"/qemu-9.1.1/build/qemu-system-aarch64"
if [ -x "${QEMU9}" ]; then
    QEMU=${QEMU9}
else
    QEMU=${QEMU6}   # default 
fi
```

To test if the fixes work, run:
```
scripts/stress-qemu.sh
```
QEMU should survive the test without segfaults.


## Symptom
QEMU occasionally segfaults when the guest kernel changes the framebuffer resolution via mailbox (mbox).

## Analysis
QEMU (up to version 9) has a race condition between two functions in `hw/display/bcm2835_fb.c`:

- `fb_update_display()`
- `bcm2835_fb_reconfigure()`

When the guest kernel changes the framebuffer resolution, the display updater (`framebuffer_update_display()`, called via timers — see call stack below) may still operate on stale framebuffer data and resolution settings. This happens even after `bcm2835_fb_reconfigure()` resizes the framebuffer using `qemu_console_resize()` and potentially invalidates the previous framebuffer and resolution. Consequently, `framebuffer_update_display()` may access an invalid buffer, leading to a segfault.

The existing code uses a simple flag (`BCM2835FBState::lock`), which is a regular variable—not even atomic and without memory barriers. This approach is ineffective. It's unclear what assumptions were made when the code was initially written—possibly, the assumption that `bcm2835_fb_reconfigure()` and `framebuffer_update_display()` would be called from the same thread. However, that assumption is incorrect, resulting in the observed race condition.

## Solution
Simply adding a lock (e.g., for `BCM2835FBConfig::xres` and `yres`) results in occasional deadlocks. This happens because `fb_update_display()` calls `framebuffer_update_display()`, which tries to acquire a "QEMU CPU" lock, while that lock is already held by the thread executing `bcm2835_fb_reconfigure()`. Specifically:

- **Thread A (`fb_update_display()`)**: Holds `new_lock`, then tries to acquire the CPU lock.
- **Thread B (`bcm2835_fb_reconfigure()`)**: Holds the CPU lock, then tries to acquire `new_lock`.

The solution that works is to move `qemu_console_resize()` out of `bcm2835_fb_reconfigure()`. It seems that `qemu_console_resize()` manipulates the framebuffer directly. Instead, `bcm2835_fb_reconfigure()` now only updates the configuration values and uses a flag to indicate that the resolution has changed. Upon seeing this flag, `fb_update_display()` calls `qemu_console_resize()`. Importantly, the current update cycle should be skipped, as accessing potentially stale information during the resize still causes a segfault. Skipping to the next update cycle allows the system to stabilize.

There are still some caveats (noted in the code), but this solution seems to work reliably as of now.


## code 

(based on qemu-9.1.1)

docs/fb-bug/bcm2835_fb.{c|h}


to configure and build qemu:
```
sudo apt remove qemu-system-arm
sudo apt install gdb-multiarch build-essential pkg-config
sudo apt install libglib2.0-dev libfdt-dev libpixman-1-dev zlib1g-dev libgtk-3-dev
pip install tomli
```
libgtk-3-dev is needed; otherwise qemu build will fall back to SDL which seems to result in a UI with blank screen.

```
mkdir build
cd build
# ../configure --target-list=aarch64-softmmu --enable-debug-info
../configure --target-list=aarch64-softmmu 
make -j6
```

test scripts

```
# for debug qemu
scripts/debug-qemu-itself.sh     

# for stress test
scripts/stress-qemu.sh
```

## segfault call stack 

```
#0  0x00005555559ce33f in rgb_to_pixel32 (b=<optimized out>, g=<optimized out>, r=<optimized out>)
    at /home/student/qemu-9.1.1/include/ui/pixel_ops.h:46
#1  draw_line_src16
    (opaque=opaque@entry=0x7ffff3013970, dst=dst@entry=0x7ffff10d3010 <error: Cannot access memory at address 0x7ffff10d3010>, src=0x7fff92300004 "", src@entry=0x7fff92300000 "", width=639, width@entry=640, deststep=deststep@entry=0) at ../hw/display/bcm2835_fb.c:131
#2  0x00005555559c93d2 in framebuffer_update_display
    (ds=<optimized out>, mem_section=<optimized out>, cols=640, rows=480, src_width=1280, dest_row_pitch=2560, dest_col_pitch=0, invalidate=1, fn=0x5555559ce250 <draw_line_src16>, opaque=0x7ffff3013970, first_row=0x7fffffffdd20, last_row=0x7fffffffdd24)
    at ../hw/display/framebuffer.c:107
#3  0x00005555559ce044 in fb_update_display (opaque=0x7ffff3013970) at ../hw/display/bcm2835_fb.c:203
```

## deadlock

obtained via "scripts/debug-qemu-itself.sh"; once deadlock, do `killall -SIGSTOP qemu-system-aarch64`. 

### thread 1 

```
#0  __futex_abstimed_wait_common64
    (private=0, cancel=true, abstime=0x0, op=393, expected=0, futex_word=0x555557421e88 <qemu_work_cond+40>)
    at ./nptl/futex-internal.c:57
#1  __futex_abstimed_wait_common
    (cancel=true, private=0, abstime=0x0, clockid=0, expected=0, futex_word=0x555557421e88 <qemu_work_cond+40>)
    at ./nptl/futex-internal.c:87
#2  __GI___futex_abstimed_wait_cancelable64
    (futex_word=futex_word@entry=0x555557421e88 <qemu_work_cond+40>, expected=expected@entry=0, clockid=clockid@entry=0, abstime=abstime@entry=0x0, private=private@entry=0) at ./nptl/futex-internal.c:139
#3  0x00007ffff5a93a41 in __pthread_cond_wait_common
    (abstime=0x0, clockid=0, mutex=0x5555574259e0 <bql>, cond=0x555557421e60 <qemu_work_cond>)
    at ./nptl/pthread_cond_wait.c:503
#4  ___pthread_cond_wait (cond=cond@entry=0x555557421e60 <qemu_work_cond>, mutex=mutex@entry=0x5555574259e0 <bql>)
    at ./nptl/pthread_cond_wait.c:627
#5  0x00005555561e40ff in qemu_cond_wait_impl
    (cond=0x555557421e60 <qemu_work_cond>, mutex=0x5555574259e0 <bql>, file=0x55555621a7ce "../cpu-common.c", line=164) at ../util/qemu-thread-posix.c:225
#6  0x00005555558fb098 in do_run_on_cpu
    (cpu=<optimized out>, func=<optimized out>, data=..., mutex=0x5555574259e0 <bql>) at ../cpu-common.c:164
#7  0x0000555555faa78e in memory_global_after_dirty_log_sync () at ../system/memory.c:2885
#8  memory_region_snapshot_and_clear_dirty
    (mr=mr@entry=0x555557966990, addr=addr@entry=1007681536, size=size@entry=1228800, client=client@entry=0)
    at ../system/memory.c:2351
#9  0x00005555559c9345 in framebuffer_update_display
    (ds=<optimized out>, mem_section=<optimized out>, cols=640, rows=480, src_width=2560, dest_row_pitch=2560, dest_col_pitch=0, invalidate=1, fn=0x5555559ce310 <draw_line_src16>, opaque=0x7ffff3013970, first_row=0x7fffffffdd40, last_row=0x7fffffffdd44) at ../hw/display/framebuffer.c:102
#10 0x00005555559ce0f5 in fb_update_display (opaque=0x7ffff3013970) at ../hw/display/bcm2835_fb.c:242
#11 0x00005555558fe116 in graphic_hw_update (con=0x55555794cf70) at ../ui/console.c:142
#12 0x00005555558fda8a in dpy_refresh (s=<optimized out>, s=0x555557b70e70) at ../ui/console.c:882
#13 gui_update (opaque=opaque@entry=0x555557b70e70) at ../ui/console.c:89
#14 0x00005555561fcd41 in timerlist_run_timers (timer_list=0x5555575a5940) at ../util/qemu-timer.c:576
#15 0x00005555561fcf89 in timerlist_run_timers (timer_list=<optimized out>) at ../util/qemu-timer.c:509
#16 qemu_clock_run_timers (type=<optimized out>) at ../util/qemu-timer.c:590
#17 qemu_clock_run_all_timers () at ../util/qemu-timer.c:677
#18 0x00005555561f91b3 in main_loop_wait (nonblocking=nonblocking@entry=0) at ../util/main-loop.c:600
#19 0x0000555555c21af7 in qemu_main_loop () at ../system/runstate.c:826
#20 0x000055555613d52b in qemu_default_main () at ../system/main.c:37
#21 0x00007ffff5a29d90 in __libc_start_call_main
     (main=main@entry=0x5555558f8270 <main>, argc=argc@entry=13, argv=argv@entry=0x7fffffffe058)
    at ../sysdeps/nptl/libc_start_call_main.h:58
#22 0x00007ffff5a29e40 in __libc_start_main_impl
     (main=0x5555558f8270 <main>, argc=13, argv=0x7fffffffe058, init=<optimized out>, fini=<optimized out>, rtld_fini=<optimi--Type <RET> for more, q to quit, c to continue without paging--q
Quit
```

### thread 2
```
(gdb) info threads
  Id   Target Id                                           Frame 
* 1    Thread 0x7ffff30b7500 (LWP 23100) "qemu-system-aar" __futex_abstimed_wait_common64 (private=0, cancel=true, 
    abstime=0x0, op=393, expected=0, futex_word=0x555557421e88 <qemu_work_cond+40>) at ./nptl/futex-internal.c:57
  2    Thread 0x7ffff2e00640 (LWP 23103) "qemu-system-aar" syscall ()
    at ../sysdeps/unix/sysv/linux/x86_64/syscall.S:38
  3    Thread 0x7ffff2400640 (LWP 23104) "gmain"           0x00007ffff5b18bcf in __GI___poll (fds=0x555557925870, 
    nfds=1, timeout=-1) at ../sysdeps/unix/sysv/linux/poll.c:29
  5    Thread 0x7ffff1000640 (LWP 23106) "gdbus"           0x00007ffff5b18bcf in __GI___poll (fds=0x7fffe000f300, 
    nfds=2, timeout=-1) at ../sysdeps/unix/sysv/linux/poll.c:29
  6    Thread 0x7fffebe00640 (LWP 23107) "dconf worker"    0x00007ffff5b18bcf in __GI___poll (fds=0x55555793c9a0, 
    nfds=1, timeout=-1) at ../sysdeps/unix/sysv/linux/poll.c:29
  7    Thread 0x7fffeb400640 (LWP 23108) "qemu-system-aar" futex_wait (private=0, expected=2, 
    futex_word=0x7ffff3013eb0) at ../sysdeps/nptl/futex-internal.h:146
  8    Thread 0x7fffeaa00640 (LWP 23109) "qemu-system-aar" futex_wait (private=0, expected=2, 
    futex_word=0x5555574259e0 <bql>) at ../sysdeps/nptl/futex-internal.h:146
  9    Thread 0x7fffea000640 (LWP 23110) "qemu-system-aar" 0x00007fff9c0822f1 in code_gen_buffer ()
  10   Thread 0x7fffe9600640 (LWP 23111) "qemu-system-aar" 0x00007fff9c0822c0 in code_gen_buffer ()
(gdb) thr 7
[Switching to thread 7 (Thread 0x7fffeb400640 (LWP 23108))]
#0  futex_wait (private=0, expected=2, futex_word=0x7ffff3013eb0) at ../sysdeps/nptl/futex-internal.h:146
146	../sysdeps/nptl/futex-internal.h: No such file or directory.
(gdb) bt
#0  futex_wait (private=0, expected=2, futex_word=0x7ffff3013eb0) at ../sysdeps/nptl/futex-internal.h:146
#1  __GI___lll_lock_wait (futex=futex@entry=0x7ffff3013eb0, private=0) at ./nptl/lowlevellock.c:49
#2  0x00007ffff5a98002 in lll_mutex_lock_optimized (mutex=0x7ffff3013eb0) at ./nptl/pthread_mutex_lock.c:48
#3  ___pthread_mutex_lock (mutex=mutex@entry=0x7ffff3013eb0) at ./nptl/pthread_mutex_lock.c:93
#4  0x00005555561e3918 in qemu_mutex_lock_impl
    (mutex=0x7ffff3013eb0, file=0x555556283caf "../hw/display/bcm2835_fb.c", line=56)
    at ../util/qemu-thread-posix.c:94
#5  0x00005555559ce991 in fb_lock (s=0x7ffff3013970) at ../hw/display/bcm2835_fb.c:56
#6  bcm2835_fb_reconfigure (s=0x7ffff3013970, newconfig=0x7fffeb3fb310) at ../hw/display/bcm2835_fb.c:303
#7  0x0000555555a5b8ba in bcm2835_property_mbox_push (value=<optimized out>, s=0x7ffff3014d90)
    at ../hw/misc/bcm2835_property.c:435
#8  bcm2835_property_write (offset=0, size=<optimized out>, value=<optimized out>, opaque=0x7ffff3014d90)
    at ../hw/misc/bcm2835_property.c:478
#9  bcm2835_property_write
    (opaque=0x7ffff3014d90, offset=<optimized out>, value=<optimized out>, size=<optimized out>)
    at ../hw/misc/bcm2835_property.c:468
#10 0x0000555555fa5df4 in memory_region_write_accessor
    (mr=mr@entry=0x7ffff3015170, addr=0, value=value@entry=0x7fffeb3fb498, size=size@entry=4, shift=<optimized out>, mask=mask@entry=4294967295, attrs=...) at ../system/memory.c:497
#11 0x0000555555fa6ac6 in access_with_adjusted_size
    (addr=addr@entry=0, value=value@entry=0x7fffeb3fb498, size=size@entry=4, access_size_min=<optimized out>, access_size_max=<optimized out>, access_fn=0x555555fa5d70 <memory_region_write_accessor>, mr=0x7ffff3015170, attrs=...)
    at ../system/memory.c:573
#12 0x0000555555fa7bf6 in memory_region_dispatch_write (mr=mr@entry=0x7ffff3015170, addr=0, data=<optimized out>, 
    data@entry=3221836920, op=op@entry=MO_32, attrs=attrs@entry=...) at ../system/memory.c:1528
#13 0x0000555555fb58b4 in address_space_stl_internal
    (endian=DEVICE_LITTLE_ENDIAN, result=0x0, attrs=..., val=3221836920, addr=0, as=0xc0095478)
    at ../system/memory_ldst.c.inc:319
#14 address_space_stl_le
    (as=as@entry=0x7ffff30155f8, addr=addr@entry=128, val=3221836920, attrs=attrs@entry=..., result=result@entry=0x0)
    at ../system/memory_ldst.c.inc:357
#15 0x0000555555a5aa2b in stl_le_phys (val=3221836920, addr=128, as=0x7ffff30155f8)
    at /home/student/qemu-9.1.1/include/exec/memory_ldst_phys.h.inc:121
#16 bcm2835_mbox_write (opaque=0x7ffff30152c0, offset=<optimized out>, value=3221836920, size=<optimized out>)
    at ../hw/misc/bcm2835_mbox.c:227
#17 0x0000555555fa5df4 in memory_region_write_accessor
    (mr=mr@entry=0x7ffff30156a0, addr=160, value=value@entry=0x7fffeb3fb748, size=size@entry=4, shift=<optimized out>, mask=mask@entry=4294967295, attrs=...) at ../system/memory.c:497
#18 0x0000555555fa6ac6 in access_with_adjusted_size
    (addr=addr@entry=160, value=value@entry=0x7fffeb3fb748, size=size@entry=4, access_size_min=<optimized out>, access_size_max=<optimized out>, access_fn=0x555555fa5d70 <memory_region_write_accessor>, mr=0x7ffff30156a0, attrs=...)
    at ../system/memory.c:573
#19 0x0000555555fa7bf6 in memory_region_dispatch_write
--Type <RET> for more, q to quit, c to continue without paging--
    (mr=mr@entry=0x7ffff30156a0, addr=addr@entry=160, data=<optimized out>, 
    data@entry=3221836920, op=op@entry=MO_32, attrs=...) at ../system/memory.c:1528
#20 0x0000555555ff811d in int_st_mmio_leN
    (cpu=cpu@entry=0x7ffff2fb22f0, full=full@entry=0x7fff5002b820, val_le=val_le@entry=3221836920, addr=addr@entry=1057011872, size=size@entry=4, mmu_idx=mmu_idx@entry=2, ra=140735714259850, mr=0x7ffff30156a0, mr_offset=160)
    at ../accel/tcg/cputlb.c:2485
#21 0x0000555555ff831d in do_st_mmio_leN
    (cpu=0x7ffff2fb22f0, full=0x7fff5002b820, val_le=3221836920, addr=1057011872, size=4, mmu_idx=2, ra=140735714259850) at ../accel/tcg/cputlb.c:2520
#22 0x0000555555ffc0e2 in do_st_4
    (ra=<optimized out>, memop=<optimized out>, mmu_idx=<optimized out>, val=3221836920, p=<optimized out>, cpu=<optimized out>) at ../accel/tcg/cputlb.c:2690
#23 do_st4_mmu (cpu=0x7ffff2fb22f0, addr=128, val=3221836920, oi=2, ra=140735714259850) at ../accel/tcg/cputlb.c:2766
#24 0x00007fff964173d6 in code_gen_buffer ()
#25 0x0000555555fecab6 in cpu_tb_exec
    (cpu=cpu@entry=0x7ffff2fb22f0, itb=itb@entry=0x7fff96417280 <code_gen_buffer+94803>, tb_exit=tb_exit@entry=0x7fffeb3fbe84) at ../accel/tcg/cpu-exec.c:458
#26 0x0000555555fed00a in cpu_loop_exec_tb
    (tb_exit=0x7fffeb3fbe84, last_tb=<synthetic pointer>, pc=<optimized out>, tb=0x7fff96417280 <code_gen_buffer+94803>, cpu=0x7ffff2fb22f0) at ../accel/tcg/cpu-exec.c:908
#27 cpu_exec_loop (cpu=cpu@entry=0x7ffff2fb22f0, sc=sc@entry=0x7fffeb3fbf30) at ../accel/tcg/cpu-exec.c:1022
#28 0x0000555555fed7c1 in cpu_exec_setjmp (cpu=cpu@entry=0x7ffff2fb22f0, sc=sc@entry=0x7fffeb3fbf30)
    at ../accel/tcg/cpu-exec.c:1039
#29 0x0000555555fedf4e in cpu_exec (cpu=cpu@entry=0x7ffff2fb22f0) at ../accel/tcg/cpu-exec.c:1065
#30 0x0000555556008df4 in tcg_cpu_exec (cpu=cpu@entry=0x7ffff2fb22f0) at ../accel/tcg/tcg-accel-ops.c:78
#31 0x0000555556008f4f in mttcg_cpu_thread_fn (arg=arg@entry=0x7ffff2fb22f0) at ../accel/tcg/tcg-accel-ops-mttcg.c:95
#32 0x00005555561e3531 in qemu_thread_start (args=<optimized out>) at ../util/qemu-thread-posix.c:541
#33 0x00007ffff5a94ac3 in start_thread (arg=<optimized out>) at ./nptl/pthread_create.c:442
#34 0x00007ffff5b26850 in clone3 () at ../sysdeps/unix/sysv/linux/x86_64/clone3.S:81
```
