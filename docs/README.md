# UVA-OS Lab1 "Baremetal" 

### Students: see [quests-lab1.md](quests-lab1.md)

## GALLERY
<img src="donut-text.gif" alt="description" height="200">
<img src="donut-pixel.gif" alt="description" height="200">

## DESIGNS

A single CPU core can boot, print messages from UART, and display pixels. Interrupts work, enabling periodic rendering of a simple "donut" animation. Everything runs in privileged mode (EL1).

<img src="image-1.png" alt="description" width="500">

✅ UART/printf 
✅ Timers (&multiplexing)
✅ Interrupts
✅ Framebuffer & animation

⛔ No multitasking 
⛔ EL1 only


## QUICKSTART

### For rpi3 (QEMU)

```
export PLAT=rpi3qemu
```

| Action                      | Command                   |
|-----------------------------|---------------------------|
| To clean up                 | `./cleanall.sh`           |
| To build everything         | `./makeall.sh`            |
| To run on qemu              | `./run-rpi3qemu.sh`       |
| Launch qemu for debugging   | `./dbg-rpi3qemu.sh`       |

### For rpi3 (hardware)
```
export PLAT=rpi3
```

| Action              | Command             |
|---------------------|---------------------|
| To clean up         | `./cleanall.sh`     |
| To build everything | `./makeall.sh`      |

(One time): Prepare the SD card

https://github.com/fxlin/uva-os-main/tree/main/make-sd

<!-- get a blank SD card, burn the provided image with Win32DiskImager, 
balenaEtcher, or Raspberry Pi Imager.  -->

Copy the kernel image `kernel8.img` to the partition named `bootfs` and boot. 