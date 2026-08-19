
build-rpi3qemu/kernel8.elf:     file format elf64-littleaarch64


Disassembly of section .text.boot:

0000000000080000 <_start>:
.section ".text.boot"

.globl _start
_start:		
	// MMU off, until we set pgtables. cf: sysregs.h
	ldr	x0, =SCTLR_VALUE_MMU_DISABLED  
   80000:	58000400 	ldr	x0, 80080 <setup_sp+0x14>
	msr	sctlr_el1, x0
   80004:	d5181000 	msr	sctlr_el1, x0
	
	/* -------- Exception level switch -------------- */
	// Check the current exception level: EL2 or EL3?
	mrs x0, CurrentEL
   80008:	d5384240 	mrs	x0, currentel
  	lsr x0, x0, #2
   8000c:	d342fc00 	lsr	x0, x0, #2
	cmp x0, #3
   80010:	f1000c1f 	cmp	x0, #0x3
	beq el3
   80014:	54000120 	b.eq	80038 <el3>  // b.none

	// Current EL is EL2 
	// set EL1 to be running in AArch64
	mrs	x0, hcr_el2
   80018:	d53c1100 	mrs	x0, hcr_el2
	orr	x0, x0, #HCR_RW  
   8001c:	b2610000 	orr	x0, x0, #0x80000000
	msr	hcr_el2, x0
   80020:	d51c1100 	msr	hcr_el2, x0

	// prepare to switch to EL1
	mov x0, #SPSR_VALUE
   80024:	d28038a0 	mov	x0, #0x1c5                 	// #453
	msr	spsr_el2, x0
   80028:	d51c4000 	msr	spsr_el2, x0

	adr	x0, el1_entry
   8002c:	10000180 	adr	x0, 8005c <el1_entry>
	msr	elr_el2, x0
   80030:	d51c4020 	msr	elr_el2, x0
	eret	// switch to EL1
   80034:	d69f03e0 	eret

0000000000080038 <el3>:

el3: 		// Current EL: EL3
	// 	With the rpi3 firmware (armstub) or qemu, kernel always starts in EL2; 
	//  We leave EL3 code here for completeness
  	ldr x0, =HCR_VALUE
   80038:	58000280 	ldr	x0, 80088 <setup_sp+0x1c>
  	msr hcr_el2, x0
   8003c:	d51c1100 	msr	hcr_el2, x0

	ldr	x0, =SCR_VALUE
   80040:	58000280 	ldr	x0, 80090 <setup_sp+0x24>
	msr	scr_el3, x0
   80044:	d51e1100 	msr	scr_el3, x0

	// prepare to switch to EL1
	ldr	x0, =SPSR_VALUE
   80048:	58000280 	ldr	x0, 80098 <setup_sp+0x2c>
	msr	spsr_el3, x0
   8004c:	d51e4000 	msr	spsr_el3, x0

	adr	x0, el1_entry		
   80050:	10000060 	adr	x0, 8005c <el1_entry>
	msr	elr_el3, x0	
   80054:	d51e4020 	msr	elr_el3, x0
	eret	// switch to EL1				
   80058:	d69f03e0 	eret

000000000008005c <el1_entry>:
el1_entry:	
	/* Below: clean up bss region. 
	  bss_begin/end must be 8 bytes aligned, per the linker script */
	// quest: boot
	// !STUDENT_DONOT_BEGIN
	ldr	x0, =bss_begin		
   8005c:	58000220 	ldr	x0, 800a0 <setup_sp+0x34>
	ldr	x1, =bss_end
   80060:	58000241 	ldr	x1, 800a8 <setup_sp+0x3c>
	sub	x1, x1, x0
   80064:	cb000021 	sub	x1, x1, x0
	// !STUDENT_DONOT_END
	bl 	memzero_aligned
   80068:	9400137c 	bl	84e58 <memzero_aligned>

000000000008006c <setup_sp>:
	
setup_sp: 	
	// quest: boot. set sp to somewhere above PHYS_BASE, far away from kernel image
	mov sp, #(PHYS_BASE + 2 * SECTION_SIZE)  	// !STUDENT_DONOT_SEE
   8006c:	b26a03ff 	mov	sp, #0x400000              	// #4194304
	// NB: we aren't use sp yet -- until we start to execute kernel_main(below)

	// install irq vectors
	ldr x0, =vectors	// load VBAR_EL1 vector table addr
   80070:	58000200 	ldr	x0, 800b0 <setup_sp+0x44>
	msr	vbar_el1, x0	
   80074:	d518c000 	msr	vbar_el1, x0

	// load the addr of kernel_main
	bl kernel_main  	// kernel.c
   80078:	94000256 	bl	809d0 <kernel_main>
   8007c:	00000000 	udf	#0
   80080:	30d00800 	.word	0x30d00800
   80084:	00000000 	.word	0x00000000
   80088:	80000000 	.word	0x80000000
   8008c:	00000000 	.word	0x00000000
   80090:	00000431 	.word	0x00000431
   80094:	00000000 	.word	0x00000000
   80098:	000001c5 	.word	0x000001c5
   8009c:	00000000 	.word	0x00000000
   800a0:	00094320 	.word	0x00094320
   800a4:	00000000 	.word	0x00000000
   800a8:	000954e0 	.word	0x000954e0
   800ac:	00000000 	.word	0x00000000
   800b0:	00084000 	.word	0x00084000
   800b4:	00000000 	.word	0x00000000

Disassembly of section .text:

0000000000080800 <enable_interrupt_controller>:
#if defined(PLAT_RPI3) || defined(PLAT_RPI3QEMU)
    // On RPi3, Arm Generic timer IRQs are wired to a per-core interrupt controller/register. 
    // For core 0, this is `TIMER_INT_CTRL_0` at 0x40000040; bit 1 is for physical timer at EL1 (CNTP). This register is documented 
    // in the [manual](https://www.raspberrypi.org/documentation/hardware/raspberrypi/bcm2836/QA7_rev3.4.pdf) of BCM2836 
    // (search for "Core timers interrupts"). Note the manual is NOT for the BCM2837 SoC used by Rpi3    
    put32(TIMER_INT_CTRL_0 + 4*coreid, TIMER_INT_CTRL_0_VALUE);
   80800:	531e7402 	lsl	w2, w0, #2
   80804:	d2800801 	mov	x1, #0x40                  	// #64
   80808:	f2a80001 	movk	x1, #0x4000, lsl #16
   8080c:	52800043 	mov	w3, #0x2                   	// #2
   80810:	b822c823 	str	w3, [x1, w2, sxtw]

    if (coreid==0)
   80814:	350000c0 	cbnz	w0, 8082c <enable_interrupt_controller+0x2c>
        put32(ENABLE_IRQS_1, 
   80818:	d2964200 	mov	x0, #0xb210                	// #45584
   8081c:	52804041 	mov	w1, #0x202                 	// #514
   80820:	f2a7e000 	movk	x0, #0x3f00, lsl #16
   80824:	72a60001 	movk	w1, #0x3000, lsl #16
   80828:	b9000001 	str	w1, [x0]
    //     arm_gic_umask(0, i);
    // gic_dump(); // debugging 
#else   
    #error "unimplemented"    
#endif
}
   8082c:	d65f03c0 	ret

0000000000080830 <handle_irq>:

// quest: pixel donut. call sys_timer_irq_simple() in the right place
// called from hw irq handler (el1_irq, entry.S)
// call from entry.S, el{0|1}_irq
#if defined(PLAT_RPI3) || defined(PLAT_RPI3QEMU)
void handle_irq(void) {
   80830:	a9bd7bfd 	stp	x29, x30, [sp, #-48]!
   80834:	910003fd 	mov	x29, sp
   80838:	a90153f3 	stp	x19, x20, [sp, #16]
    // register that holds interrupt status for interrupts `0 - 31`. 
    // Using this register we can check whether the current interrupt was 
    // generated by the timer or by some other device and call device specific 
    // interrupt handler
    // NB: Each Core has its own pending local interrupt register. 
    int coreid = cpuid();
   8083c:	9400117f 	bl	84e38 <cpuid>
    unsigned int irq = get32(INT_SOURCE_0 + 4*coreid), irq0 = irq; 
   80840:	d2800c01 	mov	x1, #0x60                  	// #96
   80844:	531e7400 	lsl	w0, w0, #2
   80848:	f2a80001 	movk	x1, #0x4000, lsl #16
   8084c:	b860c834 	ldr	w20, [x1, w0, sxtw]

    if (irq & GENERIC_TIMER_INTERRUPT) {
   80850:	2a1403f3 	mov	w19, w20
   80854:	37080494 	tbnz	w20, #1, 808e4 <handle_irq+0xb4>
        handle_generic_timer_irq();
        irq &= (~GENERIC_TIMER_INTERRUPT);
    } 
    
    if (irq & GPU_SIDE_INTERRUPT) {
   80858:	36400153 	tbz	w19, #8, 80880 <handle_irq+0x50>
        unsigned int p1 = get32(IRQ_PENDING_1);
   8085c:	d2964080 	mov	x0, #0xb204                	// #45572
   80860:	f90013f5 	str	x21, [sp, #32]
   80864:	f2a7e000 	movk	x0, #0x3f00, lsl #16
   80868:	b9400015 	ldr	w21, [x0]
        if (p1 & IRQ_PENDING_1_AUX) {   // mini uart 
   8086c:	37e80495 	tbnz	w21, #29, 808fc <handle_irq+0xcc>
            uart_irq(); 
            p1 &= (~IRQ_PENDING_1_AUX); 
        }        
        if (p1 & SYSTEM_TIMER_IRQ_1) {
   80870:	370804d5 	tbnz	w21, #1, 80908 <handle_irq+0xd8>
        }
        if (p1) {
            E("unknown pending irq in IRQ_PENDING_1 p1 %08x", p1); 
            goto unknown; 
        }          
        irq &= (~GPU_SIDE_INTERRUPT);  // clear all "GPU side" irqs
   80874:	12177a73 	and	w19, w19, #0xfffffeff
        if (p1) {
   80878:	35000515 	cbnz	w21, 80918 <handle_irq+0xe8>
   8087c:	f94013f5 	ldr	x21, [sp, #32]
    } 

    if (!irq) 
   80880:	34000393 	cbz	w19, 808f0 <handle_irq+0xc0>
   80884:	90000033 	adrp	x19, 84000 <vectors>
        return;  // all irq bits cleared

unknown:
    E("Unknown pending irq: INT_SOURCE_0 %08x IRQ_BASIC_PENDING %08x " 
   80888:	d2964002 	mov	x2, #0xb200                	// #45568
   8088c:	d2964081 	mov	x1, #0xb204                	// #45572
   80890:	d2964100 	mov	x0, #0xb208                	// #45576
   80894:	f2a7e002 	movk	x2, #0x3f00, lsl #16
   80898:	f2a7e001 	movk	x1, #0x3f00, lsl #16
   8089c:	f2a7e000 	movk	x0, #0x3f00, lsl #16
   808a0:	b9400044 	ldr	w4, [x2]
   808a4:	9139e273 	add	x19, x19, #0xe78
   808a8:	b9400025 	ldr	w5, [x1]
   808ac:	2a1403e3 	mov	w3, w20
   808b0:	b9400006 	ldr	w6, [x0]
   808b4:	aa1303e1 	mov	x1, x19
   808b8:	52800d02 	mov	w2, #0x68                  	// #104
   808bc:	90000020 	adrp	x0, 84000 <vectors>
   808c0:	913b0000 	add	x0, x0, #0xec0
   808c4:	94000337 	bl	815a0 <tfp_printf>
        irq0, 
        get32(IRQ_BASIC_PENDING), 
        get32(IRQ_PENDING_1),
        get32(IRQ_PENDING_2)
        );
    BUG(); 
   808c8:	aa1303e1 	mov	x1, x19
   808cc:	90000020 	adrp	x0, 84000 <vectors>
}
   808d0:	a94153f3 	ldp	x19, x20, [sp, #16]
    BUG(); 
   808d4:	913ce000 	add	x0, x0, #0xf38
}
   808d8:	a8c37bfd 	ldp	x29, x30, [sp], #48
    BUG(); 
   808dc:	52800de2 	mov	w2, #0x6f                  	// #111
   808e0:	140003fe 	b	818d8 <assertion_failed>
        irq &= (~GENERIC_TIMER_INTERRUPT);
   808e4:	121e7a93 	and	w19, w20, #0xfffffffd
        handle_generic_timer_irq();
   808e8:	940005a2 	bl	81f70 <handle_generic_timer_irq>
        irq &= (~GENERIC_TIMER_INTERRUPT);
   808ec:	17ffffdb 	b	80858 <handle_irq+0x28>
}
   808f0:	a94153f3 	ldp	x19, x20, [sp, #16]
   808f4:	a8c37bfd 	ldp	x29, x30, [sp], #48
   808f8:	d65f03c0 	ret
            p1 &= (~IRQ_PENDING_1_AUX); 
   808fc:	12027ab5 	and	w21, w21, #0xdfffffff
            uart_irq(); 
   80900:	94000c76 	bl	83ad8 <uart_irq>
        if (p1 & SYSTEM_TIMER_IRQ_1) {
   80904:	360ffb95 	tbz	w21, #1, 80874 <handle_irq+0x44>
            p1 &= (~SYSTEM_TIMER_IRQ_1);
   80908:	121e7ab5 	and	w21, w21, #0xfffffffd
        irq &= (~GPU_SIDE_INTERRUPT);  // clear all "GPU side" irqs
   8090c:	12177a73 	and	w19, w19, #0xfffffeff
            sys_timer_irq();         //!STUDENT_DONOT_SEE
   80910:	94000674 	bl	822e0 <sys_timer_irq>
        if (p1) {
   80914:	34fffb55 	cbz	w21, 8087c <handle_irq+0x4c>
            E("unknown pending irq in IRQ_PENDING_1 p1 %08x", p1); 
   80918:	2a1503e3 	mov	w3, w21
   8091c:	90000033 	adrp	x19, 84000 <vectors>
   80920:	90000020 	adrp	x0, 84000 <vectors>
   80924:	9139e261 	add	x1, x19, #0xe78
   80928:	913a0000 	add	x0, x0, #0xe80
   8092c:	52800bc2 	mov	w2, #0x5e                  	// #94
   80930:	9400031c 	bl	815a0 <tfp_printf>
            goto unknown; 
   80934:	f94013f5 	ldr	x21, [sp, #32]
   80938:	17ffffd4 	b	80888 <handle_irq+0x58>
   8093c:	d503201f 	nop

0000000000080940 <show_invalid_entry_message>:
#endif

// esr: syndrome, elr: ~faulty pc, far: faulty access addr
void show_invalid_entry_message(int type, unsigned long esr, 
    unsigned long elr, unsigned long far)
{    
   80940:	a9bc7bfd 	stp	x29, x30, [sp, #-64]!
    E("%s, cpu%d, esr: 0x%016lx, elr: 0x%016lx, far: 0x%016lx",  
   80944:	900000a4 	adrp	x4, 94000 <_binary_font_psf_start+0x634>
   80948:	9107c084 	add	x4, x4, #0x1f0
{    
   8094c:	910003fd 	mov	x29, sp
   80950:	f9001bf7 	str	x23, [sp, #48]
    E("%s, cpu%d, esr: 0x%016lx, elr: 0x%016lx, far: 0x%016lx",  
   80954:	f860d897 	ldr	x23, [x4, w0, sxtw #3]
{    
   80958:	a90153f3 	stp	x19, x20, [sp, #16]
   8095c:	aa0103f4 	mov	x20, x1
    E("%s, cpu%d, esr: 0x%016lx, elr: 0x%016lx, far: 0x%016lx",  
   80960:	90000033 	adrp	x19, 84000 <vectors>
   80964:	9139e273 	add	x19, x19, #0xe78
{    
   80968:	a9025bf5 	stp	x21, x22, [sp, #32]
   8096c:	aa0203f5 	mov	x21, x2
   80970:	aa0303f6 	mov	x22, x3
    E("%s, cpu%d, esr: 0x%016lx, elr: 0x%016lx, far: 0x%016lx",  
   80974:	94001131 	bl	84e38 <cpuid>
   80978:	2a0003e4 	mov	w4, w0
   8097c:	aa1703e3 	mov	x3, x23
   80980:	aa1603e7 	mov	x7, x22
   80984:	aa1503e6 	mov	x6, x21
   80988:	aa1403e5 	mov	x5, x20
   8098c:	aa1303e1 	mov	x1, x19
   80990:	52800ee2 	mov	w2, #0x77                  	// #119
   80994:	90000020 	adrp	x0, 84000 <vectors>
   80998:	913d0000 	add	x0, x0, #0xf40
   8099c:	94000301 	bl	815a0 <tfp_printf>
        entry_error_messages[type], cpuid(), esr, elr, far);
    E("online esr decoder: %s0x%016lx", "https://esr.arm64.dev/#", esr);
   809a0:	aa1403e4 	mov	x4, x20
   809a4:	aa1303e1 	mov	x1, x19
}
   809a8:	a94153f3 	ldp	x19, x20, [sp, #16]
    E("online esr decoder: %s0x%016lx", "https://esr.arm64.dev/#", esr);
   809ac:	90000023 	adrp	x3, 84000 <vectors>
}
   809b0:	a9425bf5 	ldp	x21, x22, [sp, #32]
    E("online esr decoder: %s0x%016lx", "https://esr.arm64.dev/#", esr);
   809b4:	913e4063 	add	x3, x3, #0xf90
}
   809b8:	f9401bf7 	ldr	x23, [sp, #48]
    E("online esr decoder: %s0x%016lx", "https://esr.arm64.dev/#", esr);
   809bc:	90000020 	adrp	x0, 84000 <vectors>
}
   809c0:	a8c47bfd 	ldp	x29, x30, [sp], #64
    E("online esr decoder: %s0x%016lx", "https://esr.arm64.dev/#", esr);
   809c4:	913ea000 	add	x0, x0, #0xfa8
   809c8:	52800f22 	mov	w2, #0x79                  	// #121
   809cc:	140002f5 	b	815a0 <tfp_printf>

00000000000809d0 <kernel_main>:

void uart_send_string(char* str);

struct cpu cpus[NCPU]; 

void kernel_main() {
   809d0:	a9bf7bfd 	stp	x29, x30, [sp, #-16]!
   809d4:	910003fd 	mov	x29, sp
	// quest: UART. call uart_init() to initialize
	uart_init();                      // !STUDENT_DONOT_SEE
   809d8:	94000c5a 	bl	83b40 <uart_init>
	// quest: UART. init printf by init_printf(NULL, XXX)
	init_printf(NULL, putc);          // !STUDENT_DONOT_SEE
   809dc:	900000a1 	adrp	x1, 94000 <_binary_font_psf_start+0x634>
   809e0:	d2800000 	mov	x0, #0x0                   	// #0
   809e4:	f9415821 	ldr	x1, [x1, #688]
   809e8:	940002e8 	bl	81588 <init_printf>
	printf("------ kernel boot ------  core %d\n\r", cpuid());
   809ec:	94001113 	bl	84e38 <cpuid>
   809f0:	2a0003e1 	mov	w1, w0
   809f4:	b0000020 	adrp	x0, 85000 <get_el+0x198>
   809f8:	91046000 	add	x0, x0, #0x118
   809fc:	940002e9 	bl	815a0 <tfp_printf>
	printf("build time (kernel.c) %s %s\n", __DATE__, __TIME__); // simplicity 
   80a00:	b0000022 	adrp	x2, 85000 <get_el+0x198>
   80a04:	b0000021 	adrp	x1, 85000 <get_el+0x198>
   80a08:	91050042 	add	x2, x2, #0x140
   80a0c:	91054021 	add	x1, x1, #0x150
   80a10:	b0000020 	adrp	x0, 85000 <get_el+0x198>
   80a14:	91058000 	add	x0, x0, #0x160
   80a18:	940002e2 	bl	815a0 <tfp_printf>

	sys_timer_init();                   // kernel timer: delay, timekeeping...
   80a1c:	940005a9 	bl	820c0 <sys_timer_init>
	enable_interrupt_controller(0);     // coreid
   80a20:	52800000 	mov	w0, #0x0                   	// #0
   80a24:	97ffff77 	bl	80800 <enable_interrupt_controller>
	// quest: sys_timer irq
	enable_irq();		// !STUDENT_DONOT_SEE
   80a28:	940010fc 	bl	84e18 <enable_irq>

	generic_timer_init();               // periodic ticks alive
   80a2c:	9400054b 	bl	81f58 <generic_timer_init>

	if (fb_init() != 0) BUG();          // will show the OS logo
   80a30:	940007f6 	bl	82a08 <fb_init>
   80a34:	350000a0 	cbnz	w0, 80a48 <kernel_main+0x78>

	// test_ktimer();
	// test_fb_voffset();               // cycle through color quads
	donut();		// !STUDENT_DONOT_SEE    uses virtual timer for animation
   80a38:	9400099c 	bl	830a8 <donut>
	
	// quest: textual donut. call donut_text()
	// donut_text();		// !STUDENT_DONOT_SEE

	while (1)
		asm volatile("wfi");            // what happen here?
   80a3c:	d503207f 	wfi
   80a40:	d503207f 	wfi
	while (1)
   80a44:	17fffffe 	b	80a3c <kernel_main+0x6c>
	if (fb_init() != 0) BUG();          // will show the OS logo
   80a48:	b0000021 	adrp	x1, 85000 <get_el+0x198>
   80a4c:	90000020 	adrp	x0, 84000 <vectors>
   80a50:	91060021 	add	x1, x1, #0x180
   80a54:	913ce000 	add	x0, x0, #0xf38
   80a58:	52800482 	mov	w2, #0x24                  	// #36
   80a5c:	9400039f 	bl	818d8 <assertion_failed>
	donut();		// !STUDENT_DONOT_SEE    uses virtual timer for animation
   80a60:	94000992 	bl	830a8 <donut>
   80a64:	17fffff6 	b	80a3c <kernel_main+0x6c>

0000000000080a68 <ulli2a>:
    unsigned long long int num, struct param *p)
{
    int n = 0;
    unsigned long long int d = 1;
    char *bf = p->bf;
    while (num / d >= p->base)
   80a68:	b9400c26 	ldr	w6, [x1, #12]
    char *bf = p->bf;
   80a6c:	f9400829 	ldr	x9, [x1, #16]
    while (num / d >= p->base)
   80a70:	2a0603e4 	mov	w4, w6
   80a74:	eb26401f 	cmp	x0, w6, uxtw
   80a78:	54000583 	b.cc	80b28 <ulli2a+0xc0>  // b.lo, b.ul, b.last
    unsigned long long int d = 1;
   80a7c:	d2800022 	mov	x2, #0x1                   	// #1
        d *= p->base;
   80a80:	9b047c42 	mul	x2, x2, x4
    while (num / d >= p->base)
   80a84:	9ac20803 	udiv	x3, x0, x2
   80a88:	eb04007f 	cmp	x3, x4
   80a8c:	54ffffa2 	b.cs	80a80 <ulli2a+0x18>  // b.hs, b.nlast
    while (d != 0) {
   80a90:	b4000462 	cbz	x2, 80b1c <ulli2a+0xb4>
    int n = 0;
   80a94:	52800007 	mov	w7, #0x0                   	// #0
        int dgt = num / d;
        num %= d;
        d /= p->base;
        if (n || dgt > 0 || d == 0) {
            *bf++ = dgt + (dgt < 10 ? '0' : (p->uc ? 'A' : 'a') - 10);
   80a98:	528006eb 	mov	w11, #0x37                  	// #55
   80a9c:	52800aea 	mov	w10, #0x57                  	// #87
        if (n || dgt > 0 || d == 0) {
   80aa0:	710000ff 	cmp	w7, #0x0
        num %= d;
   80aa4:	9b028060 	msub	x0, x3, x2, x0
        d /= p->base;
   80aa8:	9ac40848 	udiv	x8, x2, x4
            *bf++ = dgt + (dgt < 10 ? '0' : (p->uc ? 'A' : 'a') - 10);
   80aac:	aa0903e5 	mov	x5, x9
        if (n || dgt > 0 || d == 0) {
   80ab0:	7a400860 	ccmp	w3, #0x0, #0x0, eq  // eq = none
   80ab4:	540000ec 	b.gt	80ad0 <ulli2a+0x68>
   80ab8:	eb02009f 	cmp	x4, x2
   80abc:	540002c9 	b.ls	80b14 <ulli2a+0xac>  // b.plast
            *bf++ = dgt + (dgt < 10 ? '0' : (p->uc ? 'A' : 'a') - 10);
   80ac0:	1100c063 	add	w3, w3, #0x30
   80ac4:	380014a3 	strb	w3, [x5], #1
            ++n;
        }
    }
    *bf = 0;
   80ac8:	390000bf 	strb	wzr, [x5]
}
   80acc:	d65f03c0 	ret
            *bf++ = dgt + (dgt < 10 ? '0' : (p->uc ? 'A' : 'a') - 10);
   80ad0:	7100247f 	cmp	w3, #0x9
   80ad4:	52800606 	mov	w6, #0x30                  	// #48
   80ad8:	5400008d 	b.le	80ae8 <ulli2a+0x80>
   80adc:	39400026 	ldrb	w6, [x1]
   80ae0:	f27e00df 	tst	x6, #0x4
   80ae4:	1a8a1166 	csel	w6, w11, w10, ne  // ne = any
   80ae8:	0b0300c3 	add	w3, w6, w3
   80aec:	380014a3 	strb	w3, [x5], #1
            ++n;
   80af0:	110004e7 	add	w7, w7, #0x1
    while (d != 0) {
   80af4:	eb02009f 	cmp	x4, x2
            *bf++ = dgt + (dgt < 10 ? '0' : (p->uc ? 'A' : 'a') - 10);
   80af8:	aa0503e9 	mov	x9, x5
    while (d != 0) {
   80afc:	54fffe68 	b.hi	80ac8 <ulli2a+0x60>  // b.pmore
   80b00:	b9400c26 	ldr	w6, [x1, #12]
   80b04:	9ac80803 	udiv	x3, x0, x8
   80b08:	2a0603e4 	mov	w4, w6
    int n = 0;
   80b0c:	aa0803e2 	mov	x2, x8
   80b10:	17ffffe4 	b	80aa0 <ulli2a+0x38>
   80b14:	52800007 	mov	w7, #0x0                   	// #0
   80b18:	17fffffb 	b	80b04 <ulli2a+0x9c>
    char *bf = p->bf;
   80b1c:	aa0903e5 	mov	x5, x9
    *bf = 0;
   80b20:	390000bf 	strb	wzr, [x5]
}
   80b24:	d65f03c0 	ret
   80b28:	aa0003e3 	mov	x3, x0
    unsigned long long int d = 1;
   80b2c:	d2800022 	mov	x2, #0x1                   	// #1
   80b30:	17ffffd9 	b	80a94 <ulli2a+0x2c>
   80b34:	d503201f 	nop

0000000000080b38 <uli2a>:
static void uli2a(unsigned long int num, struct param *p)
{
    int n = 0;
    unsigned long int d = 1;
    char *bf = p->bf;
    while (num / d >= p->base)
   80b38:	b9400c26 	ldr	w6, [x1, #12]
    char *bf = p->bf;
   80b3c:	f9400829 	ldr	x9, [x1, #16]
    while (num / d >= p->base)
   80b40:	2a0603e4 	mov	w4, w6
   80b44:	eb26401f 	cmp	x0, w6, uxtw
   80b48:	54000583 	b.cc	80bf8 <uli2a+0xc0>  // b.lo, b.ul, b.last
    unsigned long int d = 1;
   80b4c:	d2800022 	mov	x2, #0x1                   	// #1
        d *= p->base;
   80b50:	9b047c42 	mul	x2, x2, x4
    while (num / d >= p->base)
   80b54:	9ac20803 	udiv	x3, x0, x2
   80b58:	eb04007f 	cmp	x3, x4
   80b5c:	54ffffa2 	b.cs	80b50 <uli2a+0x18>  // b.hs, b.nlast
    while (d != 0) {
   80b60:	b4000462 	cbz	x2, 80bec <uli2a+0xb4>
    int n = 0;
   80b64:	52800007 	mov	w7, #0x0                   	// #0
        int dgt = num / d;
        num %= d;
        d /= p->base;
        if (n || dgt > 0 || d == 0) {
            *bf++ = dgt + (dgt < 10 ? '0' : (p->uc ? 'A' : 'a') - 10);
   80b68:	528006eb 	mov	w11, #0x37                  	// #55
   80b6c:	52800aea 	mov	w10, #0x57                  	// #87
        if (n || dgt > 0 || d == 0) {
   80b70:	710000ff 	cmp	w7, #0x0
        num %= d;
   80b74:	9b028060 	msub	x0, x3, x2, x0
        d /= p->base;
   80b78:	9ac40848 	udiv	x8, x2, x4
            *bf++ = dgt + (dgt < 10 ? '0' : (p->uc ? 'A' : 'a') - 10);
   80b7c:	aa0903e5 	mov	x5, x9
        if (n || dgt > 0 || d == 0) {
   80b80:	7a400860 	ccmp	w3, #0x0, #0x0, eq  // eq = none
   80b84:	540000ec 	b.gt	80ba0 <uli2a+0x68>
   80b88:	eb02009f 	cmp	x4, x2
   80b8c:	540002c9 	b.ls	80be4 <uli2a+0xac>  // b.plast
            *bf++ = dgt + (dgt < 10 ? '0' : (p->uc ? 'A' : 'a') - 10);
   80b90:	1100c063 	add	w3, w3, #0x30
   80b94:	380014a3 	strb	w3, [x5], #1
            ++n;
        }
    }
    *bf = 0;
   80b98:	390000bf 	strb	wzr, [x5]
}
   80b9c:	d65f03c0 	ret
            *bf++ = dgt + (dgt < 10 ? '0' : (p->uc ? 'A' : 'a') - 10);
   80ba0:	7100247f 	cmp	w3, #0x9
   80ba4:	52800606 	mov	w6, #0x30                  	// #48
   80ba8:	5400008d 	b.le	80bb8 <uli2a+0x80>
   80bac:	39400026 	ldrb	w6, [x1]
   80bb0:	f27e00df 	tst	x6, #0x4
   80bb4:	1a8a1166 	csel	w6, w11, w10, ne  // ne = any
   80bb8:	0b0300c3 	add	w3, w6, w3
   80bbc:	380014a3 	strb	w3, [x5], #1
            ++n;
   80bc0:	110004e7 	add	w7, w7, #0x1
    while (d != 0) {
   80bc4:	eb02009f 	cmp	x4, x2
            *bf++ = dgt + (dgt < 10 ? '0' : (p->uc ? 'A' : 'a') - 10);
   80bc8:	aa0503e9 	mov	x9, x5
    while (d != 0) {
   80bcc:	54fffe68 	b.hi	80b98 <uli2a+0x60>  // b.pmore
   80bd0:	b9400c26 	ldr	w6, [x1, #12]
   80bd4:	9ac80803 	udiv	x3, x0, x8
   80bd8:	2a0603e4 	mov	w4, w6
    int n = 0;
   80bdc:	aa0803e2 	mov	x2, x8
   80be0:	17ffffe4 	b	80b70 <uli2a+0x38>
   80be4:	52800007 	mov	w7, #0x0                   	// #0
   80be8:	17fffffb 	b	80bd4 <uli2a+0x9c>
    char *bf = p->bf;
   80bec:	aa0903e5 	mov	x5, x9
    *bf = 0;
   80bf0:	390000bf 	strb	wzr, [x5]
}
   80bf4:	d65f03c0 	ret
   80bf8:	aa0003e3 	mov	x3, x0
    unsigned long int d = 1;
   80bfc:	d2800022 	mov	x2, #0x1                   	// #1
   80c00:	17ffffd9 	b	80b64 <uli2a+0x2c>
   80c04:	d503201f 	nop

0000000000080c08 <ui2a>:
static void ui2a(unsigned int num, struct param *p)
{
    int n = 0;
    unsigned int d = 1;
    char *bf = p->bf;
    while (num / d >= p->base)
   80c08:	b9400c24 	ldr	w4, [x1, #12]
    char *bf = p->bf;
   80c0c:	f9400826 	ldr	x6, [x1, #16]
    while (num / d >= p->base)
   80c10:	6b04001f 	cmp	w0, w4
   80c14:	54000583 	b.cc	80cc4 <ui2a+0xbc>  // b.lo, b.ul, b.last
    unsigned int d = 1;
   80c18:	52800022 	mov	w2, #0x1                   	// #1
   80c1c:	d503201f 	nop
        d *= p->base;
   80c20:	1b047c42 	mul	w2, w2, w4
    while (num / d >= p->base)
   80c24:	1ac20803 	udiv	w3, w0, w2
   80c28:	6b04007f 	cmp	w3, w4
   80c2c:	54ffffa2 	b.cs	80c20 <ui2a+0x18>  // b.hs, b.nlast
    while (d != 0) {
   80c30:	34000442 	cbz	w2, 80cb8 <ui2a+0xb0>
    int n = 0;
   80c34:	52800007 	mov	w7, #0x0                   	// #0
        int dgt = num / d;
        num %= d;
        d /= p->base;
        if (n || dgt > 0 || d == 0) {
            *bf++ = dgt + (dgt < 10 ? '0' : (p->uc ? 'A' : 'a') - 10);
   80c38:	528006ea 	mov	w10, #0x37                  	// #55
   80c3c:	52800ae9 	mov	w9, #0x57                  	// #87
        if (n || dgt > 0 || d == 0) {
   80c40:	710000ff 	cmp	w7, #0x0
        num %= d;
   80c44:	1b028060 	msub	w0, w3, w2, w0
        d /= p->base;
   80c48:	1ac40848 	udiv	w8, w2, w4
            *bf++ = dgt + (dgt < 10 ? '0' : (p->uc ? 'A' : 'a') - 10);
   80c4c:	aa0603e5 	mov	x5, x6
        if (n || dgt > 0 || d == 0) {
   80c50:	7a400860 	ccmp	w3, #0x0, #0x0, eq  // eq = none
   80c54:	540000ec 	b.gt	80c70 <ui2a+0x68>
   80c58:	6b04005f 	cmp	w2, w4
   80c5c:	540002a2 	b.cs	80cb0 <ui2a+0xa8>  // b.hs, b.nlast
            *bf++ = dgt + (dgt < 10 ? '0' : (p->uc ? 'A' : 'a') - 10);
   80c60:	1100c063 	add	w3, w3, #0x30
   80c64:	380014a3 	strb	w3, [x5], #1
            ++n;
        }
    }
    *bf = 0;
   80c68:	390000bf 	strb	wzr, [x5]
}
   80c6c:	d65f03c0 	ret
            *bf++ = dgt + (dgt < 10 ? '0' : (p->uc ? 'A' : 'a') - 10);
   80c70:	7100247f 	cmp	w3, #0x9
   80c74:	52800606 	mov	w6, #0x30                  	// #48
   80c78:	5400008d 	b.le	80c88 <ui2a+0x80>
   80c7c:	39400026 	ldrb	w6, [x1]
   80c80:	f27e00df 	tst	x6, #0x4
   80c84:	1a891146 	csel	w6, w10, w9, ne  // ne = any
   80c88:	0b0300c3 	add	w3, w6, w3
   80c8c:	380014a3 	strb	w3, [x5], #1
            ++n;
   80c90:	110004e7 	add	w7, w7, #0x1
    while (d != 0) {
   80c94:	6b04005f 	cmp	w2, w4
            *bf++ = dgt + (dgt < 10 ? '0' : (p->uc ? 'A' : 'a') - 10);
   80c98:	aa0503e6 	mov	x6, x5
    while (d != 0) {
   80c9c:	54fffe63 	b.cc	80c68 <ui2a+0x60>  // b.lo, b.ul, b.last
   80ca0:	b9400c24 	ldr	w4, [x1, #12]
   80ca4:	1ac80803 	udiv	w3, w0, w8
    int n = 0;
   80ca8:	2a0803e2 	mov	w2, w8
   80cac:	17ffffe5 	b	80c40 <ui2a+0x38>
   80cb0:	52800007 	mov	w7, #0x0                   	// #0
   80cb4:	17fffffc 	b	80ca4 <ui2a+0x9c>
    char *bf = p->bf;
   80cb8:	aa0603e5 	mov	x5, x6
    *bf = 0;
   80cbc:	390000bf 	strb	wzr, [x5]
}
   80cc0:	d65f03c0 	ret
   80cc4:	2a0003e3 	mov	w3, w0
    unsigned int d = 1;
   80cc8:	52800022 	mov	w2, #0x1                   	// #1
   80ccc:	17ffffda 	b	80c34 <ui2a+0x2c>

0000000000080cd0 <putchw>:
    *nump = num;
    return ch;
}

static void putchw(void *putp, putcf putf, struct param *p)
{
   80cd0:	a9bc7bfd 	stp	x29, x30, [sp, #-64]!
   80cd4:	910003fd 	mov	x29, sp
   80cd8:	a90153f3 	stp	x19, x20, [sp, #16]
   80cdc:	aa0003f4 	mov	x20, x0
    char ch;
    int n = p->width;
   80ce0:	b9400453 	ldr	w19, [x2, #4]
    char *bf = p->bf;

    /* Number of filling characters */
    while (*bf++ && n > 0)
   80ce4:	f9400840 	ldr	x0, [x2, #16]
{
   80ce8:	a9025bf5 	stp	x21, x22, [sp, #32]
   80cec:	aa0103f5 	mov	x21, x1
   80cf0:	f9001bf7 	str	x23, [sp, #48]
   80cf4:	aa0203f7 	mov	x23, x2
    while (*bf++ && n > 0)
   80cf8:	38401401 	ldrb	w1, [x0], #1
   80cfc:	7100003f 	cmp	w1, #0x0
   80d00:	7a401a64 	ccmp	w19, #0x0, #0x4, ne  // ne = any
   80d04:	540000cd 	b.le	80d1c <putchw+0x4c>
   80d08:	38401401 	ldrb	w1, [x0], #1
        n--;
   80d0c:	51000673 	sub	w19, w19, #0x1
    while (*bf++ && n > 0)
   80d10:	7100003f 	cmp	w1, #0x0
   80d14:	7a401a64 	ccmp	w19, #0x0, #0x4, ne  // ne = any
   80d18:	54ffff8c 	b.gt	80d08 <putchw+0x38>
    if (p->sign)
   80d1c:	394022e1 	ldrb	w1, [x23, #8]
        n--;
    if (p->alt && p->base == 16)
   80d20:	394002e0 	ldrb	w0, [x23]
        n--;
   80d24:	7100003f 	cmp	w1, #0x0
   80d28:	1a9f07e2 	cset	w2, ne  // ne = any
   80d2c:	4b020273 	sub	w19, w19, w2
    if (p->alt && p->base == 16)
   80d30:	360800e0 	tbz	w0, #1, 80d4c <putchw+0x7c>
   80d34:	b9400ee2 	ldr	w2, [x23, #12]
   80d38:	7100405f 	cmp	w2, #0x10
   80d3c:	54000a80 	b.eq	80e8c <putchw+0x1bc>  // b.none
        n -= 2;
    else if (p->alt && p->base == 8)
        n--;
   80d40:	7100205f 	cmp	w2, #0x8
   80d44:	1a9f17e2 	cset	w2, eq  // eq = none
   80d48:	4b020273 	sub	w19, w19, w2

    /* Fill with space to align to the right, before alternate or sign */
    if (!p->lz && !p->align_left) {
   80d4c:	52800122 	mov	w2, #0x9                   	// #9
   80d50:	6a02001f 	tst	w0, w2
   80d54:	54000181 	b.ne	80d84 <putchw+0xb4>  // b.any
        while (n-- > 0)
   80d58:	7100027f 	cmp	w19, #0x0
   80d5c:	51000673 	sub	w19, w19, #0x1
   80d60:	5400012d 	b.le	80d84 <putchw+0xb4>
   80d64:	d503201f 	nop
   80d68:	51000673 	sub	w19, w19, #0x1
            putf(putp, ' ');
   80d6c:	aa1403e0 	mov	x0, x20
   80d70:	52800401 	mov	w1, #0x20                  	// #32
   80d74:	d63f02a0 	blr	x21
        while (n-- > 0)
   80d78:	3100067f 	cmn	w19, #0x1
   80d7c:	54ffff61 	b.ne	80d68 <putchw+0x98>  // b.any
   80d80:	394022e1 	ldrb	w1, [x23, #8]
    }

    /* print sign */
    if (p->sign)
   80d84:	34000061 	cbz	w1, 80d90 <putchw+0xc0>
        putf(putp, p->sign);
   80d88:	aa1403e0 	mov	x0, x20
   80d8c:	d63f02a0 	blr	x21

    /* Alternate */
    if (p->alt && p->base == 16) {
   80d90:	394002e0 	ldrb	w0, [x23]
   80d94:	360800c0 	tbz	w0, #1, 80dac <putchw+0xdc>
   80d98:	b9400ee1 	ldr	w1, [x23, #12]
   80d9c:	7100403f 	cmp	w1, #0x10
   80da0:	540005e0 	b.eq	80e5c <putchw+0x18c>  // b.none
        putf(putp, '0');
        putf(putp, (p->uc ? 'X' : 'x'));
    } else if (p->alt && p->base == 8) {
   80da4:	7100203f 	cmp	w1, #0x8
   80da8:	54000760 	b.eq	80e94 <putchw+0x1c4>  // b.none
        putf(putp, '0');
    }

    /* Fill with zeros, after alternate or sign */
    if (p->lz) {
   80dac:	36000160 	tbz	w0, #0, 80dd8 <putchw+0x108>
        while (n-- > 0)
   80db0:	7100027f 	cmp	w19, #0x0
   80db4:	51000673 	sub	w19, w19, #0x1
   80db8:	5400010d 	b.le	80dd8 <putchw+0x108>
   80dbc:	d503201f 	nop
   80dc0:	51000673 	sub	w19, w19, #0x1
            putf(putp, '0');
   80dc4:	aa1403e0 	mov	x0, x20
   80dc8:	52800601 	mov	w1, #0x30                  	// #48
   80dcc:	d63f02a0 	blr	x21
        while (n-- > 0)
   80dd0:	3100067f 	cmn	w19, #0x1
   80dd4:	54ffff61 	b.ne	80dc0 <putchw+0xf0>  // b.any
    }

    /* Put actual buffer */
    bf = p->bf;
    while ((ch = *bf++))
   80dd8:	f9400af6 	ldr	x22, [x23, #16]
   80ddc:	384016c1 	ldrb	w1, [x22], #1
   80de0:	340000c1 	cbz	w1, 80df8 <putchw+0x128>
   80de4:	d503201f 	nop
        putf(putp, ch);
   80de8:	aa1403e0 	mov	x0, x20
   80dec:	d63f02a0 	blr	x21
    while ((ch = *bf++))
   80df0:	384016c1 	ldrb	w1, [x22], #1
   80df4:	35ffffa1 	cbnz	w1, 80de8 <putchw+0x118>

    /* Fill with space to align to the left, after string */
    if (!p->lz && p->align_left) {
   80df8:	394002e1 	ldrb	w1, [x23]
   80dfc:	52800120 	mov	w0, #0x9                   	// #9
   80e00:	0a010000 	and	w0, w0, w1
   80e04:	7100201f 	cmp	w0, #0x8
   80e08:	540000c0 	b.eq	80e20 <putchw+0x150>  // b.none
        while (n-- > 0)
            putf(putp, ' ');
    }
}
   80e0c:	a94153f3 	ldp	x19, x20, [sp, #16]
   80e10:	a9425bf5 	ldp	x21, x22, [sp, #32]
   80e14:	f9401bf7 	ldr	x23, [sp, #48]
   80e18:	a8c47bfd 	ldp	x29, x30, [sp], #64
   80e1c:	d65f03c0 	ret
        while (n-- > 0)
   80e20:	7100027f 	cmp	w19, #0x0
   80e24:	51000673 	sub	w19, w19, #0x1
   80e28:	54ffff2d 	b.le	80e0c <putchw+0x13c>
   80e2c:	d503201f 	nop
   80e30:	51000673 	sub	w19, w19, #0x1
            putf(putp, ' ');
   80e34:	aa1403e0 	mov	x0, x20
   80e38:	52800401 	mov	w1, #0x20                  	// #32
   80e3c:	d63f02a0 	blr	x21
        while (n-- > 0)
   80e40:	3100067f 	cmn	w19, #0x1
   80e44:	54ffff61 	b.ne	80e30 <putchw+0x160>  // b.any
}
   80e48:	a94153f3 	ldp	x19, x20, [sp, #16]
   80e4c:	a9425bf5 	ldp	x21, x22, [sp, #32]
   80e50:	f9401bf7 	ldr	x23, [sp, #48]
   80e54:	a8c47bfd 	ldp	x29, x30, [sp], #64
   80e58:	d65f03c0 	ret
        putf(putp, '0');
   80e5c:	aa1403e0 	mov	x0, x20
   80e60:	52800601 	mov	w1, #0x30                  	// #48
   80e64:	d63f02a0 	blr	x21
        putf(putp, (p->uc ? 'X' : 'x'));
   80e68:	394002e3 	ldrb	w3, [x23]
   80e6c:	52800b02 	mov	w2, #0x58                  	// #88
   80e70:	aa1403e0 	mov	x0, x20
   80e74:	52800f01 	mov	w1, #0x78                  	// #120
   80e78:	f27e007f 	tst	x3, #0x4
   80e7c:	1a811041 	csel	w1, w2, w1, ne  // ne = any
   80e80:	d63f02a0 	blr	x21
   80e84:	394002e0 	ldrb	w0, [x23]
   80e88:	17ffffc9 	b	80dac <putchw+0xdc>
        n -= 2;
   80e8c:	51000a73 	sub	w19, w19, #0x2
   80e90:	17ffffaf 	b	80d4c <putchw+0x7c>
        putf(putp, '0');
   80e94:	aa1403e0 	mov	x0, x20
   80e98:	52800601 	mov	w1, #0x30                  	// #48
   80e9c:	d63f02a0 	blr	x21
   80ea0:	394002e0 	ldrb	w0, [x23]
   80ea4:	17ffffc2 	b	80dac <putchw+0xdc>

0000000000080ea8 <_vsnprintf_putcf>:
};

static void _vsnprintf_putcf(void *p, char c)
{
  struct _vsnprintf_putcf_data *data = (struct _vsnprintf_putcf_data*)p;
  if (data->num_chars < data->dest_capacity)
   80ea8:	f9400003 	ldr	x3, [x0]
{
   80eac:	12001c21 	and	w1, w1, #0xff
  if (data->num_chars < data->dest_capacity)
   80eb0:	f9400802 	ldr	x2, [x0, #16]
   80eb4:	eb03005f 	cmp	x2, x3
   80eb8:	54000082 	b.cs	80ec8 <_vsnprintf_putcf+0x20>  // b.hs, b.nlast
    data->dest[data->num_chars] = c;
   80ebc:	f9400403 	ldr	x3, [x0, #8]
   80ec0:	38226861 	strb	w1, [x3, x2]
   80ec4:	f9400802 	ldr	x2, [x0, #16]
  data->num_chars ++;
   80ec8:	91000442 	add	x2, x2, #0x1
   80ecc:	f9000802 	str	x2, [x0, #16]
}
   80ed0:	d65f03c0 	ret
   80ed4:	d503201f 	nop

0000000000080ed8 <_vsprintf_putcf>:
};

static void _vsprintf_putcf(void *p, char c)
{
  struct _vsprintf_putcf_data *data = (struct _vsprintf_putcf_data*)p;
  data->dest[data->num_chars++] = c;
   80ed8:	a9400803 	ldp	x3, x2, [x0]
   80edc:	91000444 	add	x4, x2, #0x1
   80ee0:	f9000404 	str	x4, [x0, #8]
   80ee4:	38226861 	strb	w1, [x3, x2]
}
   80ee8:	d65f03c0 	ret
   80eec:	d503201f 	nop

0000000000080ef0 <tfp_format>:
{
   80ef0:	a9b67bfd 	stp	x29, x30, [sp, #-160]!
   80ef4:	910003fd 	mov	x29, sp
   80ef8:	a90573fb 	stp	x27, x28, [sp, #80]
    while ((ch = *(fmt++))) {
   80efc:	aa0203fb 	mov	x27, x2
{
   80f00:	a90153f3 	stp	x19, x20, [sp, #16]
   80f04:	aa0103f4 	mov	x20, x1
   80f08:	aa0003f3 	mov	x19, x0
   80f0c:	a9025bf5 	stp	x21, x22, [sp, #32]
   80f10:	b9401876 	ldr	w22, [x3, #24]
   80f14:	a9046bf9 	stp	x25, x26, [sp, #64]
    p.bf = bf;
   80f18:	9101c3f9 	add	x25, sp, #0x70
    while ((ch = *(fmt++))) {
   80f1c:	38401761 	ldrb	w1, [x27], #1
   80f20:	a9400075 	ldp	x21, x0, [x3]
   80f24:	f90037e0 	str	x0, [sp, #104]
    p.bf = bf;
   80f28:	f9004ff9 	str	x25, [sp, #152]
    while ((ch = *(fmt++))) {
   80f2c:	34000a81 	cbz	w1, 8107c <tfp_format+0x18c>
                p.base = 10;
   80f30:	5280015a 	mov	w26, #0xa                   	// #10
   80f34:	a90363f7 	stp	x23, x24, [sp, #48]
    ui2a(num, p);
   80f38:	910223f7 	add	x23, sp, #0x88
            p.lz = 0;
   80f3c:	12800178 	mov	w24, #0xfffffff4            	// #-12
   80f40:	14000008 	b	80f60 <tfp_format+0x70>
            putf(putp, ch);
   80f44:	aa1303e0 	mov	x0, x19
   80f48:	d63f0280 	blr	x20
   80f4c:	aa1c03e0 	mov	x0, x28
   80f50:	aa1b03fc 	mov	x28, x27
   80f54:	aa0003fb 	mov	x27, x0
    while ((ch = *(fmt++))) {
   80f58:	39400381 	ldrb	w1, [x28]
   80f5c:	340008e1 	cbz	w1, 81078 <tfp_format+0x188>
        if (ch != '%') {
   80f60:	7100943f 	cmp	w1, #0x25
   80f64:	9100077c 	add	x28, x27, #0x1
   80f68:	54fffee1 	b.ne	80f44 <tfp_format+0x54>  // b.any
            p.lz = 0;
   80f6c:	394223e0 	ldrb	w0, [sp, #136]
            while ((ch = *(fmt++))) {
   80f70:	39400363 	ldrb	w3, [x27]
            p.lz = 0;
   80f74:	0a180000 	and	w0, w0, w24
   80f78:	390223e0 	strb	w0, [sp, #136]
            p.width = 0;
   80f7c:	b9008fff 	str	wzr, [sp, #140]
            p.sign = 0;
   80f80:	390243ff 	strb	wzr, [sp, #144]
            while ((ch = *(fmt++))) {
   80f84:	340007a3 	cbz	w3, 81078 <tfp_format+0x188>
   80f88:	52800002 	mov	w2, #0x0                   	// #0
   80f8c:	52800001 	mov	w1, #0x0                   	// #0
   80f90:	52800000 	mov	w0, #0x0                   	// #0
                switch (ch) {
   80f94:	7100b47f 	cmp	w3, #0x2d
   80f98:	54000f00 	b.eq	81178 <tfp_format+0x288>  // b.none
   80f9c:	7100c07f 	cmp	w3, #0x30
   80fa0:	540009e0 	b.eq	810dc <tfp_format+0x1ec>  // b.none
   80fa4:	71008c7f 	cmp	w3, #0x23
   80fa8:	54000760 	b.eq	81094 <tfp_format+0x1a4>  // b.none
   80fac:	34000080 	cbz	w0, 80fbc <tfp_format+0xcc>
   80fb0:	394223e0 	ldrb	w0, [sp, #136]
   80fb4:	321d0000 	orr	w0, w0, #0x8
   80fb8:	390223e0 	strb	w0, [sp, #136]
   80fbc:	34000081 	cbz	w1, 80fcc <tfp_format+0xdc>
   80fc0:	394223e0 	ldrb	w0, [sp, #136]
   80fc4:	32000000 	orr	w0, w0, #0x1
   80fc8:	390223e0 	strb	w0, [sp, #136]
   80fcc:	34000082 	cbz	w2, 80fdc <tfp_format+0xec>
   80fd0:	394223e0 	ldrb	w0, [sp, #136]
   80fd4:	321f0000 	orr	w0, w0, #0x2
   80fd8:	390223e0 	strb	w0, [sp, #136]
            if (ch >= '0' && ch <= '9') {
   80fdc:	5100c066 	sub	w6, w3, #0x30
   80fe0:	12001cc0 	and	w0, w6, #0xff
   80fe4:	7100241f 	cmp	w0, #0x9
   80fe8:	54001209 	b.ls	81228 <tfp_format+0x338>  // b.plast
            if (ch == '.') {
   80fec:	7100b87f 	cmp	w3, #0x2e
   80ff0:	54001540 	b.eq	81298 <tfp_format+0x3a8>  // b.none
            if (ch == 'z') {
   80ff4:	7101e87f 	cmp	w3, #0x7a
   80ff8:	540010e0 	b.eq	81214 <tfp_format+0x324>  // b.none
            if (ch == 'l') {
   80ffc:	7101b07f 	cmp	w3, #0x6c
   81000:	54001600 	b.eq	812c0 <tfp_format+0x3d0>  // b.none
            switch (ch) {
   81004:	7101a47f 	cmp	w3, #0x69
   81008:	54002640 	b.eq	814d0 <tfp_format+0x5e0>  // b.none
            char lng = 0;  /* 1 for long, 2 for long long */
   8100c:	52800000 	mov	w0, #0x0                   	// #0
            switch (ch) {
   81010:	7101a47f 	cmp	w3, #0x69
   81014:	54000b69 	b.ls	81180 <tfp_format+0x290>  // b.plast
   81018:	7101cc7f 	cmp	w3, #0x73
   8101c:	540017e0 	b.eq	81318 <tfp_format+0x428>  // b.none
   81020:	54000889 	b.ls	81130 <tfp_format+0x240>  // b.plast
   81024:	7101d47f 	cmp	w3, #0x75
   81028:	540005e1 	b.ne	810e4 <tfp_format+0x1f4>  // b.any
                p.base = 10;
   8102c:	b90097fa 	str	w26, [sp, #148]
                if (2 == lng)
   81030:	7100081f 	cmp	w0, #0x2
   81034:	540006e0 	b.eq	81110 <tfp_format+0x220>  // b.none
                  if (1 == lng)
   81038:	7100041f 	cmp	w0, #0x1
   8103c:	540008e0 	b.eq	81158 <tfp_format+0x268>  // b.none
                    ui2a(va_arg(va, unsigned int), &p);
   81040:	37f81c36 	tbnz	w22, #31, 813c4 <tfp_format+0x4d4>
   81044:	91002ea1 	add	x1, x21, #0xb
   81048:	aa1503e0 	mov	x0, x21
   8104c:	927df035 	and	x21, x1, #0xfffffffffffffff8
   81050:	b9400000 	ldr	w0, [x0]
   81054:	aa1703e1 	mov	x1, x23
   81058:	97fffeec 	bl	80c08 <ui2a>
                putchw(putp, putf, &p);
   8105c:	aa1403e1 	mov	x1, x20
   81060:	aa1703e2 	mov	x2, x23
   81064:	aa1303e0 	mov	x0, x19
   81068:	97ffff1a 	bl	80cd0 <putchw>
    while ((ch = *(fmt++))) {
   8106c:	39400381 	ldrb	w1, [x28]
   81070:	9100079b 	add	x27, x28, #0x1
   81074:	35fff761 	cbnz	w1, 80f60 <tfp_format+0x70>
   81078:	a94363f7 	ldp	x23, x24, [sp, #48]
}
   8107c:	a94153f3 	ldp	x19, x20, [sp, #16]
   81080:	a9425bf5 	ldp	x21, x22, [sp, #32]
   81084:	a9446bf9 	ldp	x25, x26, [sp, #64]
   81088:	a94573fb 	ldp	x27, x28, [sp, #80]
   8108c:	a8ca7bfd 	ldp	x29, x30, [sp], #160
   81090:	d65f03c0 	ret
                    p.alt = 1;
   81094:	52800022 	mov	w2, #0x1                   	// #1
            while ((ch = *(fmt++))) {
   81098:	38401783 	ldrb	w3, [x28], #1
   8109c:	35fff7c3 	cbnz	w3, 80f94 <tfp_format+0xa4>
   810a0:	34000080 	cbz	w0, 810b0 <tfp_format+0x1c0>
   810a4:	394223e0 	ldrb	w0, [sp, #136]
   810a8:	321d0000 	orr	w0, w0, #0x8
   810ac:	390223e0 	strb	w0, [sp, #136]
   810b0:	34fffe41 	cbz	w1, 81078 <tfp_format+0x188>
   810b4:	394223e0 	ldrb	w0, [sp, #136]
}
   810b8:	a94153f3 	ldp	x19, x20, [sp, #16]
   810bc:	32000000 	orr	w0, w0, #0x1
   810c0:	390223e0 	strb	w0, [sp, #136]
   810c4:	a9425bf5 	ldp	x21, x22, [sp, #32]
   810c8:	a94363f7 	ldp	x23, x24, [sp, #48]
   810cc:	a9446bf9 	ldp	x25, x26, [sp, #64]
   810d0:	a94573fb 	ldp	x27, x28, [sp, #80]
   810d4:	a8ca7bfd 	ldp	x29, x30, [sp], #160
   810d8:	d65f03c0 	ret
                    p.lz = 1;
   810dc:	52800021 	mov	w1, #0x1                   	// #1
   810e0:	17ffffee 	b	81098 <tfp_format+0x1a8>
            switch (ch) {
   810e4:	7101e07f 	cmp	w3, #0x78
   810e8:	54000f61 	b.ne	812d4 <tfp_format+0x3e4>  // b.any
                p.uc = (ch == 'X')?1:0;
   810ec:	7101607f 	cmp	w3, #0x58
   810f0:	394223e1 	ldrb	w1, [sp, #136]
   810f4:	1a9f17e2 	cset	w2, eq  // eq = none
                p.base = 16;
   810f8:	52800203 	mov	w3, #0x10                  	// #16
   810fc:	b90097e3 	str	w3, [sp, #148]
                if (2 == lng)
   81100:	7100081f 	cmp	w0, #0x2
                p.uc = (ch == 'X')?1:0;
   81104:	331e0041 	bfi	w1, w2, #2, #1
   81108:	390223e1 	strb	w1, [sp, #136]
                if (2 == lng)
   8110c:	54fff961 	b.ne	81038 <tfp_format+0x148>  // b.any
                    ulli2a(va_arg(va, unsigned long long int), &p);
   81110:	37f81836 	tbnz	w22, #31, 81414 <tfp_format+0x524>
   81114:	91003ea1 	add	x1, x21, #0xf
   81118:	aa1503e0 	mov	x0, x21
   8111c:	927df035 	and	x21, x1, #0xfffffffffffffff8
   81120:	f9400000 	ldr	x0, [x0]
   81124:	aa1703e1 	mov	x1, x23
   81128:	97fffe50 	bl	80a68 <ulli2a>
   8112c:	17ffffcc 	b	8105c <tfp_format+0x16c>
            switch (ch) {
   81130:	7101bc7f 	cmp	w3, #0x6f
   81134:	54000d40 	b.eq	812dc <tfp_format+0x3ec>  // b.none
   81138:	7101c07f 	cmp	w3, #0x70
   8113c:	54000cc1 	b.ne	812d4 <tfp_format+0x3e4>  // b.any
                p.alt = 1;
   81140:	394223e0 	ldrb	w0, [sp, #136]
                p.base = 16;
   81144:	52800201 	mov	w1, #0x10                  	// #16
   81148:	b90097e1 	str	w1, [sp, #148]
                p.alt = 1;
   8114c:	121d7400 	and	w0, w0, #0xfffffff9
   81150:	321f0000 	orr	w0, w0, #0x2
   81154:	390223e0 	strb	w0, [sp, #136]
                    uli2a(va_arg(va, unsigned long int), &p);
   81158:	37f81476 	tbnz	w22, #31, 813e4 <tfp_format+0x4f4>
   8115c:	91003ea1 	add	x1, x21, #0xf
   81160:	aa1503e0 	mov	x0, x21
   81164:	927df035 	and	x21, x1, #0xfffffffffffffff8
   81168:	f9400000 	ldr	x0, [x0]
   8116c:	aa1703e1 	mov	x1, x23
   81170:	97fffe72 	bl	80b38 <uli2a>
   81174:	17ffffba 	b	8105c <tfp_format+0x16c>
                switch (ch) {
   81178:	52800020 	mov	w0, #0x1                   	// #1
   8117c:	17ffffc7 	b	81098 <tfp_format+0x1a8>
            switch (ch) {
   81180:	7101607f 	cmp	w3, #0x58
   81184:	54fffb40 	b.eq	810ec <tfp_format+0x1fc>  // b.none
   81188:	54000128 	b.hi	811ac <tfp_format+0x2bc>  // b.pmore
   8118c:	34fff763 	cbz	w3, 81078 <tfp_format+0x188>
   81190:	7100947f 	cmp	w3, #0x25
   81194:	54000a01 	b.ne	812d4 <tfp_format+0x3e4>  // b.any
                putf(putp, ch);
   81198:	9100079b 	add	x27, x28, #0x1
   8119c:	2a0303e1 	mov	w1, w3
   811a0:	aa1303e0 	mov	x0, x19
   811a4:	d63f0280 	blr	x20
   811a8:	17ffff6c 	b	80f58 <tfp_format+0x68>
            switch (ch) {
   811ac:	71018c7f 	cmp	w3, #0x63
   811b0:	54000141 	b.ne	811d8 <tfp_format+0x2e8>  // b.any
                putf(putp, (char)(va_arg(va, int)));
   811b4:	37f80cd6 	tbnz	w22, #31, 8134c <tfp_format+0x45c>
   811b8:	91002ea1 	add	x1, x21, #0xb
   811bc:	aa1503e0 	mov	x0, x21
   811c0:	927df035 	and	x21, x1, #0xfffffffffffffff8
   811c4:	39400001 	ldrb	w1, [x0]
   811c8:	9100079b 	add	x27, x28, #0x1
   811cc:	aa1303e0 	mov	x0, x19
   811d0:	d63f0280 	blr	x20
                break;
   811d4:	17ffff61 	b	80f58 <tfp_format+0x68>
            switch (ch) {
   811d8:	7101907f 	cmp	w3, #0x64
   811dc:	540007c1 	b.ne	812d4 <tfp_format+0x3e4>  // b.any
                p.base = 10;
   811e0:	b90097fa 	str	w26, [sp, #148]
                if (2 == lng)
   811e4:	7100081f 	cmp	w0, #0x2
   811e8:	54001261 	b.ne	81434 <tfp_format+0x544>  // b.any
                    lli2a(va_arg(va, long long int), &p);
   811ec:	37f81456 	tbnz	w22, #31, 81474 <tfp_format+0x584>
   811f0:	91003ea1 	add	x1, x21, #0xf
   811f4:	aa1503e0 	mov	x0, x21
   811f8:	927df035 	and	x21, x1, #0xfffffffffffffff8
   811fc:	f9400000 	ldr	x0, [x0]
    if (num < 0) {
   81200:	b6fff920 	tbz	x0, #63, 81124 <tfp_format+0x234>
        p->sign = '-';
   81204:	528005a1 	mov	w1, #0x2d                  	// #45
        num = -num;
   81208:	cb0003e0 	neg	x0, x0
        p->sign = '-';
   8120c:	390243e1 	strb	w1, [sp, #144]
    ulli2a(num, p);
   81210:	17ffffc5 	b	81124 <tfp_format+0x234>
                ch = *(fmt++);
   81214:	38401783 	ldrb	w3, [x28], #1
            switch (ch) {
   81218:	7101a47f 	cmp	w3, #0x69
   8121c:	54001440 	b.eq	814a4 <tfp_format+0x5b4>  // b.none
   81220:	52800020 	mov	w0, #0x1                   	// #1
   81224:	17ffff7b 	b	81010 <tfp_format+0x120>
    unsigned int num = 0;
   81228:	52800002 	mov	w2, #0x0                   	// #0
   8122c:	1400000b 	b	81258 <tfp_format+0x368>
    else if (ch >= 'a' && ch <= 'f')
   81230:	7100141f 	cmp	w0, #0x5
   81234:	54000269 	b.ls	81280 <tfp_format+0x390>  // b.plast
    else if (ch >= 'A' && ch <= 'F')
   81238:	7100143f 	cmp	w1, #0x5
   8123c:	54000288 	b.hi	8128c <tfp_format+0x39c>  // b.pmore
        if (digit > base)
   81240:	710028bf 	cmp	w5, #0xa
   81244:	54000241 	b.ne	8128c <tfp_format+0x39c>  // b.any
        ch = *p++;
   81248:	38401783 	ldrb	w3, [x28], #1
        num = num * base + digit;
   8124c:	0b020842 	add	w2, w2, w2, lsl #2
   81250:	5100c066 	sub	w6, w3, #0x30
   81254:	0b0204a2 	add	w2, w5, w2, lsl #1
    else if (ch >= 'a' && ch <= 'f')
   81258:	51018460 	sub	w0, w3, #0x61
    else if (ch >= 'A' && ch <= 'F')
   8125c:	51010461 	sub	w1, w3, #0x41
    if (ch >= '0' && ch <= '9')
   81260:	12001cc4 	and	w4, w6, #0xff
        return ch - 'A' + 10;
   81264:	5100dc65 	sub	w5, w3, #0x37
    else if (ch >= 'a' && ch <= 'f')
   81268:	12001c00 	and	w0, w0, #0xff
    else if (ch >= 'A' && ch <= 'F')
   8126c:	12001c21 	and	w1, w1, #0xff
    if (ch >= '0' && ch <= '9')
   81270:	7100249f 	cmp	w4, #0x9
   81274:	54fffde8 	b.hi	81230 <tfp_format+0x340>  // b.pmore
        return ch - '0';
   81278:	2a0603e5 	mov	w5, w6
        if (digit > base)
   8127c:	17fffff3 	b	81248 <tfp_format+0x358>
        return ch - 'a' + 10;
   81280:	51015c65 	sub	w5, w3, #0x57
        if (digit > base)
   81284:	710028bf 	cmp	w5, #0xa
   81288:	54fffe00 	b.eq	81248 <tfp_format+0x358>  // b.none
    *nump = num;
   8128c:	b9008fe2 	str	w2, [sp, #140]
            if (ch == '.') {
   81290:	7100b87f 	cmp	w3, #0x2e
   81294:	54ffeb01 	b.ne	80ff4 <tfp_format+0x104>  // b.any
              p.lz = 1;  /* zero-padding */
   81298:	394223e0 	ldrb	w0, [sp, #136]
   8129c:	32000000 	orr	w0, w0, #0x1
   812a0:	390223e0 	strb	w0, [sp, #136]
   812a4:	d503201f 	nop
                ch = *(fmt++);
   812a8:	38401783 	ldrb	w3, [x28], #1
              } while ((ch >= '0') && (ch <= '9'));
   812ac:	5100c060 	sub	w0, w3, #0x30
   812b0:	12001c00 	and	w0, w0, #0xff
   812b4:	7100241f 	cmp	w0, #0x9
   812b8:	54ffff89 	b.ls	812a8 <tfp_format+0x3b8>  // b.plast
   812bc:	17ffff4e 	b	80ff4 <tfp_format+0x104>
                ch = *(fmt++);
   812c0:	39400383 	ldrb	w3, [x28]
                if (ch == 'l') {
   812c4:	7101b07f 	cmp	w3, #0x6c
   812c8:	54000720 	b.eq	813ac <tfp_format+0x4bc>  // b.none
                ch = *(fmt++);
   812cc:	9100079c 	add	x28, x28, #0x1
   812d0:	17ffffd2 	b	81218 <tfp_format+0x328>
   812d4:	9100079b 	add	x27, x28, #0x1
   812d8:	17ffff20 	b	80f58 <tfp_format+0x68>
                p.base = 8;
   812dc:	52800100 	mov	w0, #0x8                   	// #8
   812e0:	b90097e0 	str	w0, [sp, #148]
                ui2a(va_arg(va, unsigned int), &p);
   812e4:	37f80456 	tbnz	w22, #31, 8136c <tfp_format+0x47c>
   812e8:	91002ea1 	add	x1, x21, #0xb
   812ec:	aa1503e0 	mov	x0, x21
   812f0:	927df035 	and	x21, x1, #0xfffffffffffffff8
   812f4:	b9400000 	ldr	w0, [x0]
   812f8:	aa1703e1 	mov	x1, x23
   812fc:	9100079b 	add	x27, x28, #0x1
   81300:	97fffe42 	bl	80c08 <ui2a>
                putchw(putp, putf, &p);
   81304:	aa1703e2 	mov	x2, x23
   81308:	aa1403e1 	mov	x1, x20
   8130c:	aa1303e0 	mov	x0, x19
   81310:	97fffe70 	bl	80cd0 <putchw>
                break;
   81314:	17ffff11 	b	80f58 <tfp_format+0x68>
                p.bf = va_arg(va, char *);
   81318:	37f803b6 	tbnz	w22, #31, 8138c <tfp_format+0x49c>
   8131c:	91003ea1 	add	x1, x21, #0xf
   81320:	aa1503e0 	mov	x0, x21
   81324:	927df035 	and	x21, x1, #0xfffffffffffffff8
   81328:	f9400003 	ldr	x3, [x0]
                putchw(putp, putf, &p);
   8132c:	aa1703e2 	mov	x2, x23
   81330:	aa1403e1 	mov	x1, x20
   81334:	aa1303e0 	mov	x0, x19
   81338:	9100079b 	add	x27, x28, #0x1
                p.bf = va_arg(va, char *);
   8133c:	f9004fe3 	str	x3, [sp, #152]
                putchw(putp, putf, &p);
   81340:	97fffe64 	bl	80cd0 <putchw>
                p.bf = bf;
   81344:	f9004ff9 	str	x25, [sp, #152]
                break;
   81348:	17ffff04 	b	80f58 <tfp_format+0x68>
                putf(putp, (char)(va_arg(va, int)));
   8134c:	110022c1 	add	w1, w22, #0x8
   81350:	7100003f 	cmp	w1, #0x0
   81354:	54000d2d 	b.le	814f8 <tfp_format+0x608>
   81358:	91002ea2 	add	x2, x21, #0xb
   8135c:	aa1503e0 	mov	x0, x21
   81360:	2a0103f6 	mov	w22, w1
   81364:	927df055 	and	x21, x2, #0xfffffffffffffff8
   81368:	17ffff97 	b	811c4 <tfp_format+0x2d4>
                ui2a(va_arg(va, unsigned int), &p);
   8136c:	110022c1 	add	w1, w22, #0x8
   81370:	7100003f 	cmp	w1, #0x0
   81374:	54000d2d 	b.le	81518 <tfp_format+0x628>
   81378:	91002ea2 	add	x2, x21, #0xb
   8137c:	aa1503e0 	mov	x0, x21
   81380:	2a0103f6 	mov	w22, w1
   81384:	927df055 	and	x21, x2, #0xfffffffffffffff8
   81388:	17ffffdb 	b	812f4 <tfp_format+0x404>
                p.bf = va_arg(va, char *);
   8138c:	110022c1 	add	w1, w22, #0x8
   81390:	7100003f 	cmp	w1, #0x0
   81394:	54000bad 	b.le	81508 <tfp_format+0x618>
   81398:	91003ea2 	add	x2, x21, #0xf
   8139c:	aa1503e0 	mov	x0, x21
   813a0:	2a0103f6 	mov	w22, w1
   813a4:	927df055 	and	x21, x2, #0xfffffffffffffff8
   813a8:	17ffffe0 	b	81328 <tfp_format+0x438>
                  ch = *(fmt++);
   813ac:	39400783 	ldrb	w3, [x28, #1]
   813b0:	91000b9c 	add	x28, x28, #0x2
            switch (ch) {
   813b4:	7101a47f 	cmp	w3, #0x69
   813b8:	54000d80 	b.eq	81568 <tfp_format+0x678>  // b.none
                  lng = 2;
   813bc:	52800040 	mov	w0, #0x2                   	// #2
   813c0:	17ffff14 	b	81010 <tfp_format+0x120>
                    ui2a(va_arg(va, unsigned int), &p);
   813c4:	110022c1 	add	w1, w22, #0x8
   813c8:	7100003f 	cmp	w1, #0x0
   813cc:	540001cd 	b.le	81404 <tfp_format+0x514>
   813d0:	91002ea2 	add	x2, x21, #0xb
   813d4:	aa1503e0 	mov	x0, x21
   813d8:	2a0103f6 	mov	w22, w1
   813dc:	927df055 	and	x21, x2, #0xfffffffffffffff8
   813e0:	17ffff1c 	b	81050 <tfp_format+0x160>
                    uli2a(va_arg(va, unsigned long int), &p);
   813e4:	110022c1 	add	w1, w22, #0x8
   813e8:	7100003f 	cmp	w1, #0x0
   813ec:	540003cd 	b.le	81464 <tfp_format+0x574>
   813f0:	91003ea2 	add	x2, x21, #0xf
   813f4:	aa1503e0 	mov	x0, x21
   813f8:	2a0103f6 	mov	w22, w1
   813fc:	927df055 	and	x21, x2, #0xfffffffffffffff8
   81400:	17ffff5a 	b	81168 <tfp_format+0x278>
                    ui2a(va_arg(va, unsigned int), &p);
   81404:	f94037e0 	ldr	x0, [sp, #104]
   81408:	8b36c000 	add	x0, x0, w22, sxtw
   8140c:	2a0103f6 	mov	w22, w1
   81410:	17ffff10 	b	81050 <tfp_format+0x160>
                    ulli2a(va_arg(va, unsigned long long int), &p);
   81414:	110022c1 	add	w1, w22, #0x8
   81418:	7100003f 	cmp	w1, #0x0
   8141c:	540003cd 	b.le	81494 <tfp_format+0x5a4>
   81420:	91003ea2 	add	x2, x21, #0xf
   81424:	aa1503e0 	mov	x0, x21
   81428:	2a0103f6 	mov	w22, w1
   8142c:	927df055 	and	x21, x2, #0xfffffffffffffff8
   81430:	17ffff3c 	b	81120 <tfp_format+0x230>
                  if (1 == lng)
   81434:	7100041f 	cmp	w0, #0x1
   81438:	54000380 	b.eq	814a8 <tfp_format+0x5b8>  // b.none
                    i2a(va_arg(va, int), &p);
   8143c:	37f804f6 	tbnz	w22, #31, 814d8 <tfp_format+0x5e8>
   81440:	91002ea1 	add	x1, x21, #0xb
   81444:	aa1503e0 	mov	x0, x21
   81448:	927df035 	and	x21, x1, #0xfffffffffffffff8
   8144c:	b9400000 	ldr	w0, [x0]
    if (num < 0) {
   81450:	36ffe020 	tbz	w0, #31, 81054 <tfp_format+0x164>
        p->sign = '-';
   81454:	528005a1 	mov	w1, #0x2d                  	// #45
        num = -num;
   81458:	4b0003e0 	neg	w0, w0
        p->sign = '-';
   8145c:	390243e1 	strb	w1, [sp, #144]
    ui2a(num, p);
   81460:	17fffefd 	b	81054 <tfp_format+0x164>
                    uli2a(va_arg(va, unsigned long int), &p);
   81464:	f94037e0 	ldr	x0, [sp, #104]
   81468:	8b36c000 	add	x0, x0, w22, sxtw
   8146c:	2a0103f6 	mov	w22, w1
   81470:	17ffff3e 	b	81168 <tfp_format+0x278>
                    lli2a(va_arg(va, long long int), &p);
   81474:	110022c1 	add	w1, w22, #0x8
   81478:	7100003f 	cmp	w1, #0x0
   8147c:	540006ed 	b.le	81558 <tfp_format+0x668>
   81480:	91003ea2 	add	x2, x21, #0xf
   81484:	aa1503e0 	mov	x0, x21
   81488:	2a0103f6 	mov	w22, w1
   8148c:	927df055 	and	x21, x2, #0xfffffffffffffff8
   81490:	17ffff5b 	b	811fc <tfp_format+0x30c>
                    ulli2a(va_arg(va, unsigned long long int), &p);
   81494:	f94037e0 	ldr	x0, [sp, #104]
   81498:	8b36c000 	add	x0, x0, w22, sxtw
   8149c:	2a0103f6 	mov	w22, w1
   814a0:	17ffff20 	b	81120 <tfp_format+0x230>
                p.base = 10;
   814a4:	b90097fa 	str	w26, [sp, #148]
                    li2a(va_arg(va, long int), &p);
   814a8:	37f80416 	tbnz	w22, #31, 81528 <tfp_format+0x638>
   814ac:	91003ea1 	add	x1, x21, #0xf
   814b0:	aa1503e0 	mov	x0, x21
   814b4:	927df035 	and	x21, x1, #0xfffffffffffffff8
   814b8:	f9400000 	ldr	x0, [x0]
    if (num < 0) {
   814bc:	b6ffe580 	tbz	x0, #63, 8116c <tfp_format+0x27c>
        p->sign = '-';
   814c0:	528005a1 	mov	w1, #0x2d                  	// #45
        num = -num;
   814c4:	cb0003e0 	neg	x0, x0
        p->sign = '-';
   814c8:	390243e1 	strb	w1, [sp, #144]
    uli2a(num, p);
   814cc:	17ffff28 	b	8116c <tfp_format+0x27c>
                p.base = 10;
   814d0:	b90097fa 	str	w26, [sp, #148]
                if (2 == lng)
   814d4:	17ffffda 	b	8143c <tfp_format+0x54c>
                    i2a(va_arg(va, int), &p);
   814d8:	110022c1 	add	w1, w22, #0x8
   814dc:	7100003f 	cmp	w1, #0x0
   814e0:	5400034d 	b.le	81548 <tfp_format+0x658>
   814e4:	91002ea2 	add	x2, x21, #0xb
   814e8:	aa1503e0 	mov	x0, x21
   814ec:	2a0103f6 	mov	w22, w1
   814f0:	927df055 	and	x21, x2, #0xfffffffffffffff8
   814f4:	17ffffd6 	b	8144c <tfp_format+0x55c>
                putf(putp, (char)(va_arg(va, int)));
   814f8:	f94037e0 	ldr	x0, [sp, #104]
   814fc:	8b36c000 	add	x0, x0, w22, sxtw
   81500:	2a0103f6 	mov	w22, w1
   81504:	17ffff30 	b	811c4 <tfp_format+0x2d4>
                p.bf = va_arg(va, char *);
   81508:	f94037e0 	ldr	x0, [sp, #104]
   8150c:	8b36c000 	add	x0, x0, w22, sxtw
   81510:	2a0103f6 	mov	w22, w1
   81514:	17ffff85 	b	81328 <tfp_format+0x438>
                ui2a(va_arg(va, unsigned int), &p);
   81518:	f94037e0 	ldr	x0, [sp, #104]
   8151c:	8b36c000 	add	x0, x0, w22, sxtw
   81520:	2a0103f6 	mov	w22, w1
   81524:	17ffff74 	b	812f4 <tfp_format+0x404>
                    li2a(va_arg(va, long int), &p);
   81528:	110022c1 	add	w1, w22, #0x8
   8152c:	7100003f 	cmp	w1, #0x0
   81530:	5400022d 	b.le	81574 <tfp_format+0x684>
   81534:	91003ea2 	add	x2, x21, #0xf
   81538:	aa1503e0 	mov	x0, x21
   8153c:	2a0103f6 	mov	w22, w1
   81540:	927df055 	and	x21, x2, #0xfffffffffffffff8
   81544:	17ffffdd 	b	814b8 <tfp_format+0x5c8>
                    i2a(va_arg(va, int), &p);
   81548:	f94037e0 	ldr	x0, [sp, #104]
   8154c:	8b36c000 	add	x0, x0, w22, sxtw
   81550:	2a0103f6 	mov	w22, w1
   81554:	17ffffbe 	b	8144c <tfp_format+0x55c>
                    lli2a(va_arg(va, long long int), &p);
   81558:	f94037e0 	ldr	x0, [sp, #104]
   8155c:	8b36c000 	add	x0, x0, w22, sxtw
   81560:	2a0103f6 	mov	w22, w1
   81564:	17ffff26 	b	811fc <tfp_format+0x30c>
                p.base = 10;
   81568:	b90097fa 	str	w26, [sp, #148]
                    lli2a(va_arg(va, long long int), &p);
   8156c:	36ffe436 	tbz	w22, #31, 811f0 <tfp_format+0x300>
   81570:	17ffffc1 	b	81474 <tfp_format+0x584>
                    li2a(va_arg(va, long int), &p);
   81574:	f94037e0 	ldr	x0, [sp, #104]
   81578:	8b36c000 	add	x0, x0, w22, sxtw
   8157c:	2a0103f6 	mov	w22, w1
   81580:	17ffffce 	b	814b8 <tfp_format+0x5c8>
   81584:	d503201f 	nop

0000000000081588 <init_printf>:
    stdout_putf = putf;
   81588:	f0000082 	adrp	x2, 94000 <_binary_font_psf_start+0x634>
   8158c:	910c8043 	add	x3, x2, #0x320
   81590:	f9019041 	str	x1, [x2, #800]
    stdout_putp = putp;
   81594:	f9000460 	str	x0, [x3, #8]
}
   81598:	d65f03c0 	ret
   8159c:	d503201f 	nop

00000000000815a0 <tfp_printf>:
{
   815a0:	a9b77bfd 	stp	x29, x30, [sp, #-144]!
    tfp_format(stdout_putp, stdout_putf, fmt, va);
   815a4:	f0000088 	adrp	x8, 94000 <_binary_font_psf_start+0x634>
   815a8:	910c810b 	add	x11, x8, #0x320
{
   815ac:	910003fd 	mov	x29, sp
   815b0:	f9002fe1 	str	x1, [sp, #88]
   815b4:	aa0003ea 	mov	x10, x0
    tfp_format(stdout_putp, stdout_putf, fmt, va);
   815b8:	f9419101 	ldr	x1, [x8, #800]
    va_start(va, fmt);
   815bc:	910143e9 	add	x9, sp, #0x50
    tfp_format(stdout_putp, stdout_putf, fmt, va);
   815c0:	f9400560 	ldr	x0, [x11, #8]
    va_start(va, fmt);
   815c4:	910243eb 	add	x11, sp, #0x90
   815c8:	a9032feb 	stp	x11, x11, [sp, #48]
   815cc:	128006e8 	mov	w8, #0xffffffc8            	// #-56
   815d0:	f90023e9 	str	x9, [sp, #64]
   815d4:	b9004be8 	str	w8, [sp, #72]
   815d8:	b9004fff 	str	wzr, [sp, #76]
    tfp_format(stdout_putp, stdout_putf, fmt, va);
   815dc:	a94327e8 	ldp	x8, x9, [sp, #48]
   815e0:	a90127e8 	stp	x8, x9, [sp, #16]
   815e4:	a94427e8 	ldp	x8, x9, [sp, #64]
   815e8:	a90227e8 	stp	x8, x9, [sp, #32]
{
   815ec:	a9060fe2 	stp	x2, x3, [sp, #96]
    tfp_format(stdout_putp, stdout_putf, fmt, va);
   815f0:	910043e3 	add	x3, sp, #0x10
   815f4:	aa0a03e2 	mov	x2, x10
{
   815f8:	a90717e4 	stp	x4, x5, [sp, #112]
   815fc:	a9081fe6 	stp	x6, x7, [sp, #128]
    tfp_format(stdout_putp, stdout_putf, fmt, va);
   81600:	97fffe3c 	bl	80ef0 <tfp_format>
}
   81604:	a8c97bfd 	ldp	x29, x30, [sp], #144
   81608:	d65f03c0 	ret
   8160c:	d503201f 	nop

0000000000081610 <tfp_vsnprintf>:
  if (size < 1)
   81610:	b5000061 	cbnz	x1, 8161c <tfp_vsnprintf+0xc>
    return 0;
   81614:	52800000 	mov	w0, #0x0                   	// #0
}
   81618:	d65f03c0 	ret
{
   8161c:	a9bb7bfd 	stp	x29, x30, [sp, #-80]!
   81620:	aa0003e5 	mov	x5, x0
  data.dest_capacity = size-1;
   81624:	d1000424 	sub	x4, x1, #0x1
{
   81628:	910003fd 	mov	x29, sp
  tfp_format(&data, _vsnprintf_putcf, format, ap);
   8162c:	a9402468 	ldp	x8, x9, [x3]
   81630:	9100e3e0 	add	x0, sp, #0x38
   81634:	a9411c66 	ldp	x6, x7, [x3, #16]
   81638:	f0ffffe1 	adrp	x1, 80000 <_start>
   8163c:	910043e3 	add	x3, sp, #0x10
   81640:	913aa021 	add	x1, x1, #0xea8
   81644:	a90127e8 	stp	x8, x9, [sp, #16]
   81648:	a9021fe6 	stp	x6, x7, [sp, #32]
  data.dest = str;
   8164c:	a90397e4 	stp	x4, x5, [sp, #56]
  data.num_chars = 0;
   81650:	f90027ff 	str	xzr, [sp, #72]
  tfp_format(&data, _vsnprintf_putcf, format, ap);
   81654:	97fffe27 	bl	80ef0 <tfp_format>
  if (data.num_chars < data.dest_capacity)
   81658:	f9401fe0 	ldr	x0, [sp, #56]
   8165c:	f94027e1 	ldr	x1, [sp, #72]
   81660:	eb00003f 	cmp	x1, x0
   81664:	540000c2 	b.cs	8167c <tfp_vsnprintf+0x6c>  // b.hs, b.nlast
    data.dest[data.num_chars] = '\0';
   81668:	f94023e0 	ldr	x0, [sp, #64]
   8166c:	3821681f 	strb	wzr, [x0, x1]
  return data.num_chars;
   81670:	b9404be0 	ldr	w0, [sp, #72]
}
   81674:	a8c57bfd 	ldp	x29, x30, [sp], #80
   81678:	d65f03c0 	ret
    data.dest[data.dest_capacity] = '\0';
   8167c:	f94023e1 	ldr	x1, [sp, #64]
   81680:	3820683f 	strb	wzr, [x1, x0]
  return data.num_chars;
   81684:	b9404be0 	ldr	w0, [sp, #72]
}
   81688:	a8c57bfd 	ldp	x29, x30, [sp], #80
   8168c:	d65f03c0 	ret

0000000000081690 <tfp_snprintf>:
{
   81690:	a9b87bfd 	stp	x29, x30, [sp, #-128]!
  va_start(ap, format);
   81694:	128004e8 	mov	w8, #0xffffffd8            	// #-40
{
   81698:	910003fd 	mov	x29, sp
  va_start(ap, format);
   8169c:	910203ea 	add	x10, sp, #0x80
   816a0:	a9032bea 	stp	x10, x10, [sp, #48]
   816a4:	910143e9 	add	x9, sp, #0x50
   816a8:	f90023e9 	str	x9, [sp, #64]
   816ac:	29097fe8 	stp	w8, wzr, [sp, #72]
  retval = tfp_vsnprintf(str, size, format, ap);
   816b0:	a94327e8 	ldp	x8, x9, [sp, #48]
   816b4:	a90127e8 	stp	x8, x9, [sp, #16]
   816b8:	a94427e8 	ldp	x8, x9, [sp, #64]
   816bc:	a90227e8 	stp	x8, x9, [sp, #32]
{
   816c0:	a90593e3 	stp	x3, x4, [sp, #88]
  retval = tfp_vsnprintf(str, size, format, ap);
   816c4:	910043e3 	add	x3, sp, #0x10
{
   816c8:	a9069be5 	stp	x5, x6, [sp, #104]
   816cc:	f9003fe7 	str	x7, [sp, #120]
  retval = tfp_vsnprintf(str, size, format, ap);
   816d0:	97ffffd0 	bl	81610 <tfp_vsnprintf>
}
   816d4:	a8c87bfd 	ldp	x29, x30, [sp], #128
   816d8:	d65f03c0 	ret
   816dc:	d503201f 	nop

00000000000816e0 <tfp_vsprintf>:

int tfp_vsprintf(char *str, const char *format, va_list ap)
{
   816e0:	aa0203e4 	mov	x4, x2
   816e4:	a9bc7bfd 	stp	x29, x30, [sp, #-64]!
   816e8:	aa0003e5 	mov	x5, x0
   816ec:	910003fd 	mov	x29, sp
  struct _vsprintf_putcf_data data;
  data.dest = str;
  data.num_chars = 0;
  tfp_format(&data, _vsprintf_putcf, format, ap);
   816f0:	a9402488 	ldp	x8, x9, [x4]
   816f4:	aa0103e2 	mov	x2, x1
   816f8:	a9411c86 	ldp	x6, x7, [x4, #16]
   816fc:	910043e3 	add	x3, sp, #0x10
   81700:	9100c3e0 	add	x0, sp, #0x30
   81704:	f0ffffe1 	adrp	x1, 80000 <_start>
   81708:	913b6021 	add	x1, x1, #0xed8
   8170c:	a90127e8 	stp	x8, x9, [sp, #16]
   81710:	a9021fe6 	stp	x6, x7, [sp, #32]
  data.num_chars = 0;
   81714:	a9037fe5 	stp	x5, xzr, [sp, #48]
  tfp_format(&data, _vsprintf_putcf, format, ap);
   81718:	97fffdf6 	bl	80ef0 <tfp_format>
  data.dest[data.num_chars] = '\0';
   8171c:	a94303e1 	ldp	x1, x0, [sp, #48]
   81720:	3820683f 	strb	wzr, [x1, x0]
  return data.num_chars;
}
   81724:	b9403be0 	ldr	w0, [sp, #56]
   81728:	a8c47bfd 	ldp	x29, x30, [sp], #64
   8172c:	d65f03c0 	ret

0000000000081730 <tfp_sprintf>:

int tfp_sprintf(char *str, const char *format, ...)
{
   81730:	a9b57bfd 	stp	x29, x30, [sp, #-176]!
  va_list ap;
  int retval;

  va_start(ap, format);
   81734:	128005e8 	mov	w8, #0xffffffd0            	// #-48
{
   81738:	aa0103ec 	mov	x12, x1
   8173c:	910003fd 	mov	x29, sp
  va_start(ap, format);
   81740:	910203e9 	add	x9, sp, #0x80
   81744:	9102c3ea 	add	x10, sp, #0xb0
   81748:	a9042bea 	stp	x10, x10, [sp, #64]
{
   8174c:	aa0003ed 	mov	x13, x0
  tfp_format(&data, _vsprintf_putcf, format, ap);
   81750:	f0ffffe1 	adrp	x1, 80000 <_start>
  va_start(ap, format);
   81754:	f9002be9 	str	x9, [sp, #80]
  tfp_format(&data, _vsprintf_putcf, format, ap);
   81758:	9100c3e0 	add	x0, sp, #0x30
  va_start(ap, format);
   8175c:	290b7fe8 	stp	w8, wzr, [sp, #88]
  tfp_format(&data, _vsprintf_putcf, format, ap);
   81760:	913b6021 	add	x1, x1, #0xed8
   81764:	a9442fea 	ldp	x10, x11, [sp, #64]
   81768:	a9012fea 	stp	x10, x11, [sp, #16]
   8176c:	a94527e8 	ldp	x8, x9, [sp, #80]
   81770:	a90227e8 	stp	x8, x9, [sp, #32]
  data.num_chars = 0;
   81774:	a9037fed 	stp	x13, xzr, [sp, #48]
   81778:	a9062fea 	stp	x10, x11, [sp, #96]
   8177c:	a90727e8 	stp	x8, x9, [sp, #112]
{
   81780:	a9080fe2 	stp	x2, x3, [sp, #128]
  tfp_format(&data, _vsprintf_putcf, format, ap);
   81784:	910043e3 	add	x3, sp, #0x10
   81788:	aa0c03e2 	mov	x2, x12
{
   8178c:	a90917e4 	stp	x4, x5, [sp, #144]
   81790:	a90a1fe6 	stp	x6, x7, [sp, #160]
  tfp_format(&data, _vsprintf_putcf, format, ap);
   81794:	97fffdd7 	bl	80ef0 <tfp_format>
  data.dest[data.num_chars] = '\0';
   81798:	a94303e1 	ldp	x1, x0, [sp, #48]
   8179c:	3820683f 	strb	wzr, [x1, x0]
  retval = tfp_vsprintf(str, format, ap);
  va_end(ap);
  return retval;
}
   817a0:	b9403be0 	ldr	w0, [sp, #56]
   817a4:	a8cb7bfd 	ldp	x29, x30, [sp], #176
   817a8:	d65f03c0 	ret
   817ac:	d503201f 	nop

00000000000817b0 <panic>:
#endif

// xv6
void panic(char *s)
{
   817b0:	a9be7bfd 	stp	x29, x30, [sp, #-32]!
  printf("panic: ");
   817b4:	90000022 	adrp	x2, 85000 <get_el+0x198>
{
   817b8:	910003fd 	mov	x29, sp
   817bc:	f9000bf3 	str	x19, [sp, #16]
   817c0:	aa0003f3 	mov	x19, x0
  printf("panic: ");
   817c4:	91064040 	add	x0, x2, #0x190
   817c8:	97ffff76 	bl	815a0 <tfp_printf>
  printf("%s\n", s);
   817cc:	aa1303e1 	mov	x1, x19
   817d0:	90000020 	adrp	x0, 85000 <get_el+0x198>
   817d4:	91066000 	add	x0, x0, #0x198
   817d8:	97ffff72 	bl	815a0 <tfp_printf>
//   panicked = 1; // freeze uart output from other CPUs
    asm volatile("msr	daifset, #0b0010 "); // disable irq
   817dc:	d50342df 	msr	daifset, #0x2
  for(;;)
   817e0:	14000000 	b	817e0 <panic+0x30>
   817e4:	d503201f 	nop

00000000000817e8 <debug_hexdump>:
}

// circle debug.cpp
// will dump at least 16 bytes....
void debug_hexdump (const void *pStart, unsigned nBytes)
{
   817e8:	d10203ff 	sub	sp, sp, #0x80
	unsigned char *pOffset = (unsigned char *) pStart;
	
	printf("Dumping 0x%x bytes starting at 0x%lx\r\n", nBytes,
   817ec:	aa0003e2 	mov	x2, x0
{
   817f0:	a9057bfd 	stp	x29, x30, [sp, #80]
   817f4:	910143fd 	add	x29, sp, #0x50
   817f8:	a90653f3 	stp	x19, x20, [sp, #96]
   817fc:	aa0003f4 	mov	x20, x0
	printf("Dumping 0x%x bytes starting at 0x%lx\r\n", nBytes,
   81800:	90000020 	adrp	x0, 85000 <get_el+0x198>
   81804:	91068000 	add	x0, x0, #0x1a0
{
   81808:	a9075bf5 	stp	x21, x22, [sp, #112]
   8180c:	2a0103f5 	mov	w21, w1
	printf("Dumping 0x%x bytes starting at 0x%lx\r\n", nBytes,
   81810:	97ffff64 	bl	815a0 <tfp_printf>
				(unsigned long) pOffset);
	
	while (nBytes > 0)
   81814:	34000575 	cbz	w21, 818c0 <debug_hexdump+0xd8>
   81818:	927c6ea2 	and	x2, x21, #0xfffffff0
	unsigned char *pOffset = (unsigned char *) pStart;
   8181c:	aa1403f3 	mov	x19, x20
   81820:	91004042 	add	x2, x2, #0x10
	while (nBytes > 0)
   81824:	0b1402b5 	add	w21, w21, w20
   81828:	90000036 	adrp	x22, 85000 <get_el+0x198>
   8182c:	8b020294 	add	x20, x20, x2
	{
		printf(
   81830:	910722d6 	add	x22, x22, #0x1c8
   81834:	14000003 	b	81840 <debug_hexdump+0x58>
	while (nBytes > 0)
   81838:	6b1302bf 	cmp	w21, w19
   8183c:	54000420 	b.eq	818c0 <debug_hexdump+0xd8>  // b.none
		printf(
   81840:	39402e68 	ldrb	w8, [x19, #11]
   81844:	92403e61 	and	x1, x19, #0xffff
   81848:	39402a69 	ldrb	w9, [x19, #10]
   8184c:	aa1603e0 	mov	x0, x22
   81850:	3940266a 	ldrb	w10, [x19, #9]
				(unsigned) pOffset[0],  (unsigned) pOffset[1],  (unsigned) pOffset[2],  (unsigned) pOffset[3],
				(unsigned) pOffset[4],  (unsigned) pOffset[5],  (unsigned) pOffset[6],  (unsigned) pOffset[7],
				(unsigned) pOffset[8],  (unsigned) pOffset[9],  (unsigned) pOffset[10], (unsigned) pOffset[11],
				(unsigned) pOffset[12], (unsigned) pOffset[13], (unsigned) pOffset[14], (unsigned) pOffset[15]);

		pOffset += 16;
   81854:	91004273 	add	x19, x19, #0x10
		printf(
   81858:	385f826b 	ldurb	w11, [x19, #-8]
   8185c:	385f726c 	ldurb	w12, [x19, #-9]
   81860:	385f626d 	ldurb	w13, [x19, #-10]
   81864:	385f5267 	ldurb	w7, [x19, #-11]
   81868:	385f4266 	ldurb	w6, [x19, #-12]
   8186c:	385f3265 	ldurb	w5, [x19, #-13]
   81870:	385f2264 	ldurb	w4, [x19, #-14]
   81874:	385f1263 	ldurb	w3, [x19, #-15]
   81878:	385f0262 	ldurb	w2, [x19, #-16]
   8187c:	b90003ed 	str	w13, [sp]
   81880:	b9000bec 	str	w12, [sp, #8]
   81884:	b90013eb 	str	w11, [sp, #16]
   81888:	b9001bea 	str	w10, [sp, #24]
   8188c:	b90023e9 	str	w9, [sp, #32]
   81890:	b9002be8 	str	w8, [sp, #40]
   81894:	385ff268 	ldurb	w8, [x19, #-1]
   81898:	385fe269 	ldurb	w9, [x19, #-2]
   8189c:	385fd26a 	ldurb	w10, [x19, #-3]
   818a0:	385fc26b 	ldurb	w11, [x19, #-4]
   818a4:	b90033eb 	str	w11, [sp, #48]
   818a8:	b9003bea 	str	w10, [sp, #56]
   818ac:	b90043e9 	str	w9, [sp, #64]
   818b0:	b9004be8 	str	w8, [sp, #72]
   818b4:	97ffff3b 	bl	815a0 <tfp_printf>
		if (nBytes >= 16)
   818b8:	eb14027f 	cmp	x19, x20
   818bc:	54fffbe1 	b.ne	81838 <debug_hexdump+0x50>  // b.any
		else
		{
			nBytes = 0;
		}
	}
}
   818c0:	a9457bfd 	ldp	x29, x30, [sp, #80]
   818c4:	a94653f3 	ldp	x19, x20, [sp, #96]
   818c8:	a9475bf5 	ldp	x21, x22, [sp, #112]
   818cc:	910203ff 	add	sp, sp, #0x80
   818d0:	d65f03c0 	ret
   818d4:	d503201f 	nop

00000000000818d8 <assertion_failed>:

// circle assert.cpp        
void assertion_failed (const char *pExpr, const char *pFile, unsigned nLine) {
   818d8:	aa0103e4 	mov	x4, x1
   818dc:	a9bf7bfd 	stp	x29, x30, [sp, #-16]!
    printf("assertion failed: %s at %s:%u\n", pExpr, pFile, nLine); 
   818e0:	aa0003e1 	mov	x1, x0
   818e4:	2a0203e3 	mov	w3, w2
   818e8:	aa0403e2 	mov	x2, x4
void assertion_failed (const char *pExpr, const char *pFile, unsigned nLine) {
   818ec:	910003fd 	mov	x29, sp
    printf("assertion failed: %s at %s:%u\n", pExpr, pFile, nLine); 
   818f0:	90000020 	adrp	x0, 85000 <get_el+0x198>
   818f4:	9108a000 	add	x0, x0, #0x228
   818f8:	97ffff2a 	bl	815a0 <tfp_printf>
    panic("kernel hangs"); 
   818fc:	90000020 	adrp	x0, 85000 <get_el+0x198>
   81900:	91092000 	add	x0, x0, #0x248
   81904:	97ffffab 	bl	817b0 <panic>

0000000000081908 <memset>:

/* c: the fill value (byte); n: size, in bytes */
void *memset(void *dst, int c, uint n) {
    char *cdst = (char *)dst;
    int i;
    for (i = 0; i < n; i++) {
   81908:	34000122 	cbz	w2, 8192c <memset+0x24>
   8190c:	51000442 	sub	w2, w2, #0x1
   81910:	12001c23 	and	w3, w1, #0xff
   81914:	91000442 	add	x2, x2, #0x1
   81918:	aa0003e1 	mov	x1, x0
   8191c:	8b000042 	add	x2, x2, x0
        cdst[i] = c;
   81920:	38001423 	strb	w3, [x1], #1
    for (i = 0; i < n; i++) {
   81924:	eb02003f 	cmp	x1, x2
   81928:	54ffffc1 	b.ne	81920 <memset+0x18>  // b.any
    }
    return dst;
}
   8192c:	d65f03c0 	ret

0000000000081930 <memzero>:
    for (i = 0; i < n; i++) {
   81930:	34000101 	cbz	w1, 81950 <memzero+0x20>
   81934:	51000421 	sub	w1, w1, #0x1
   81938:	8b010002 	add	x2, x0, x1
   8193c:	d503201f 	nop
        cdst[i] = c;
   81940:	3900001f 	strb	wzr, [x0]
    for (i = 0; i < n; i++) {
   81944:	eb02001f 	cmp	x0, x2
   81948:	91000400 	add	x0, x0, #0x1
   8194c:	54ffffa1 	b.ne	81940 <memzero+0x10>  // b.any

void memzero(void *dst, uint n) {
    memset(dst, 0, n);
}
   81950:	d65f03c0 	ret
   81954:	d503201f 	nop

0000000000081958 <memcmp>:
int memcmp(const void *v1, const void *v2, uint n) {
    const uchar *s1, *s2;

    s1 = v1;
    s2 = v2;
    while (n-- > 0) {
   81958:	51000446 	sub	w6, w2, #0x1
   8195c:	340001a2 	cbz	w2, 81990 <memcmp+0x38>
   81960:	d2800002 	mov	x2, #0x0                   	// #0
   81964:	14000004 	b	81974 <memcmp+0x1c>
   81968:	eb0200df 	cmp	x6, x2
   8196c:	aa0503e2 	mov	x2, x5
   81970:	54000100 	b.eq	81990 <memcmp+0x38>  // b.none
        if (*s1 != *s2)
   81974:	38626803 	ldrb	w3, [x0, x2]
   81978:	91000445 	add	x5, x2, #0x1
   8197c:	38626824 	ldrb	w4, [x1, x2]
   81980:	6b04007f 	cmp	w3, w4
   81984:	54ffff20 	b.eq	81968 <memcmp+0x10>  // b.none
            return *s1 - *s2;
   81988:	4b040060 	sub	w0, w3, w4
        s1++, s2++;
    }

    return 0;
}
   8198c:	d65f03c0 	ret
    return 0;
   81990:	52800000 	mov	w0, #0x0                   	// #0
}
   81994:	d65f03c0 	ret

0000000000081998 <memmove>:
/* well handles dst/src overlap */
void *memmove(void *dst, const void *src, uint n) {
    const char *s;
    char *d;

    if (n == 0)
   81998:	34000162 	cbz	w2, 819c4 <memmove+0x2c>
        return dst;

    s = src;
    d = dst;
    if (s < d && s + n > d) {
   8199c:	eb00003f 	cmp	x1, x0
   819a0:	51000445 	sub	w5, w2, #0x1
   819a4:	54000123 	b.cc	819c8 <memmove+0x30>  // b.lo, b.ul, b.last
void *memmove(void *dst, const void *src, uint n) {
   819a8:	d2800002 	mov	x2, #0x0                   	// #0
   819ac:	d503201f 	nop
        d += n;
        while (n-- > 0)
            *--d = *--s;
    } else
        while (n-- > 0)
            *d++ = *s++;
   819b0:	38626824 	ldrb	w4, [x1, x2]
        while (n-- > 0)
   819b4:	eb0200bf 	cmp	x5, x2
            *d++ = *s++;
   819b8:	38226804 	strb	w4, [x0, x2]
        while (n-- > 0)
   819bc:	91000442 	add	x2, x2, #0x1
   819c0:	54ffff81 	b.ne	819b0 <memmove+0x18>  // b.any

    return dst;
}
   819c4:	d65f03c0 	ret
    if (s < d && s + n > d) {
   819c8:	2a0203e2 	mov	w2, w2
   819cc:	8b020024 	add	x4, x1, x2
   819d0:	eb00009f 	cmp	x4, x0
   819d4:	54fffea9 	b.ls	819a8 <memmove+0x10>  // b.plast
        d += n;
   819d8:	92800021 	mov	x1, #0xfffffffffffffffe    	// #-2
   819dc:	8b020002 	add	x2, x0, x2
        while (n-- > 0)
   819e0:	cb254025 	sub	x5, x1, w5, uxtw
        d += n;
   819e4:	92800001 	mov	x1, #0xffffffffffffffff    	// #-1
            *--d = *--s;
   819e8:	38616883 	ldrb	w3, [x4, x1]
   819ec:	38216843 	strb	w3, [x2, x1]
        while (n-- > 0)
   819f0:	d1000421 	sub	x1, x1, #0x1
   819f4:	eb0100bf 	cmp	x5, x1
   819f8:	54ffff81 	b.ne	819e8 <memmove+0x50>  // b.any
}
   819fc:	d65f03c0 	ret

0000000000081a00 <memcpy>:
 * memcpy exists to satisfy GCC. Use memmove instead.
 * Note: GCC may generate code to invoke memcpy for struct assignment,
 * so the function below must handle all cases correctly (e.g., cannot assume any alignment).
 */
void *memcpy(void *dst, const void *src, uint n) {
    return memmove(dst, src, n);
   81a00:	17ffffe6 	b	81998 <memmove>
   81a04:	d503201f 	nop

0000000000081a08 <strncmp>:
}

int strncmp(const char *p, const char *q, uint n) {
    while (n > 0 && *p && *p == *q)
   81a08:	340001e2 	cbz	w2, 81a44 <strncmp+0x3c>
   81a0c:	51000446 	sub	w6, w2, #0x1
   81a10:	d2800002 	mov	x2, #0x0                   	// #0
   81a14:	14000005 	b	81a28 <strncmp+0x20>
   81a18:	54000121 	b.ne	81a3c <strncmp+0x34>  // b.any
   81a1c:	eb0200df 	cmp	x6, x2
   81a20:	aa0503e2 	mov	x2, x5
   81a24:	54000100 	b.eq	81a44 <strncmp+0x3c>  // b.none
   81a28:	38626803 	ldrb	w3, [x0, x2]
   81a2c:	91000445 	add	x5, x2, #0x1
   81a30:	38626824 	ldrb	w4, [x1, x2]
   81a34:	6b04007f 	cmp	w3, w4
   81a38:	35ffff03 	cbnz	w3, 81a18 <strncmp+0x10>
        n--, p++, q++;
    if (n == 0)
        return 0;
    return (uchar)*p - (uchar)*q;
   81a3c:	4b040060 	sub	w0, w3, w4
}
   81a40:	d65f03c0 	ret
        return 0;
   81a44:	52800000 	mov	w0, #0x0                   	// #0
}
   81a48:	d65f03c0 	ret
   81a4c:	d503201f 	nop

0000000000081a50 <strncpy>:

char *strncpy(char *s, const char *t, int n) {
    char *os;

    os = s;
    while (n-- > 0 && (*s++ = *t++) != 0)
   81a50:	aa0103e5 	mov	x5, x1
   81a54:	aa0003e1 	mov	x1, x0
   81a58:	14000004 	b	81a68 <strncpy+0x18>
   81a5c:	384014a4 	ldrb	w4, [x5], #1
   81a60:	38001424 	strb	w4, [x1], #1
   81a64:	340000a4 	cbz	w4, 81a78 <strncpy+0x28>
   81a68:	2a0203e3 	mov	w3, w2
   81a6c:	51000442 	sub	w2, w2, #0x1
   81a70:	7100007f 	cmp	w3, #0x0
   81a74:	54ffff4c 	b.gt	81a5c <strncpy+0xc>
        ;
    while (n-- > 0)
   81a78:	7100005f 	cmp	w2, #0x0
   81a7c:	0b010063 	add	w3, w3, w1
   81a80:	540000ed 	b.le	81a9c <strncpy+0x4c>
   81a84:	d503201f 	nop
        *s++ = 0;
   81a88:	3800143f 	strb	wzr, [x1], #1
    while (n-- > 0)
   81a8c:	2a2103e2 	mvn	w2, w1
   81a90:	0b030042 	add	w2, w2, w3
   81a94:	7100005f 	cmp	w2, #0x0
   81a98:	54ffff8c 	b.gt	81a88 <strncpy+0x38>
    return os;
}
   81a9c:	d65f03c0 	ret

0000000000081aa0 <safestrcpy>:
/* Like strncpy but guaranteed to NUL-terminate. */
char *safestrcpy(char *s, const char *t, int n) {
    char *os;

    os = s;
    if (n <= 0)
   81aa0:	7100005f 	cmp	w2, #0x0
   81aa4:	5400016d 	b.le	81ad0 <safestrcpy+0x30>
   81aa8:	51000442 	sub	w2, w2, #0x1
   81aac:	aa0003e3 	mov	x3, x0
   81ab0:	8b020024 	add	x4, x1, x2
   81ab4:	14000004 	b	81ac4 <safestrcpy+0x24>
        return os;
    while (--n > 0 && (*s++ = *t++) != 0)
   81ab8:	38401422 	ldrb	w2, [x1], #1
   81abc:	38001462 	strb	w2, [x3], #1
   81ac0:	34000062 	cbz	w2, 81acc <safestrcpy+0x2c>
   81ac4:	eb04003f 	cmp	x1, x4
   81ac8:	54ffff81 	b.ne	81ab8 <safestrcpy+0x18>  // b.any
        ;
    *s = 0;
   81acc:	3900007f 	strb	wzr, [x3]
    return os;
}
   81ad0:	d65f03c0 	ret
   81ad4:	d503201f 	nop

0000000000081ad8 <strlen>:

int strlen(const char *s) {
    int n;

    for (n = 0; s[n]; n++)
   81ad8:	39400001 	ldrb	w1, [x0]
   81adc:	34000101 	cbz	w1, 81afc <strlen+0x24>
   81ae0:	d1000403 	sub	x3, x0, #0x1
   81ae4:	d2800021 	mov	x1, #0x1                   	// #1
   81ae8:	2a0103e0 	mov	w0, w1
   81aec:	91000421 	add	x1, x1, #0x1
   81af0:	38616862 	ldrb	w2, [x3, x1]
   81af4:	35ffffa2 	cbnz	w2, 81ae8 <strlen+0x10>
        ;
    return n;
}
   81af8:	d65f03c0 	ret
    for (n = 0; s[n]; n++)
   81afc:	52800000 	mov	w0, #0x0                   	// #0
}
   81b00:	d65f03c0 	ret
   81b04:	d503201f 	nop

0000000000081b08 <atoi>:

int atoi(const char *s) {
    int n;
    n = 0;
    while ('0' <= *s && *s <= '9')
   81b08:	39400002 	ldrb	w2, [x0]
int atoi(const char *s) {
   81b0c:	aa0003e3 	mov	x3, x0
    while ('0' <= *s && *s <= '9')
   81b10:	5100c040 	sub	w0, w2, #0x30
   81b14:	12001c00 	and	w0, w0, #0xff
   81b18:	7100241f 	cmp	w0, #0x9
    n = 0;
   81b1c:	52800000 	mov	w0, #0x0                   	// #0
    while ('0' <= *s && *s <= '9')
   81b20:	54000148 	b.hi	81b48 <atoi+0x40>  // b.pmore
   81b24:	d503201f 	nop
        n = n * 10 + *s++ - '0';
   81b28:	0b000800 	add	w0, w0, w0, lsl #2
   81b2c:	0b000440 	add	w0, w2, w0, lsl #1
    while ('0' <= *s && *s <= '9')
   81b30:	38401c62 	ldrb	w2, [x3, #1]!
        n = n * 10 + *s++ - '0';
   81b34:	5100c000 	sub	w0, w0, #0x30
    while ('0' <= *s && *s <= '9')
   81b38:	5100c041 	sub	w1, w2, #0x30
   81b3c:	12001c21 	and	w1, w1, #0xff
   81b40:	7100243f 	cmp	w1, #0x9
   81b44:	54ffff29 	b.ls	81b28 <atoi+0x20>  // b.plast
    return n;
}
   81b48:	d65f03c0 	ret
   81b4c:	00000000 	udf	#0

0000000000081b50 <initlock>:

// #define SPINLOCK_DEBUG 1

void initlock(struct spinlock *lk, char *name) {
    lk->name = name;
    lk->locked = 0;
   81b50:	b900001f 	str	wzr, [x0]
    lk->cpu = 0;
   81b54:	a900fc01 	stp	x1, xzr, [x0, #8]
}
   81b58:	d65f03c0 	ret
   81b5c:	d503201f 	nop

0000000000081b60 <holding>:

/* Check whether this cpu is holding the lock.
  Interrupts must be off. */
int holding(struct spinlock *lk) {
    int r;
    r = (lk->locked && lk->cpu == mycpu());
   81b60:	b9400001 	ldr	w1, [x0]
   81b64:	35000061 	cbnz	w1, 81b70 <holding+0x10>
   81b68:	52800000 	mov	w0, #0x0                   	// #0
    return r;
}
   81b6c:	d65f03c0 	ret
int holding(struct spinlock *lk) {
   81b70:	a9be7bfd 	stp	x29, x30, [sp, #-32]!
   81b74:	910003fd 	mov	x29, sp
   81b78:	f9000bf3 	str	x19, [sp, #16]
    r = (lk->locked && lk->cpu == mycpu());
   81b7c:	f9400813 	ldr	x19, [x0, #16]
};
extern struct cpu cpus[NCPU];		// sched.c

// irq must be disabled
extern int cpuid(void); 
static inline struct cpu* mycpu(void) {return &cpus[cpuid()];};
   81b80:	94000cae 	bl	84e38 <cpuid>
   81b84:	f0000081 	adrp	x1, 94000 <_binary_font_psf_start+0x634>
   81b88:	52800302 	mov	w2, #0x18                  	// #24
   81b8c:	f9415021 	ldr	x1, [x1, #672]
   81b90:	9b220400 	smaddl	x0, w0, w2, x1
   81b94:	eb00027f 	cmp	x19, x0
   81b98:	1a9f17e0 	cset	w0, eq  // eq = none
}
   81b9c:	f9400bf3 	ldr	x19, [sp, #16]
   81ba0:	a8c27bfd 	ldp	x29, x30, [sp], #32
   81ba4:	d65f03c0 	ret

0000000000081ba8 <push_off>:
  it takes two pop_off()s to undo two push_off()s.  Also, if interrupts
  are initially off, then push_off, pop_off leaves them off.

  "intena" is the irq status (on/off) when noff (i.e. the "balance") is 0. 
  hence, the irq status must be restored when noff reaches 0 again */
void push_off(void) {
   81ba8:	a9bd7bfd 	stp	x29, x30, [sp, #-48]!
   81bac:	910003fd 	mov	x29, sp
   81bb0:	a90153f3 	stp	x19, x20, [sp, #16]
    int old = intr_get();

    // intr_off();
    disable_irq();
    if (mycpu()->noff == 0)
   81bb4:	f0000093 	adrp	x19, 94000 <_binary_font_psf_start+0x634>
void push_off(void) {
   81bb8:	f90013f5 	str	x21, [sp, #32]
void irq_vector_init( void );    
void enable_irq( void ); 
void disable_irq( void );
int is_irq_masked(void); 
/*return 1 if irq enabled, 0 otherwise*/
static inline int intr_get(void) {return 1-is_irq_masked();}; 
   81bbc:	94000c9b 	bl	84e28 <is_irq_masked>
   81bc0:	2a0003f4 	mov	w20, w0
    disable_irq();
   81bc4:	94000c97 	bl	84e20 <disable_irq>
   81bc8:	94000c9c 	bl	84e38 <cpuid>
    if (mycpu()->noff == 0)
   81bcc:	937f7c01 	sbfiz	x1, x0, #1, #32
   81bd0:	8b20c021 	add	x1, x1, w0, sxtw
   81bd4:	f9415275 	ldr	x21, [x19, #672]
   81bd8:	d37df021 	lsl	x1, x1, #3
   81bdc:	b8616aa0 	ldr	w0, [x21, x1]
   81be0:	340001a0 	cbz	w0, 81c14 <push_off+0x6c>
   81be4:	94000c95 	bl	84e38 <cpuid>
        mycpu()->intena = old;
    mycpu()->noff += 1;
   81be8:	937f7c01 	sbfiz	x1, x0, #1, #32
   81bec:	8b20c020 	add	x0, x1, w0, sxtw
   81bf0:	f9415273 	ldr	x19, [x19, #672]
   81bf4:	d37df000 	lsl	x0, x0, #3
}
   81bf8:	f94013f5 	ldr	x21, [sp, #32]
    mycpu()->noff += 1;
   81bfc:	b8606a61 	ldr	w1, [x19, x0]
   81c00:	11000421 	add	w1, w1, #0x1
   81c04:	b8206a61 	str	w1, [x19, x0]
}
   81c08:	a94153f3 	ldp	x19, x20, [sp, #16]
   81c0c:	a8c37bfd 	ldp	x29, x30, [sp], #48
   81c10:	d65f03c0 	ret
   81c14:	94000c89 	bl	84e38 <cpuid>
   81c18:	52800021 	mov	w1, #0x1                   	// #1
   81c1c:	4b140034 	sub	w20, w1, w20
        mycpu()->intena = old;
   81c20:	937f7c01 	sbfiz	x1, x0, #1, #32
   81c24:	8b20c020 	add	x0, x1, w0, sxtw
   81c28:	8b000eb5 	add	x21, x21, x0, lsl #3
   81c2c:	b90006b4 	str	w20, [x21, #4]
   81c30:	17ffffed 	b	81be4 <push_off+0x3c>
   81c34:	d503201f 	nop

0000000000081c38 <acquire>:
void acquire(struct spinlock *lk) {
   81c38:	a9bd7bfd 	stp	x29, x30, [sp, #-48]!
   81c3c:	910003fd 	mov	x29, sp
   81c40:	a90153f3 	stp	x19, x20, [sp, #16]
   81c44:	aa0003f3 	mov	x19, x0
    push_off(); // disable interrupts to avoid deadlock.
   81c48:	97ffffd8 	bl	81ba8 <push_off>
    if (!lk || holding(lk)) {
   81c4c:	b4000393 	cbz	x19, 81cbc <acquire+0x84>
    r = (lk->locked && lk->cpu == mycpu());
   81c50:	b9400260 	ldr	w0, [x19]
   81c54:	f0000094 	adrp	x20, 94000 <_binary_font_psf_start+0x634>
   81c58:	35000180 	cbnz	w0, 81c88 <acquire+0x50>
    lk->locked = 1;
   81c5c:	52800020 	mov	w0, #0x1                   	// #1
   81c60:	b9000260 	str	w0, [x19]
    __sync_synchronize();
   81c64:	d5033bbf 	dmb	ish
   81c68:	94000c74 	bl	84e38 <cpuid>
   81c6c:	f9415294 	ldr	x20, [x20, #672]
   81c70:	52800301 	mov	w1, #0x18                  	// #24
   81c74:	9b215014 	smaddl	x20, w0, w1, x20
    lk->cpu = mycpu();
   81c78:	f9000a74 	str	x20, [x19, #16]
}
   81c7c:	a94153f3 	ldp	x19, x20, [sp, #16]
   81c80:	a8c37bfd 	ldp	x29, x30, [sp], #48
   81c84:	d65f03c0 	ret
int holding(struct spinlock *lk) {
   81c88:	f90013f5 	str	x21, [sp, #32]
    r = (lk->locked && lk->cpu == mycpu());
   81c8c:	f9400a75 	ldr	x21, [x19, #16]
   81c90:	94000c6a 	bl	84e38 <cpuid>
   81c94:	f9415281 	ldr	x1, [x20, #672]
   81c98:	52800302 	mov	w2, #0x18                  	// #24
   81c9c:	9b220400 	smaddl	x0, w0, w2, x1
   81ca0:	eb0002bf 	cmp	x21, x0
   81ca4:	f94013f5 	ldr	x21, [sp, #32]
   81ca8:	540000c0 	b.eq	81cc0 <acquire+0x88>  // b.none
    while (lk->locked == 1)
   81cac:	b9400260 	ldr	w0, [x19]
   81cb0:	7100041f 	cmp	w0, #0x1
   81cb4:	54fffd41 	b.ne	81c5c <acquire+0x24>  // b.any
   81cb8:	14000000 	b	81cb8 <acquire+0x80>
   81cbc:	f0000094 	adrp	x20, 94000 <_binary_font_psf_start+0x634>
        printf("%s ", lk->name);
   81cc0:	f9400661 	ldr	x1, [x19, #8]
   81cc4:	90000020 	adrp	x0, 85000 <get_el+0x198>
   81cc8:	91096000 	add	x0, x0, #0x258
   81ccc:	97fffe35 	bl	815a0 <tfp_printf>
        panic("acquire");
   81cd0:	90000020 	adrp	x0, 85000 <get_el+0x198>
   81cd4:	91098000 	add	x0, x0, #0x260
   81cd8:	97fffeb6 	bl	817b0 <panic>
    while (lk->locked == 1)
   81cdc:	b9400260 	ldr	w0, [x19]
   81ce0:	7100041f 	cmp	w0, #0x1
   81ce4:	54fffea0 	b.eq	81cb8 <acquire+0x80>  // b.none
   81ce8:	17ffffdd 	b	81c5c <acquire+0x24>
   81cec:	d503201f 	nop

0000000000081cf0 <pop_off>:

/* pop_off must be done with a positive counter (noff)
  i.e. it's a bug if irq is already enabled and then pop_off */
void pop_off(void) {
   81cf0:	a9bd7bfd 	stp	x29, x30, [sp, #-48]!
   81cf4:	910003fd 	mov	x29, sp
   81cf8:	a90153f3 	stp	x19, x20, [sp, #16]
   81cfc:	a9025bf5 	stp	x21, x22, [sp, #32]
   81d00:	94000c4e 	bl	84e38 <cpuid>
   81d04:	2a0003f3 	mov	w19, w0
   81d08:	94000c48 	bl	84e28 <is_irq_masked>
    struct cpu *c = mycpu();
    if (intr_get())
   81d0c:	7100041f 	cmp	w0, #0x1
   81d10:	54000080 	b.eq	81d20 <pop_off+0x30>  // b.none
        panic("pop_off - interruptible");
   81d14:	90000020 	adrp	x0, 85000 <get_el+0x198>
   81d18:	9109a000 	add	x0, x0, #0x268
   81d1c:	97fffea5 	bl	817b0 <panic>
    if (c->noff < 1)
   81d20:	93407e74 	sxtw	x20, w19
   81d24:	f0000095 	adrp	x21, 94000 <_binary_font_psf_start+0x634>
   81d28:	8b33c693 	add	x19, x20, w19, sxtw #1
   81d2c:	f94152b6 	ldr	x22, [x21, #672]
   81d30:	d37df273 	lsl	x19, x19, #3
   81d34:	b8736ac0 	ldr	w0, [x22, x19]
   81d38:	7100001f 	cmp	w0, #0x0
   81d3c:	540001cd 	b.le	81d74 <pop_off+0x84>
        panic("pop_off");
    c->noff -= 1;
   81d40:	8b140694 	add	x20, x20, x20, lsl #1
   81d44:	51000400 	sub	w0, w0, #0x1
   81d48:	f94152b5 	ldr	x21, [x21, #672]
   81d4c:	d37df294 	lsl	x20, x20, #3
   81d50:	b8346aa0 	str	w0, [x21, x20]
    if (c->noff == 0 && c->intena)
   81d54:	35000080 	cbnz	w0, 81d64 <pop_off+0x74>
   81d58:	8b1402b5 	add	x21, x21, x20
   81d5c:	b94006a0 	ldr	w0, [x21, #4]
   81d60:	35000140 	cbnz	w0, 81d88 <pop_off+0x98>
        enable_irq();
}
   81d64:	a94153f3 	ldp	x19, x20, [sp, #16]
   81d68:	a9425bf5 	ldp	x21, x22, [sp, #32]
   81d6c:	a8c37bfd 	ldp	x29, x30, [sp], #48
   81d70:	d65f03c0 	ret
        panic("pop_off");
   81d74:	90000020 	adrp	x0, 85000 <get_el+0x198>
   81d78:	910a0000 	add	x0, x0, #0x280
   81d7c:	97fffe8d 	bl	817b0 <panic>
   81d80:	b8736ac0 	ldr	w0, [x22, x19]
   81d84:	17ffffef 	b	81d40 <pop_off+0x50>
}
   81d88:	a94153f3 	ldp	x19, x20, [sp, #16]
   81d8c:	a9425bf5 	ldp	x21, x22, [sp, #32]
   81d90:	a8c37bfd 	ldp	x29, x30, [sp], #48
        enable_irq();
   81d94:	14000c21 	b	84e18 <enable_irq>

0000000000081d98 <release>:
void release(struct spinlock *lk) {
   81d98:	a9be7bfd 	stp	x29, x30, [sp, #-32]!
   81d9c:	910003fd 	mov	x29, sp
   81da0:	a90153f3 	stp	x19, x20, [sp, #16]
   81da4:	aa0003f3 	mov	x19, x0
    if (!lk || !holding(lk)) {
   81da8:	b4000060 	cbz	x0, 81db4 <release+0x1c>
    r = (lk->locked && lk->cpu == mycpu());
   81dac:	b9400000 	ldr	w0, [x0]
   81db0:	350001c0 	cbnz	w0, 81de8 <release+0x50>
        printf("%s ", lk->name);
   81db4:	f9400661 	ldr	x1, [x19, #8]
   81db8:	90000020 	adrp	x0, 85000 <get_el+0x198>
   81dbc:	91096000 	add	x0, x0, #0x258
   81dc0:	97fffdf8 	bl	815a0 <tfp_printf>
        panic("release");
   81dc4:	90000020 	adrp	x0, 85000 <get_el+0x198>
   81dc8:	910a2000 	add	x0, x0, #0x288
   81dcc:	97fffe79 	bl	817b0 <panic>
    lk->cpu = 0;
   81dd0:	f9000a7f 	str	xzr, [x19, #16]
    __sync_synchronize();
   81dd4:	d5033bbf 	dmb	ish
    lk->locked = 0;
   81dd8:	b900027f 	str	wzr, [x19]
}
   81ddc:	a94153f3 	ldp	x19, x20, [sp, #16]
   81de0:	a8c27bfd 	ldp	x29, x30, [sp], #32
    pop_off();
   81de4:	17ffffc3 	b	81cf0 <pop_off>
    r = (lk->locked && lk->cpu == mycpu());
   81de8:	f9400a74 	ldr	x20, [x19, #16]
   81dec:	94000c13 	bl	84e38 <cpuid>
   81df0:	f0000081 	adrp	x1, 94000 <_binary_font_psf_start+0x634>
   81df4:	52800302 	mov	w2, #0x18                  	// #24
   81df8:	f9415021 	ldr	x1, [x1, #672]
   81dfc:	9b220400 	smaddl	x0, w0, w2, x1
   81e00:	eb00029f 	cmp	x20, x0
   81e04:	54fffd81 	b.ne	81db4 <release+0x1c>  // b.any
   81e08:	17fffff2 	b	81dd0 <release+0x38>
   81e0c:	00000000 	udf	#0

0000000000081e10 <adjust_sys_timer>:

// we have added/removed a virt timer, now adjust the phys timer accordingly
// caller must hold timerlock
// return 0 on success
static int adjust_sys_timer(void)
{
   81e10:	a9bb7bfd 	stp	x29, x30, [sp, #-80]!
   81e14:	910003fd 	mov	x29, sp
   81e18:	a90363f7 	stp	x23, x24, [sp, #48]
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);  //!STUDENT_WILL_SEE_AS( return 0; )
   81e1c:	d2860098 	mov	x24, #0x3004                	// #12292
	unsigned long next = (unsigned long)-1; // upcoming firing time, to be determined
   81e20:	92800017 	mov	x23, #0xffffffffffffffff    	// #-1
{
   81e24:	f90023f9 	str	x25, [sp, #64]
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);  //!STUDENT_WILL_SEE_AS( return 0; )
   81e28:	d2860119 	mov	x25, #0x3008                	// #12296
   81e2c:	f2a7e018 	movk	x24, #0x3f00, lsl #16
   81e30:	f2a7e019 	movk	x25, #0x3f00, lsl #16
{
   81e34:	a90153f3 	stp	x19, x20, [sp, #16]
   81e38:	f0000093 	adrp	x19, 94000 <_binary_font_psf_start+0x634>
   81e3c:	d2800014 	mov	x20, #0x0                   	// #0
   81e40:	910cc273 	add	x19, x19, #0x330
   81e44:	a9025bf5 	stp	x21, x22, [sp, #32]
				} else // timer shall not restart
					timers[tt].handler = 0;
			} else 
				// give "next" a bit slack so current_counter() won't exceed
				// "next" before we retuen from this function
				next = timers[tt].elapseat + 10*1000 /*10ms*/;
   81e48:	d284e215 	mov	x21, #0x2710                	// #10000
					timers[tt].elapseat = current_counter() + TICKPERMS * timers[tt].delayms; 
   81e4c:	52807d16 	mov	w22, #0x3e8                 	// #1000
   81e50:	1400000a 	b	81e78 <adjust_sys_timer+0x68>
				if ((*timers[tt].handler)(tt, timers[tt].param, timers[tt].context) == 1) { 
   81e54:	a9418a61 	ldp	x1, x2, [x19, #24]
   81e58:	d63f0060 	blr	x3
   81e5c:	7100041f 	cmp	w0, #0x1
   81e60:	540005a0 	b.eq	81f14 <adjust_sys_timer+0x104>  // b.none
					timers[tt].handler = 0;
   81e64:	f900027f 	str	xzr, [x19]
	for (int tt = 0; tt < N_TIMERS; tt++) {
   81e68:	91000694 	add	x20, x20, #0x1
   81e6c:	9100a273 	add	x19, x19, #0x28
   81e70:	f100529f 	cmp	x20, #0x14
   81e74:	54000240 	b.eq	81ebc <adjust_sys_timer+0xac>  // b.none
		if (!timers[tt].handler)
   81e78:	f9400263 	ldr	x3, [x19]
   81e7c:	b4ffff63 	cbz	x3, 81e68 <adjust_sys_timer+0x58>
		if (timers[tt].elapseat < next) {
   81e80:	f9400661 	ldr	x1, [x19, #8]
   81e84:	eb17003f 	cmp	x1, x23
   81e88:	54ffff02 	b.cs	81e68 <adjust_sys_timer+0x58>  // b.hs, b.nlast
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);  //!STUDENT_WILL_SEE_AS( return 0; )
   81e8c:	b9400322 	ldr	w2, [x25]
				if ((*timers[tt].handler)(tt, timers[tt].param, timers[tt].context) == 1) { 
   81e90:	aa1403e0 	mov	x0, x20
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);  //!STUDENT_WILL_SEE_AS( return 0; )
   81e94:	b9400304 	ldr	w4, [x24]
   81e98:	2a0403e4 	mov	w4, w4
   81e9c:	aa028082 	orr	x2, x4, x2, lsl #32
			if (timers[tt].elapseat < current_counter()) {
   81ea0:	eb02003f 	cmp	x1, x2
   81ea4:	54fffd83 	b.cc	81e54 <adjust_sys_timer+0x44>  // b.lo, b.ul, b.last
   81ea8:	91000694 	add	x20, x20, #0x1
				next = timers[tt].elapseat + 10*1000 /*10ms*/;
   81eac:	8b150037 	add	x23, x1, x21
	for (int tt = 0; tt < N_TIMERS; tt++) {
   81eb0:	9100a273 	add	x19, x19, #0x28
   81eb4:	f100529f 	cmp	x20, #0x14
   81eb8:	54fffe01 	b.ne	81e78 <adjust_sys_timer+0x68>  // b.any
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);  //!STUDENT_WILL_SEE_AS( return 0; )
   81ebc:	d2860100 	mov	x0, #0x3008                	// #12296
   81ec0:	d2860081 	mov	x1, #0x3004                	// #12292
   81ec4:	f2a7e000 	movk	x0, #0x3f00, lsl #16
   81ec8:	f2a7e001 	movk	x1, #0x3f00, lsl #16
   81ecc:	b9400000 	ldr	w0, [x0]
   81ed0:	b9400021 	ldr	w1, [x1]
   81ed4:	2a0103e1 	mov	w1, w1
   81ed8:	aa008020 	orr	x0, x1, x0, lsl #32
		}
	}

	// a known bug (TBD. may occur: when qemu is very slow, or on actual hw
	// timer expired, but handler not called?? should we handle it?
	BUG_ON(current_counter() > next); 
   81edc:	eb0002ff 	cmp	x23, x0
   81ee0:	540002c3 	b.cc	81f38 <adjust_sys_timer+0x128>  // b.lo, b.ul, b.last

	// if no valid handlers, we leave TIMER_C1 as is. it will trigger a timer
	// irq when wrapping around (~4000 sec later). this is fine as our isr
	// compares 64bit counters. 
	if (next == 0xFFFFFFFFFFFFFFFF) 
   81ee4:	b10006ff 	cmn	x23, #0x1
   81ee8:	54000080 	b.eq	81ef8 <adjust_sys_timer+0xe8>  // b.none
		return 0; 

	// the compare reg is only 32 bits so we have to ignore the high 32 bits of
	// the counter. this is ok even if the low 32 bits have to wrap around 
	// in order to match TIMER_C1 (cf the isr)	
	put32(TIMER_C1, (unsigned)next);	//!STUDENT_DONOT_SEE
   81eec:	d2860200 	mov	x0, #0x3010                	// #12304
   81ef0:	f2a7e000 	movk	x0, #0x3f00, lsl #16
   81ef4:	b9000017 	str	w23, [x0]

	return 0; 
}
   81ef8:	52800000 	mov	w0, #0x0                   	// #0
   81efc:	a94153f3 	ldp	x19, x20, [sp, #16]
   81f00:	a9425bf5 	ldp	x21, x22, [sp, #32]
   81f04:	a94363f7 	ldp	x23, x24, [sp, #48]
   81f08:	f94023f9 	ldr	x25, [sp, #64]
   81f0c:	a8c57bfd 	ldp	x29, x30, [sp], #80
   81f10:	d65f03c0 	ret
					timers[tt].elapseat = current_counter() + TICKPERMS * timers[tt].delayms; 
   81f14:	b9401260 	ldr	w0, [x19, #16]
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);  //!STUDENT_WILL_SEE_AS( return 0; )
   81f18:	b9400321 	ldr	w1, [x25]
   81f1c:	b9400302 	ldr	w2, [x24]
					timers[tt].elapseat = current_counter() + TICKPERMS * timers[tt].delayms; 
   81f20:	1b167c00 	mul	w0, w0, w22
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);  //!STUDENT_WILL_SEE_AS( return 0; )
   81f24:	2a0203e2 	mov	w2, w2
   81f28:	aa018041 	orr	x1, x2, x1, lsl #32
					timers[tt].elapseat = current_counter() + TICKPERMS * timers[tt].delayms; 
   81f2c:	8b204020 	add	x0, x1, w0, uxtw
   81f30:	f9000660 	str	x0, [x19, #8]
   81f34:	17ffffcd 	b	81e68 <adjust_sys_timer+0x58>
	BUG_ON(current_counter() > next); 
   81f38:	90000021 	adrp	x1, 85000 <get_el+0x198>
   81f3c:	90000020 	adrp	x0, 85000 <get_el+0x198>
   81f40:	910a4021 	add	x1, x1, #0x290
   81f44:	910a6000 	add	x0, x0, #0x298
   81f48:	52801ae2 	mov	w2, #0xd7                  	// #215
   81f4c:	97fffe63 	bl	818d8 <assertion_failed>
	if (next == 0xFFFFFFFFFFFFFFFF) 
   81f50:	17ffffe7 	b	81eec <adjust_sys_timer+0xdc>
   81f54:	d503201f 	nop

0000000000081f58 <generic_timer_init>:
	asm volatile("msr CNTP_CTL_EL0, %0" : : "r"(1));
   81f58:	52800020 	mov	w0, #0x1                   	// #1
   81f5c:	d51be220 	msr	cntp_ctl_el0, x0
	generic_timer_reset(interval);	// kickoff 1st time firing
   81f60:	d0000080 	adrp	x0, 93000 <get_el+0xe198>
	asm volatile("msr CNTP_TVAL_EL0, %0" : : "r"(intv));  // TVAL is 32bit, signed
   81f64:	b9495800 	ldr	w0, [x0, #2392]
   81f68:	d51be200 	msr	cntp_tval_el0, x0
}
   81f6c:	d65f03c0 	ret

0000000000081f70 <handle_generic_timer_irq>:
	generic_timer_reset(interval);
   81f70:	d0000080 	adrp	x0, 93000 <get_el+0xe198>
	asm volatile("msr CNTP_TVAL_EL0, %0" : : "r"(intv));  // TVAL is 32bit, signed
   81f74:	b9495800 	ldr	w0, [x0, #2392]
   81f78:	d51be200 	msr	cntp_tval_el0, x0
}
   81f7c:	d65f03c0 	ret

0000000000081f80 <current_counter>:
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);  //!STUDENT_WILL_SEE_AS( return 0; )
   81f80:	d2860101 	mov	x1, #0x3008                	// #12296
   81f84:	d2860080 	mov	x0, #0x3004                	// #12292
   81f88:	f2a7e001 	movk	x1, #0x3f00, lsl #16
   81f8c:	f2a7e000 	movk	x0, #0x3f00, lsl #16
   81f90:	b9400021 	ldr	w1, [x1]
   81f94:	b9400000 	ldr	w0, [x0]
   81f98:	2a0003e0 	mov	w0, w0
}
   81f9c:	aa018000 	orr	x0, x0, x1, lsl #32
   81fa0:	d65f03c0 	ret
   81fa4:	d503201f 	nop

0000000000081fa8 <ms_delay>:
	delay(cycles_per_ms * ms); 	// !STUDENT_DONOT_SEE
   81fa8:	52944bc1 	mov	w1, #0xa25e                	// #41566
void ms_delay(unsigned ms) {
   81fac:	d10043ff 	sub	sp, sp, #0x10
	delay(cycles_per_ms * ms); 	// !STUDENT_DONOT_SEE
   81fb0:	72a000c1 	movk	w1, #0x6, lsl #16
   81fb4:	1b017c00 	mul	w0, w0, w1
	volatile unsigned long c = cycles; 
   81fb8:	f90007e0 	str	x0, [sp, #8]
	while (c!=0) c--; 
   81fbc:	f94007e0 	ldr	x0, [sp, #8]
   81fc0:	b40000e0 	cbz	x0, 81fdc <ms_delay+0x34>
   81fc4:	d503201f 	nop
   81fc8:	f94007e0 	ldr	x0, [sp, #8]
   81fcc:	d1000400 	sub	x0, x0, #0x1
   81fd0:	f90007e0 	str	x0, [sp, #8]
   81fd4:	f94007e0 	ldr	x0, [sp, #8]
   81fd8:	b5ffff80 	cbnz	x0, 81fc8 <ms_delay+0x20>
}
   81fdc:	910043ff 	add	sp, sp, #0x10
   81fe0:	d65f03c0 	ret
   81fe4:	d503201f 	nop

0000000000081fe8 <us_delay>:
void us_delay(unsigned us) {
   81fe8:	d10043ff 	sub	sp, sp, #0x10
	delay(cycles_per_us * us); // !STUDENT_DONOT_SEE
   81fec:	52803641 	mov	w1, #0x1b2                 	// #434
   81ff0:	1b017c00 	mul	w0, w0, w1
	volatile unsigned long c = cycles; 
   81ff4:	f90007e0 	str	x0, [sp, #8]
	while (c!=0) c--; 
   81ff8:	f94007e0 	ldr	x0, [sp, #8]
   81ffc:	b40000c0 	cbz	x0, 82014 <us_delay+0x2c>
   82000:	f94007e0 	ldr	x0, [sp, #8]
   82004:	d1000400 	sub	x0, x0, #0x1
   82008:	f90007e0 	str	x0, [sp, #8]
   8200c:	f94007e0 	ldr	x0, [sp, #8]
   82010:	b5ffff80 	cbnz	x0, 82000 <us_delay+0x18>
}
   82014:	910043ff 	add	sp, sp, #0x10
   82018:	d65f03c0 	ret
   8201c:	d503201f 	nop

0000000000082020 <current_time>:
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);  //!STUDENT_WILL_SEE_AS( return 0; )
   82020:	d2860102 	mov	x2, #0x3008                	// #12296
   82024:	d2860085 	mov	x5, #0x3004                	// #12292
   82028:	f2a7e002 	movk	x2, #0x3f00, lsl #16
   8202c:	f2a7e005 	movk	x5, #0x3f00, lsl #16
	*sec =  (unsigned) (cur / TICKPERSEC); 
   82030:	d2869b63 	mov	x3, #0x34db                	// #13531
	cur -= (*sec) * TICKPERSEC; 
   82034:	52884804 	mov	w4, #0x4240                	// #16960
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);  //!STUDENT_WILL_SEE_AS( return 0; )
   82038:	b9400042 	ldr	w2, [x2]
	*sec =  (unsigned) (cur / TICKPERSEC); 
   8203c:	f2baf6c3 	movk	x3, #0xd7b6, lsl #16
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);  //!STUDENT_WILL_SEE_AS( return 0; )
   82040:	b94000a5 	ldr	w5, [x5]
	*sec =  (unsigned) (cur / TICKPERSEC); 
   82044:	f2dbd043 	movk	x3, #0xde82, lsl #32
   82048:	f2e86363 	movk	x3, #0x431b, lsl #48
	cur -= (*sec) * TICKPERSEC; 
   8204c:	72a001e4 	movk	w4, #0xf, lsl #16
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);  //!STUDENT_WILL_SEE_AS( return 0; )
   82050:	2a0503e5 	mov	w5, w5
	*msec = (unsigned) (cur / TICKPERMS);
   82054:	d29ef9e6 	mov	x6, #0xf7cf                	// #63439
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);  //!STUDENT_WILL_SEE_AS( return 0; )
   82058:	aa0280a2 	orr	x2, x5, x2, lsl #32
	*msec = (unsigned) (cur / TICKPERMS);
   8205c:	f2bc6a66 	movk	x6, #0xe353, lsl #16
   82060:	f2d374a6 	movk	x6, #0x9ba5, lsl #32
   82064:	f2e41886 	movk	x6, #0x20c4, lsl #48
	*sec =  (unsigned) (cur / TICKPERSEC); 
   82068:	9bc37c43 	umulh	x3, x2, x3
   8206c:	d352fc63 	lsr	x3, x3, #18
   82070:	b9000003 	str	w3, [x0]
	cur -= (*sec) * TICKPERSEC; 
   82074:	1b037c83 	mul	w3, w4, w3
   82078:	cb234042 	sub	x2, x2, w3, uxtw
	*msec = (unsigned) (cur / TICKPERMS);
   8207c:	d343fc42 	lsr	x2, x2, #3
   82080:	9bc67c42 	umulh	x2, x2, x6
   82084:	d344fc42 	lsr	x2, x2, #4
   82088:	b9000022 	str	w2, [x1]
}
   8208c:	d65f03c0 	ret

0000000000082090 <delay>:
void delay(unsigned long cycles) {
   82090:	d10043ff 	sub	sp, sp, #0x10
	volatile unsigned long c = cycles; 
   82094:	f90007e0 	str	x0, [sp, #8]
	while (c!=0) c--; 
   82098:	f94007e0 	ldr	x0, [sp, #8]
   8209c:	b40000c0 	cbz	x0, 820b4 <delay+0x24>
   820a0:	f94007e0 	ldr	x0, [sp, #8]
   820a4:	d1000400 	sub	x0, x0, #0x1
   820a8:	f90007e0 	str	x0, [sp, #8]
   820ac:	f94007e0 	ldr	x0, [sp, #8]
   820b0:	b5ffff80 	cbnz	x0, 820a0 <delay+0x10>
}
   820b4:	910043ff 	add	sp, sp, #0x10
   820b8:	d65f03c0 	ret
   820bc:	d503201f 	nop

00000000000820c0 <sys_timer_init>:
{
   820c0:	a9bf7bfd 	stp	x29, x30, [sp, #-16]!
	initlock(&timerlock, "timer"); 
   820c4:	d0000080 	adrp	x0, 94000 <_binary_font_psf_start+0x634>
   820c8:	f0000001 	adrp	x1, 85000 <get_el+0x198>
{
   820cc:	910003fd 	mov	x29, sp
	initlock(&timerlock, "timer"); 
   820d0:	f9414c00 	ldr	x0, [x0, #664]
   820d4:	910ae021 	add	x1, x1, #0x2b8
   820d8:	97fffe9e 	bl	81b50 <initlock>
}
   820dc:	a8c17bfd 	ldp	x29, x30, [sp], #16
	memzero(timers, sizeof(timers)); 	// all field zeros	
   820e0:	d0000080 	adrp	x0, 94000 <_binary_font_psf_start+0x634>
   820e4:	52806401 	mov	w1, #0x320                 	// #800
   820e8:	910cc000 	add	x0, x0, #0x330
   820ec:	17fffe11 	b	81930 <memzero>

00000000000820f0 <ktimer_start>:

// see above
// cannot be called from TKernelTimerHandler, which will have timerlock held
// thus, deadlock 
int ktimer_start(unsigned delayms, TKernelTimerHandler *handler, 
		void *para, void *context) {
   820f0:	a9ba7bfd 	stp	x29, x30, [sp, #-96]!
   820f4:	910003fd 	mov	x29, sp
   820f8:	a90363f7 	stp	x23, x24, [sp, #48]
	int ret;
	acquire(&timerlock); 
   820fc:	d0000097 	adrp	x23, 94000 <_binary_font_psf_start+0x634>
   82100:	d0000098 	adrp	x24, 94000 <_binary_font_psf_start+0x634>
		void *para, void *context) {
   82104:	f90023f9 	str	x25, [sp, #64]
   82108:	2a0003f9 	mov	w25, w0
	acquire(&timerlock); 
   8210c:	f9414ee0 	ldr	x0, [x23, #664]
		void *para, void *context) {
   82110:	a90153f3 	stp	x19, x20, [sp, #16]
   82114:	aa0103f4 	mov	x20, x1
   82118:	a9025bf5 	stp	x21, x22, [sp, #32]
   8211c:	aa0203f5 	mov	x21, x2
   82120:	aa0303f6 	mov	x22, x3
	acquire(&timerlock); 
   82124:	97fffec5 	bl	81c38 <acquire>
	for (t = 0; t < N_TIMERS; t++) {
   82128:	52800013 	mov	w19, #0x0                   	// #0
   8212c:	910cc300 	add	x0, x24, #0x330
   82130:	14000004 	b	82140 <ktimer_start+0x50>
   82134:	11000673 	add	w19, w19, #0x1
   82138:	7100527f 	cmp	w19, #0x14
   8213c:	54000460 	b.eq	821c8 <ktimer_start+0xd8>  // b.none
		if (timers[t].handler == 0) 
   82140:	f9400001 	ldr	x1, [x0]
   82144:	9100a000 	add	x0, x0, #0x28
   82148:	b5ffff61 	cbnz	x1, 82134 <ktimer_start+0x44>
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);  //!STUDENT_WILL_SEE_AS( return 0; )
   8214c:	d2860101 	mov	x1, #0x3008                	// #12296
   82150:	d2860080 	mov	x0, #0x3004                	// #12292
   82154:	f2a7e001 	movk	x1, #0x3f00, lsl #16
   82158:	f2a7e000 	movk	x0, #0x3f00, lsl #16
	BUG_ON(cur + TICKPERMS * delayms < cur); // 64bit counter wraps around??
   8215c:	52807d04 	mov	w4, #0x3e8                 	// #1000
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);  //!STUDENT_WILL_SEE_AS( return 0; )
   82160:	b9400025 	ldr	w5, [x1]
   82164:	b9400000 	ldr	w0, [x0]
	BUG_ON(cur + TICKPERMS * delayms < cur); // 64bit counter wraps around??
   82168:	1b047f26 	mul	w6, w25, w4
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);  //!STUDENT_WILL_SEE_AS( return 0; )
   8216c:	2a0003e0 	mov	w0, w0
   82170:	aa058004 	orr	x4, x0, x5, lsl #32
   82174:	ab060084 	adds	x4, x4, x6
   82178:	54000382 	b.cs	821e8 <ktimer_start+0xf8>  // b.hs, b.nlast
	timers[t].handler = handler; 
   8217c:	d37e7e61 	ubfiz	x1, x19, #2, #32
   82180:	910cc318 	add	x24, x24, #0x330
   82184:	8b334021 	add	x1, x1, w19, uxtw
   82188:	d37df021 	lsl	x1, x1, #3
	timers[t].param = para; 
   8218c:	8b010300 	add	x0, x24, x1
	timers[t].handler = handler; 
   82190:	f8216b14 	str	x20, [x24, x1]
	timers[t].elapseat = cur + TICKPERMS * delayms; 
   82194:	f9000404 	str	x4, [x0, #8]
	timers[t].delayms = delayms; 
   82198:	b9001019 	str	w25, [x0, #16]
	timers[t].context = context; 
   8219c:	a901d815 	stp	x21, x22, [x0, #24]
	adjust_sys_timer(); 
   821a0:	97ffff1c 	bl	81e10 <adjust_sys_timer>
	ret = ktimer_start_nolock(delayms, handler, para, context); 
	release(&timerlock); 
   821a4:	f9414ee0 	ldr	x0, [x23, #664]
   821a8:	97fffefc 	bl	81d98 <release>
	return ret;
}
   821ac:	2a1303e0 	mov	w0, w19
   821b0:	a94153f3 	ldp	x19, x20, [sp, #16]
   821b4:	a9425bf5 	ldp	x21, x22, [sp, #32]
   821b8:	a94363f7 	ldp	x23, x24, [sp, #48]
   821bc:	f94023f9 	ldr	x25, [sp, #64]
   821c0:	a8c67bfd 	ldp	x29, x30, [sp], #96
   821c4:	d65f03c0 	ret
		E("ktimer_start failed. # max timer reached"); 
   821c8:	f0000001 	adrp	x1, 85000 <get_el+0x198>
   821cc:	f0000000 	adrp	x0, 85000 <get_el+0x198>
   821d0:	910a4021 	add	x1, x1, #0x290
   821d4:	910bc000 	add	x0, x0, #0x2f0
   821d8:	52801ee2 	mov	w2, #0xf7                  	// #247
		return -1; 
   821dc:	12800013 	mov	w19, #0xffffffff            	// #-1
		E("ktimer_start failed. # max timer reached"); 
   821e0:	97fffcf0 	bl	815a0 <tfp_printf>
		return -1; 
   821e4:	17fffff0 	b	821a4 <ktimer_start+0xb4>
	BUG_ON(cur + TICKPERMS * delayms < cur); // 64bit counter wraps around??
   821e8:	f0000001 	adrp	x1, 85000 <get_el+0x198>
   821ec:	f0000000 	adrp	x0, 85000 <get_el+0x198>
   821f0:	910a4021 	add	x1, x1, #0x290
   821f4:	910b0000 	add	x0, x0, #0x2c0
   821f8:	52801f82 	mov	w2, #0xfc                  	// #252
   821fc:	f9002fe4 	str	x4, [sp, #88]
   82200:	97fffdb6 	bl	818d8 <assertion_failed>
   82204:	f9402fe4 	ldr	x4, [sp, #88]
   82208:	17ffffdd 	b	8217c <ktimer_start+0x8c>
   8220c:	d503201f 	nop

0000000000082210 <ktimer_cancel>:
// return 0 on okay, -1 if no such timer/handler, 
//	-2 if already fired (will clean anyway)
int ktimer_cancel(int t) {
	unsigned long cur; 

	if (t < 0 || t >= N_TIMERS)
   82210:	71004c1f 	cmp	w0, #0x13
   82214:	540004c8 	b.hi	822ac <ktimer_cancel+0x9c>  // b.pmore
int ktimer_cancel(int t) {
   82218:	a9bd7bfd 	stp	x29, x30, [sp, #-48]!
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);  //!STUDENT_WILL_SEE_AS( return 0; )
   8221c:	d2860101 	mov	x1, #0x3008                	// #12296
   82220:	f2a7e001 	movk	x1, #0x3f00, lsl #16
int ktimer_cancel(int t) {
   82224:	910003fd 	mov	x29, sp
   82228:	a90153f3 	stp	x19, x20, [sp, #16]
   8222c:	2a0003f3 	mov	w19, w0
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);  //!STUDENT_WILL_SEE_AS( return 0; )
   82230:	d2860080 	mov	x0, #0x3004                	// #12292
   82234:	f2a7e000 	movk	x0, #0x3f00, lsl #16
   82238:	b9400022 	ldr	w2, [x1]
		return -1; 

	cur = current_counter();
	acquire(&timerlock); 
   8223c:	d0000094 	adrp	x20, 94000 <_binary_font_psf_start+0x634>
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);  //!STUDENT_WILL_SEE_AS( return 0; )
   82240:	b9400001 	ldr	w1, [x0]
	acquire(&timerlock); 
   82244:	f9414e94 	ldr	x20, [x20, #664]
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);  //!STUDENT_WILL_SEE_AS( return 0; )
   82248:	2a0103e1 	mov	w1, w1
int ktimer_cancel(int t) {
   8224c:	f90013f5 	str	x21, [sp, #32]
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);  //!STUDENT_WILL_SEE_AS( return 0; )
   82250:	aa028035 	orr	x21, x1, x2, lsl #32
	acquire(&timerlock); 
   82254:	aa1403e0 	mov	x0, x20
   82258:	97fffe78 	bl	81c38 <acquire>

	if (!timers[t].handler) {	// invalid handler
   8225c:	937e7e60 	sbfiz	x0, x19, #2, #32
   82260:	d0000081 	adrp	x1, 94000 <_binary_font_psf_start+0x634>
   82264:	8b33c013 	add	x19, x0, w19, sxtw
   82268:	910cc021 	add	x1, x1, #0x330
   8226c:	d37df273 	lsl	x19, x19, #3
   82270:	f8736820 	ldr	x0, [x1, x19]
   82274:	b40002c0 	cbz	x0, 822cc <ktimer_cancel+0xbc>
		release(&timerlock); 
		return -1; 
	}

	if (timers[t].elapseat < cur) { // already fired? 
   82278:	8b130022 	add	x2, x1, x19
   8227c:	f9400440 	ldr	x0, [x2, #8]
   82280:	eb15001f 	cmp	x0, x21
   82284:	54000183 	b.cc	822b4 <ktimer_cancel+0xa4>  // b.lo, b.ul, b.last
		timers[t].param = 0; 
		release(&timerlock); 
		return -2; 
	}

	timers[t].handler = 0; 
   82288:	f833683f 	str	xzr, [x1, x19]
	// timers[t].context = 0; 
	// timers[t].param = 0; 
	// timers[t].elapseat = 0; 

	adjust_sys_timer(); 	
   8228c:	97fffee1 	bl	81e10 <adjust_sys_timer>
	release(&timerlock);
   82290:	aa1403e0 	mov	x0, x20
   82294:	97fffec1 	bl	81d98 <release>

	return 0;  
   82298:	52800000 	mov	w0, #0x0                   	// #0
}
   8229c:	a94153f3 	ldp	x19, x20, [sp, #16]
   822a0:	f94013f5 	ldr	x21, [sp, #32]
   822a4:	a8c37bfd 	ldp	x29, x30, [sp], #48
   822a8:	d65f03c0 	ret
		return -1; 
   822ac:	12800000 	mov	w0, #0xffffffff            	// #-1
}
   822b0:	d65f03c0 	ret
		timers[t].handler = 0; 
   822b4:	f833683f 	str	xzr, [x1, x19]
		release(&timerlock); 
   822b8:	aa1403e0 	mov	x0, x20
		timers[t].context = 0; 
   822bc:	a901fc5f 	stp	xzr, xzr, [x2, #24]
		release(&timerlock); 
   822c0:	97fffeb6 	bl	81d98 <release>
		return -2; 
   822c4:	12800020 	mov	w0, #0xfffffffe            	// #-2
   822c8:	17fffff5 	b	8229c <ktimer_cancel+0x8c>
		release(&timerlock); 
   822cc:	aa1403e0 	mov	x0, x20
   822d0:	97fffeb2 	bl	81d98 <release>
		return -1; 
   822d4:	12800000 	mov	w0, #0xffffffff            	// #-1
   822d8:	17fffff1 	b	8229c <ktimer_cancel+0x8c>
   822dc:	d503201f 	nop

00000000000822e0 <sys_timer_irq>:
void sys_timer_irq(void) 
{
	V("called");	

	// timer1 must have pending match. below could happen under high load. why?
	BUG_ON(!(get32(TIMER_CS) & TIMER_CS_M1));  
   822e0:	d2860000 	mov	x0, #0x3000                	// #12288
{
   822e4:	a9bc7bfd 	stp	x29, x30, [sp, #-64]!
	BUG_ON(!(get32(TIMER_CS) & TIMER_CS_M1));  
   822e8:	f2a7e000 	movk	x0, #0x3f00, lsl #16
{
   822ec:	910003fd 	mov	x29, sp
	BUG_ON(!(get32(TIMER_CS) & TIMER_CS_M1));  
   822f0:	b9400000 	ldr	w0, [x0]
{
   822f4:	a90153f3 	stp	x19, x20, [sp, #16]
   822f8:	a9025bf5 	stp	x21, x22, [sp, #32]
   822fc:	f9001bf7 	str	x23, [sp, #48]
	BUG_ON(!(get32(TIMER_CS) & TIMER_CS_M1));  
   82300:	36080680 	tbz	w0, #1, 823d0 <sys_timer_irq+0xf0>
	put32(TIMER_CS, TIMER_CS_M1);	// clear timer1 match
   82304:	d2860000 	mov	x0, #0x3000                	// #12288
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);  //!STUDENT_WILL_SEE_AS( return 0; )
   82308:	d2860102 	mov	x2, #0x3008                	// #12296
	put32(TIMER_CS, TIMER_CS_M1);	// clear timer1 match
   8230c:	f2a7e000 	movk	x0, #0x3f00, lsl #16
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);  //!STUDENT_WILL_SEE_AS( return 0; )
   82310:	d2860081 	mov	x1, #0x3004                	// #12292
	put32(TIMER_CS, TIMER_CS_M1);	// clear timer1 match
   82314:	52800043 	mov	w3, #0x2                   	// #2
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);  //!STUDENT_WILL_SEE_AS( return 0; )
   82318:	f2a7e002 	movk	x2, #0x3f00, lsl #16
   8231c:	f2a7e001 	movk	x1, #0x3f00, lsl #16
	put32(TIMER_CS, TIMER_CS_M1);	// clear timer1 match
   82320:	b9000003 	str	w3, [x0]

	unsigned long cur = current_counter(); 
	int ret; 

	acquire(&timerlock); 
   82324:	d0000096 	adrp	x22, 94000 <_binary_font_psf_start+0x634>
   82328:	d2800014 	mov	x20, #0x0                   	// #0
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);  //!STUDENT_WILL_SEE_AS( return 0; )
   8232c:	b9400055 	ldr	w21, [x2]
			// W("called, id %d h %lx", t, (unsigned long)timers[t].handler);	
			// NB: exec the callback w/ timerlock held
			// quest (side): virtual timers
			ret = (*h)(t, timers[t].param, timers[t].context); //!STUDENT_WILL_SEE_AS( ret = 0; )
			if (ret==1) { // restart the ktimer in place
				timers[t].elapseat = cur + TICKPERMS * timers[t].delayms; //!STUDENT_WILL_SEE_AS( timers[t].elapseat = 0; )
   82330:	52807d17 	mov	w23, #0x3e8                 	// #1000
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);  //!STUDENT_WILL_SEE_AS( return 0; )
   82334:	b9400021 	ldr	w1, [x1]
   82338:	d0000093 	adrp	x19, 94000 <_binary_font_psf_start+0x634>
	acquire(&timerlock); 
   8233c:	f9414ec0 	ldr	x0, [x22, #664]
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);  //!STUDENT_WILL_SEE_AS( return 0; )
   82340:	2a0103e1 	mov	w1, w1
   82344:	910cc273 	add	x19, x19, #0x330
   82348:	aa158035 	orr	x21, x1, x21, lsl #32
	acquire(&timerlock); 
   8234c:	97fffe3b 	bl	81c38 <acquire>
	for (int t = 0; t < N_TIMERS; t++) {
   82350:	14000006 	b	82368 <sys_timer_irq+0x88>
				adjust_sys_timer(); 
			} else 
				timers[t].handler = 0; 
   82354:	f900027f 	str	xzr, [x19]
	for (int t = 0; t < N_TIMERS; t++) {
   82358:	91000694 	add	x20, x20, #0x1
   8235c:	9100a273 	add	x19, x19, #0x28
   82360:	f100529f 	cmp	x20, #0x14
   82364:	54000280 	b.eq	823b4 <sys_timer_irq+0xd4>  // b.none
		TKernelTimerHandler *h = timers[t].handler; 
   82368:	f9400263 	ldr	x3, [x19]
			ret = (*h)(t, timers[t].param, timers[t].context); //!STUDENT_WILL_SEE_AS( ret = 0; )
   8236c:	aa1403e0 	mov	x0, x20
		if (h == 0) 
   82370:	b4ffff43 	cbz	x3, 82358 <sys_timer_irq+0x78>
		if (timers[t].elapseat <= cur) { // should fire  
   82374:	f9400661 	ldr	x1, [x19, #8]
   82378:	eb15003f 	cmp	x1, x21
   8237c:	54fffee8 	b.hi	82358 <sys_timer_irq+0x78>  // b.pmore
			ret = (*h)(t, timers[t].param, timers[t].context); //!STUDENT_WILL_SEE_AS( ret = 0; )
   82380:	a9418a61 	ldp	x1, x2, [x19, #24]
   82384:	d63f0060 	blr	x3
			if (ret==1) { // restart the ktimer in place
   82388:	7100041f 	cmp	w0, #0x1
   8238c:	54fffe41 	b.ne	82354 <sys_timer_irq+0x74>  // b.any
				timers[t].elapseat = cur + TICKPERMS * timers[t].delayms; //!STUDENT_WILL_SEE_AS( timers[t].elapseat = 0; )
   82390:	b9401260 	ldr	w0, [x19, #16]
   82394:	91000694 	add	x20, x20, #0x1
   82398:	9100a273 	add	x19, x19, #0x28
   8239c:	1b177c00 	mul	w0, w0, w23
   823a0:	8b2042a0 	add	x0, x21, w0, uxtw
   823a4:	f81e0260 	stur	x0, [x19, #-32]
				adjust_sys_timer(); 
   823a8:	97fffe9a 	bl	81e10 <adjust_sys_timer>
	for (int t = 0; t < N_TIMERS; t++) {
   823ac:	f100529f 	cmp	x20, #0x14
   823b0:	54fffdc1 	b.ne	82368 <sys_timer_irq+0x88>  // b.any
		}		
	}
	adjust_sys_timer(); 
   823b4:	97fffe97 	bl	81e10 <adjust_sys_timer>
	release(&timerlock);
   823b8:	f9414ec0 	ldr	x0, [x22, #664]
}
   823bc:	a94153f3 	ldp	x19, x20, [sp, #16]
   823c0:	a9425bf5 	ldp	x21, x22, [sp, #32]
   823c4:	f9401bf7 	ldr	x23, [sp, #48]
   823c8:	a8c47bfd 	ldp	x29, x30, [sp], #64
	release(&timerlock);
   823cc:	17fffe73 	b	81d98 <release>
	BUG_ON(!(get32(TIMER_CS) & TIMER_CS_M1));  
   823d0:	f0000001 	adrp	x1, 85000 <get_el+0x198>
   823d4:	f0000000 	adrp	x0, 85000 <get_el+0x198>
   823d8:	910a4021 	add	x1, x1, #0x290
   823dc:	910cc000 	add	x0, x0, #0x330
   823e0:	528027e2 	mov	w2, #0x13f                 	// #319
   823e4:	97fffd3d 	bl	818d8 <assertion_failed>
   823e8:	17ffffc7 	b	82304 <sys_timer_irq+0x24>
   823ec:	00000000 	udf	#0

00000000000823f0 <mbox_call>:
 * Spin wait for mailbox hardware.
 * Returns 0 on failure, non-zero on success.
 *
 * Caller must hold mboxlock.
 */
int mbox_call(unsigned char ch) {
   823f0:	a9bc7bfd 	stp	x29, x30, [sp, #-64]!
    // the buf addr (pa) w/ ch (chan id) in LSB 
    unsigned int r = (((unsigned int)((unsigned long)&mbox) & ~0xF) | (ch & 0xF));
    r = BUS_ADDRESS(r); 
    /* wait until we can write to the mailbox */
    do { asm volatile("nop"); } while (*MBOX_STATUS & MBOX_FULL);
   823f4:	d2971301 	mov	x1, #0xb898                	// #47256
   823f8:	f2a7e001 	movk	x1, #0x3f00, lsl #16
int mbox_call(unsigned char ch) {
   823fc:	910003fd 	mov	x29, sp
   82400:	a90363f7 	stp	x23, x24, [sp, #48]
    unsigned int r = (((unsigned int)((unsigned long)&mbox) & ~0xF) | (ch & 0xF));
   82404:	d0000098 	adrp	x24, 94000 <_binary_font_psf_start+0x634>
int mbox_call(unsigned char ch) {
   82408:	a90153f3 	stp	x19, x20, [sp, #16]
    unsigned int r = (((unsigned int)((unsigned long)&mbox) & ~0xF) | (ch & 0xF));
   8240c:	12000c14 	and	w20, w0, #0xf
   82410:	f9414b00 	ldr	x0, [x24, #656]
int mbox_call(unsigned char ch) {
   82414:	a9025bf5 	stp	x21, x22, [sp, #32]
    unsigned int r = (((unsigned int)((unsigned long)&mbox) & ~0xF) | (ch & 0xF));
   82418:	2a000294 	orr	w20, w20, w0
    r = BUS_ADDRESS(r); 
   8241c:	32020694 	orr	w20, w20, #0xc0000000
    do { asm volatile("nop"); } while (*MBOX_STATUS & MBOX_FULL);
   82420:	d503201f 	nop
   82424:	b9400020 	ldr	w0, [x1]
   82428:	37ffffc0 	tbnz	w0, #31, 82420 <mbox_call+0x30>
    __asm__ volatile ("dmb sy" ::: "memory");    // mem barrier, ensuring msg in mem
   8242c:	d5033fbf 	dmb	sy

    /* write the address of our message to the mailbox with channel identifier */
    *MBOX_WRITE = r; 
   82430:	d2971400 	mov	x0, #0xb8a0                	// #47264
            V("r is 0x%x", r); 
            /* is it a valid successful response? (strange it's benign) */
            if (mbox[1] != MBOX_RESPONSE) I("mbox[1] is %08x", mbox[1]);            
            return mbox[1] == MBOX_RESPONSE;
        } else {
            W("got an irrelevant msg. bug?"); 
   82434:	f0000015 	adrp	x21, 85000 <get_el+0x198>
    *MBOX_WRITE = r; 
   82438:	f2a7e000 	movk	x0, #0x3f00, lsl #16
        do { asm volatile("nop"); } while (*MBOX_STATUS & MBOX_EMPTY);
   8243c:	d2971313 	mov	x19, #0xb898                	// #47256
        if (r == *MBOX_READ) {
   82440:	d2971017 	mov	x23, #0xb880                	// #47232
            W("got an irrelevant msg. bug?"); 
   82444:	910e02b5 	add	x21, x21, #0x380
        do { asm volatile("nop"); } while (*MBOX_STATUS & MBOX_EMPTY);
   82448:	f2a7e013 	movk	x19, #0x3f00, lsl #16
        if (r == *MBOX_READ) {
   8244c:	f2a7e017 	movk	x23, #0x3f00, lsl #16
            W("got an irrelevant msg. bug?"); 
   82450:	f0000016 	adrp	x22, 85000 <get_el+0x198>
    *MBOX_WRITE = r; 
   82454:	b9000014 	str	w20, [x0]
        do { asm volatile("nop"); } while (*MBOX_STATUS & MBOX_EMPTY);
   82458:	d503201f 	nop
   8245c:	b9400260 	ldr	w0, [x19]
   82460:	37f7ffc0 	tbnz	w0, #30, 82458 <mbox_call+0x68>
        if (r == *MBOX_READ) {
   82464:	b94002e3 	ldr	w3, [x23]
            W("got an irrelevant msg. bug?"); 
   82468:	aa1503e1 	mov	x1, x21
   8246c:	910ec2c0 	add	x0, x22, #0x3b0
   82470:	52800842 	mov	w2, #0x42                  	// #66
        if (r == *MBOX_READ) {
   82474:	6b14007f 	cmp	w3, w20
   82478:	54000060 	b.eq	82484 <mbox_call+0x94>  // b.none
            W("got an irrelevant msg. bug?"); 
   8247c:	97fffc49 	bl	815a0 <tfp_printf>
    while (1) {
   82480:	17fffff6 	b	82458 <mbox_call+0x68>
            if (mbox[1] != MBOX_RESPONSE) I("mbox[1] is %08x", mbox[1]);            
   82484:	f9414b00 	ldr	x0, [x24, #656]
   82488:	52b00001 	mov	w1, #0x80000000            	// #-2147483648
   8248c:	b9400402 	ldr	w2, [x0, #4]
   82490:	6b01005f 	cmp	w2, w1
   82494:	54000100 	b.eq	824b4 <mbox_call+0xc4>  // b.none
   82498:	b9400403 	ldr	w3, [x0, #4]
   8249c:	f0000001 	adrp	x1, 85000 <get_el+0x198>
   824a0:	f0000000 	adrp	x0, 85000 <get_el+0x198>
   824a4:	910e0021 	add	x1, x1, #0x380
   824a8:	910e2000 	add	x0, x0, #0x388
   824ac:	528007e2 	mov	w2, #0x3f                  	// #63
   824b0:	97fffc3c 	bl	815a0 <tfp_printf>
            return mbox[1] == MBOX_RESPONSE;
   824b4:	f9414b18 	ldr	x24, [x24, #656]
   824b8:	52b00000 	mov	w0, #0x80000000            	// #-2147483648
        }
    }
    return 0;
}
   824bc:	a94153f3 	ldp	x19, x20, [sp, #16]
            return mbox[1] == MBOX_RESPONSE;
   824c0:	b9400701 	ldr	w1, [x24, #4]
}
   824c4:	a9425bf5 	ldp	x21, x22, [sp, #32]
            return mbox[1] == MBOX_RESPONSE;
   824c8:	6b00003f 	cmp	w1, w0
   824cc:	1a9f17e0 	cset	w0, eq  // eq = none
}
   824d0:	a94363f7 	ldp	x23, x24, [sp, #48]
   824d4:	a8c47bfd 	ldp	x29, x30, [sp], #64
   824d8:	d65f03c0 	ret
   824dc:	d503201f 	nop

00000000000824e0 <fb_detect_scr_dim>:
 * Return: 0 on success.
 *
 * FXL's 720p monitor: 1360x768
 * QEMU: 640x480 (initial; subject to reconfig for larger fb)
 */
int fb_detect_scr_dim(uint *w, uint *h) {
   824e0:	a9bd7bfd 	stp	x29, x30, [sp, #-48]!
    mbox[0] = 8*4;     // size of the whole buf that follows
   824e4:	52800404 	mov	w4, #0x20                  	// #32
    mbox[1] = MBOX_REQUEST; // cpu->gpu request
        mbox[2] = 0x40003;     // rls framebuffer
   824e8:	52800063 	mov	w3, #0x3                   	// #3
int fb_detect_scr_dim(uint *w, uint *h) {
   824ec:	910003fd 	mov	x29, sp
   824f0:	a90153f3 	stp	x19, x20, [sp, #16]
    mbox[0] = 8*4;     // size of the whole buf that follows
   824f4:	d0000093 	adrp	x19, 94000 <_binary_font_psf_start+0x634>
        mbox[2] = 0x40003;     // rls framebuffer
   824f8:	72a00083 	movk	w3, #0x4, lsl #16
    mbox[0] = 8*4;     // size of the whole buf that follows
   824fc:	f9414a73 	ldr	x19, [x19, #656]
int fb_detect_scr_dim(uint *w, uint *h) {
   82500:	f90013f5 	str	x21, [sp, #32]
        mbox[3] = 8;           // total buf size
   82504:	52800102 	mov	w2, #0x8                   	// #8
int fb_detect_scr_dim(uint *w, uint *h) {
   82508:	aa0003f4 	mov	x20, x0
   8250c:	aa0103f5 	mov	x21, x1
        mbox[4] = 0;           // req para size
        mbox[5] = 0;           // resp: width
        mbox[6] = 0;           // resp: height
    mbox[7] = MBOX_TAG_LAST;

    if(!mbox_call(MBOX_CH_PROP)) {
   82510:	2a0203e0 	mov	w0, w2
    mbox[0] = 8*4;     // size of the whole buf that follows
   82514:	b9000264 	str	w4, [x19]
    mbox[1] = MBOX_REQUEST; // cpu->gpu request
   82518:	b900067f 	str	wzr, [x19, #4]
        mbox[2] = 0x40003;     // rls framebuffer
   8251c:	b9000a63 	str	w3, [x19, #8]
        mbox[3] = 8;           // total buf size
   82520:	b9000e62 	str	w2, [x19, #12]
        mbox[4] = 0;           // req para size
   82524:	b900127f 	str	wzr, [x19, #16]
        mbox[5] = 0;           // resp: width
   82528:	b900167f 	str	wzr, [x19, #20]
        mbox[6] = 0;           // resp: height
   8252c:	b9001a7f 	str	wzr, [x19, #24]
    mbox[7] = MBOX_TAG_LAST;
   82530:	b9001e7f 	str	wzr, [x19, #28]
    if(!mbox_call(MBOX_CH_PROP)) {
   82534:	97ffffaf 	bl	823f0 <mbox_call>
   82538:	34000220 	cbz	w0, 8257c <fb_detect_scr_dim+0x9c>
        E("failed to get screen dim");
        return -1;
    } 

    *w=mbox[5];*h=mbox[6]; I("detected screen dim %d %d", *w, *h);    
   8253c:	b9401660 	ldr	w0, [x19, #20]
   82540:	f0000001 	adrp	x1, 85000 <get_el+0x198>
   82544:	b9000280 	str	w0, [x20]
   82548:	910e0021 	add	x1, x1, #0x380
   8254c:	52801542 	mov	w2, #0xaa                  	// #170
   82550:	f0000000 	adrp	x0, 85000 <get_el+0x198>
   82554:	b9401a64 	ldr	w4, [x19, #24]
   82558:	91104000 	add	x0, x0, #0x410
   8255c:	b90002a4 	str	w4, [x21]
   82560:	b9400283 	ldr	w3, [x20]
   82564:	97fffc0f 	bl	815a0 <tfp_printf>
    return 0; 
   82568:	52800000 	mov	w0, #0x0                   	// #0
}
   8256c:	a94153f3 	ldp	x19, x20, [sp, #16]
   82570:	f94013f5 	ldr	x21, [sp, #32]
   82574:	a8c37bfd 	ldp	x29, x30, [sp], #48
   82578:	d65f03c0 	ret
        E("failed to get screen dim");
   8257c:	f0000001 	adrp	x1, 85000 <get_el+0x198>
   82580:	f0000000 	adrp	x0, 85000 <get_el+0x198>
   82584:	910e0021 	add	x1, x1, #0x380
   82588:	910f8000 	add	x0, x0, #0x3e0
   8258c:	528014c2 	mov	w2, #0xa6                  	// #166
   82590:	97fffc04 	bl	815a0 <tfp_printf>
        return -1;
   82594:	12800000 	mov	w0, #0xffffffff            	// #-1
   82598:	17fffff5 	b	8256c <fb_detect_scr_dim+0x8c>
   8259c:	d503201f 	nop

00000000000825a0 <fb_set_voffsets>:
/* 
 * Set virt offset
 * Caller must hold mboxlock
 * Return 0 on success 
 */
int fb_set_voffsets(int offsetx, int offsety) {
   825a0:	a9bd7bfd 	stp	x29, x30, [sp, #-48]!

    mbox[0] = 8*4;
   825a4:	52800404 	mov	w4, #0x20                  	// #32
    mbox[1] = MBOX_REQUEST;
    
    mbox[2] = 0x48009; 
   825a8:	52900123 	mov	w3, #0x8009                	// #32777
int fb_set_voffsets(int offsetx, int offsety) {
   825ac:	910003fd 	mov	x29, sp
   825b0:	a9025bf5 	stp	x21, x22, [sp, #32]
    mbox[0] = 8*4;
   825b4:	d0000096 	adrp	x22, 94000 <_binary_font_psf_start+0x634>
    mbox[2] = 0x48009; 
   825b8:	72a00083 	movk	w3, #0x4, lsl #16
int fb_set_voffsets(int offsetx, int offsety) {
   825bc:	a90153f3 	stp	x19, x20, [sp, #16]
    mbox[3] = 8;
   825c0:	52800102 	mov	w2, #0x8                   	// #8
int fb_set_voffsets(int offsetx, int offsety) {
   825c4:	2a0003f4 	mov	w20, w0
    mbox[0] = 8*4;
   825c8:	f9414ad3 	ldr	x19, [x22, #656]
int fb_set_voffsets(int offsetx, int offsety) {
   825cc:	2a0103f5 	mov	w21, w1
    mbox[5] =  offsetx;           //FrameBufferInfo.x_offset
    mbox[6] =  offsety;           //FrameBufferInfo.y.offset    

    mbox[7] = MBOX_TAG_LAST;

    if(!mbox_call(MBOX_CH_PROP)) {
   825d0:	2a0203e0 	mov	w0, w2
    mbox[0] = 8*4;
   825d4:	b9000264 	str	w4, [x19]
    mbox[1] = MBOX_REQUEST;
   825d8:	b900067f 	str	wzr, [x19, #4]
    mbox[2] = 0x48009; 
   825dc:	b9000a63 	str	w3, [x19, #8]
    mbox[3] = 8;
   825e0:	b9000e62 	str	w2, [x19, #12]
    mbox[4] = 8;
   825e4:	b9001262 	str	w2, [x19, #16]
    mbox[5] =  offsetx;           //FrameBufferInfo.x_offset
   825e8:	b9001674 	str	w20, [x19, #20]
    mbox[6] =  offsety;           //FrameBufferInfo.y.offset    
   825ec:	b9001a61 	str	w1, [x19, #24]
    mbox[7] = MBOX_TAG_LAST;
   825f0:	b9001e7f 	str	wzr, [x19, #28]
    if(!mbox_call(MBOX_CH_PROP)) {
   825f4:	97ffff7f 	bl	823f0 <mbox_call>
   825f8:	34000320 	cbz	w0, 8265c <fb_set_voffsets+0xbc>
        E("failed to set virt offsets, requested x=%d y=%d", offsetx, offsety);
        return -1;
    }     
     if (mbox[5] != offsetx || mbox[6] != offsety) {
   825fc:	b9401660 	ldr	w0, [x19, #20]
   82600:	6b00029f 	cmp	w20, w0
   82604:	54000121 	b.ne	82628 <fb_set_voffsets+0x88>  // b.any
   82608:	b9401a61 	ldr	w1, [x19, #24]
            offsetx, offsety, mbox[5], mbox[6]);
        return -1;     
     }
     V("set OK: offsetx %u offsety %u res: offsetx %u offsety %u", 
            offsetx, offsety, mbox[5], mbox[6]);
     return 0; 
   8260c:	52800000 	mov	w0, #0x0                   	// #0
     if (mbox[5] != offsetx || mbox[6] != offsety) {
   82610:	6b0102bf 	cmp	w21, w1
   82614:	540000a1 	b.ne	82628 <fb_set_voffsets+0x88>  // b.any
}
   82618:	a94153f3 	ldp	x19, x20, [sp, #16]
   8261c:	a9425bf5 	ldp	x21, x22, [sp, #32]
   82620:	a8c37bfd 	ldp	x29, x30, [sp], #48
   82624:	d65f03c0 	ret
        E("failed set: offsetx %u offsety %u res: offsetx %u offsety %u", 
   82628:	f9414ad6 	ldr	x22, [x22, #656]
   8262c:	2a1503e4 	mov	w4, w21
   82630:	2a1403e3 	mov	w3, w20
   82634:	f0000001 	adrp	x1, 85000 <get_el+0x198>
   82638:	f0000000 	adrp	x0, 85000 <get_el+0x198>
   8263c:	910e0021 	add	x1, x1, #0x380
   82640:	b94016c5 	ldr	w5, [x22, #20]
   82644:	91122000 	add	x0, x0, #0x488
   82648:	b9401ac6 	ldr	w6, [x22, #24]
   8264c:	528018a2 	mov	w2, #0xc5                  	// #197
   82650:	97fffbd4 	bl	815a0 <tfp_printf>
        return -1;     
   82654:	12800000 	mov	w0, #0xffffffff            	// #-1
   82658:	17fffff0 	b	82618 <fb_set_voffsets+0x78>
        E("failed to set virt offsets, requested x=%d y=%d", offsetx, offsety);
   8265c:	2a1503e4 	mov	w4, w21
   82660:	2a1403e3 	mov	w3, w20
   82664:	f0000001 	adrp	x1, 85000 <get_el+0x198>
   82668:	f0000000 	adrp	x0, 85000 <get_el+0x198>
   8266c:	910e0021 	add	x1, x1, #0x380
   82670:	91110000 	add	x0, x0, #0x440
   82674:	52801822 	mov	w2, #0xc1                  	// #193
   82678:	97fffbca 	bl	815a0 <tfp_printf>
        return -1;
   8267c:	12800000 	mov	w0, #0xffffffff            	// #-1
   82680:	17ffffe6 	b	82618 <fb_set_voffsets+0x78>
   82684:	d503201f 	nop

0000000000082688 <fb_fini>:
    return ret; 
}

/* Finalize the framebuffer and clean up.
    Return 0 on success (display will go blank). */
int fb_fini(void) {
   82688:	a9be7bfd 	stp	x29, x30, [sp, #-32]!
   8268c:	910003fd 	mov	x29, sp
   82690:	a90153f3 	stp	x19, x20, [sp, #16]
    int ret = 0;

    acquire(&mboxlock);
    if (!the_fb.fb || !the_fb.size) {
   82694:	b0000093 	adrp	x19, 93000 <get_el+0xe198>
    acquire(&mboxlock);
   82698:	d0000094 	adrp	x20, 94000 <_binary_font_psf_start+0x634>
   8269c:	9109c280 	add	x0, x20, #0x270
   826a0:	97fffd66 	bl	81c38 <acquire>
    if (!the_fb.fb || !the_fb.size) {
   826a4:	f944b260 	ldr	x0, [x19, #2400]
   826a8:	b4000460 	cbz	x0, 82734 <fb_fini+0xac>
   826ac:	91258261 	add	x1, x19, #0x960
   826b0:	b9403422 	ldr	w2, [x1, #52]
   826b4:	34000402 	cbz	w2, 82734 <fb_fini+0xac>
        ret = -1;
        goto out;
    }

#ifdef PLAT_RPI3QEMU // avoid artifacts: qemu does not clear old fb
    memset(the_fb.fb, 0, the_fb.size);
   826b8:	52800001 	mov	w1, #0x0                   	// #0
   826bc:	97fffc93 	bl	81908 <memset>
#endif

    mbox[0] = 6 * 4;        // size of the whole buf that follows
   826c0:	d0000081 	adrp	x1, 94000 <_binary_font_psf_start+0x634>
   826c4:	52800303 	mov	w3, #0x18                  	// #24
    mbox[1] = MBOX_REQUEST; // cpu->gpu request

    mbox[2] = 0x48001; // rls framebuffer
   826c8:	52900022 	mov	w2, #0x8001                	// #32769
    mbox[3] = 0;       // total buf size
    mbox[4] = 0;       // req para size

    mbox[5] = MBOX_TAG_LAST;

    if (!mbox_call(MBOX_CH_PROP))
   826cc:	52800100 	mov	w0, #0x8                   	// #8
    mbox[0] = 6 * 4;        // size of the whole buf that follows
   826d0:	f9414821 	ldr	x1, [x1, #656]
    mbox[2] = 0x48001; // rls framebuffer
   826d4:	72a00082 	movk	w2, #0x4, lsl #16
    mbox[0] = 6 * 4;        // size of the whole buf that follows
   826d8:	b9000023 	str	w3, [x1]
    mbox[1] = MBOX_REQUEST; // cpu->gpu request
   826dc:	b900043f 	str	wzr, [x1, #4]
    mbox[2] = 0x48001; // rls framebuffer
   826e0:	b9000822 	str	w2, [x1, #8]
    mbox[3] = 0;       // total buf size
   826e4:	b9000c3f 	str	wzr, [x1, #12]
    mbox[4] = 0;       // req para size
   826e8:	b900103f 	str	wzr, [x1, #16]
    mbox[5] = MBOX_TAG_LAST;
   826ec:	b900143f 	str	wzr, [x1, #20]
    if (!mbox_call(MBOX_CH_PROP))
   826f0:	97ffff40 	bl	823f0 <mbox_call>
   826f4:	34000120 	cbz	w0, 82718 <fb_fini+0x90>
    // wont need this until flavor simple/rich user
    // if (free_phys_region(VA2PA(the_fb.fb), the_fb.size)) {
    //     E("failed to free fb memory. bug?");
    //     ret = -2;
    // }
    the_fb.fb = 0;
   826f8:	f904b27f 	str	xzr, [x19, #2400]
    int ret = 0;
   826fc:	52800013 	mov	w19, #0x0                   	// #0
out:
    release(&mboxlock);
   82700:	9109c280 	add	x0, x20, #0x270
   82704:	97fffda5 	bl	81d98 <release>
    return ret;
}
   82708:	2a1303e0 	mov	w0, w19
   8270c:	a94153f3 	ldp	x19, x20, [sp, #16]
   82710:	a8c27bfd 	ldp	x29, x30, [sp], #32
   82714:	d65f03c0 	ret
        I("failed to rls fb with GPU.");
   82718:	f0000001 	adrp	x1, 85000 <get_el+0x198>
   8271c:	f0000000 	adrp	x0, 85000 <get_el+0x198>
   82720:	910e0021 	add	x1, x1, #0x380
   82724:	91136000 	add	x0, x0, #0x4d8
   82728:	52802a82 	mov	w2, #0x154                 	// #340
   8272c:	97fffb9d 	bl	815a0 <tfp_printf>
   82730:	17fffff2 	b	826f8 <fb_fini+0x70>
        ret = -1;
   82734:	12800013 	mov	w19, #0xffffffff            	// #-1
   82738:	17fffff2 	b	82700 <fb_fini+0x78>
   8273c:	d503201f 	nop

0000000000082740 <fb_print>:
    unsigned char *fb = the_fb.fb;

    // get our font
    psf_t *font = (psf_t *)&_binary_font_psf_start;
    // draw next character if it's not zero
    while (*s) {
   82740:	39400043 	ldrb	w3, [x2]
    unsigned pitch = the_fb.pitch;
   82744:	b0000084 	adrp	x4, 93000 <get_el+0xe198>
   82748:	91258085 	add	x5, x4, #0x960
    unsigned char *fb = the_fb.fb;
   8274c:	f944b08f 	ldr	x15, [x4, #2400]
    unsigned pitch = the_fb.pitch;
   82750:	b94018ab 	ldr	w11, [x5, #24]
    while (*s) {
   82754:	34000923 	cbz	w3, 82878 <fb_print+0x138>
void fb_print(int *x, int *y, char *s) {
   82758:	a9bd7bfd 	stp	x29, x30, [sp, #-48]!
        /* get offset of the glyph. Need to adjust this to support unicode table */
        unsigned char *glyph = (unsigned char *)&_binary_font_psf_start +
                               font->headersize + (*((unsigned char *)s) < font->numglyph ? *s : 0) * font->bytesperglyph;
   8275c:	d0000084 	adrp	x4, 94000 <_binary_font_psf_start+0x634>
            } else {
                // display a character
                for (j = 0; j < font->height; j++) {
                    // display one row
                    line = offs;
                    mask = 1 << (font->width - 1);
   82760:	5280002e 	mov	w14, #0x1                   	// #1
void fb_print(int *x, int *y, char *s) {
   82764:	910003fd 	mov	x29, sp
                               font->headersize + (*((unsigned char *)s) < font->numglyph ? *s : 0) * font->bytesperglyph;
   82768:	f9415c84 	ldr	x4, [x4, #696]
   8276c:	910011f1 	add	x17, x15, #0x4
                    for (i = 0; i < font->width; i++) {
                        // if bit set, we use white color, otherwise black
                        *((unsigned int *)(fb + line)) = ((int)*glyph) & mask ? 0xFFFFFF : 0;
   82770:	12bfe008 	mov	w8, #0xffffff              	// #16777215
void fb_print(int *x, int *y, char *s) {
   82774:	a90153f3 	stp	x19, x20, [sp, #16]
        unsigned char *glyph = (unsigned char *)&_binary_font_psf_start +
   82778:	aa0403f4 	mov	x20, x4
                               font->headersize + (*((unsigned char *)s) < font->numglyph ? *s : 0) * font->bytesperglyph;
   8277c:	b940088d 	ldr	w13, [x4, #8]
   82780:	b940109e 	ldr	w30, [x4, #16]
   82784:	b9401492 	ldr	w18, [x4, #20]
   82788:	2a0d03ed 	mov	w13, w13
        int i, j, line, mask, bytesperline = (font->width + 7) / 8;
   8278c:	b9401c8a 	ldr	w10, [x4, #28]
                for (j = 0; j < font->height; j++) {
   82790:	b9401889 	ldr	w9, [x4, #24]
        int i, j, line, mask, bytesperline = (font->width + 7) / 8;
   82794:	11001d4c 	add	w12, w10, #0x7
                    mask = 1 << (font->width - 1);
   82798:	51000550 	sub	w16, w10, #0x1
   8279c:	0b0e0153 	add	w19, w10, w14
void fb_print(int *x, int *y, char *s) {
   827a0:	a9025bf5 	stp	x21, x22, [sp, #32]
   827a4:	53037d8c 	lsr	w12, w12, #3
                    mask = 1 << (font->width - 1);
   827a8:	1ad021ce 	lsl	w14, w14, w16
   827ac:	14000009 	b	827d0 <fb_print+0x90>
            if (*s == '\n') {
   827b0:	7100287f 	cmp	w3, #0xa
   827b4:	54000281 	b.ne	82804 <fb_print+0xc4>  // b.any
                *x = 0;
   827b8:	b900001f 	str	wzr, [x0]
                *y += font->height;
   827bc:	b9400023 	ldr	w3, [x1]
   827c0:	0b090063 	add	w3, w3, w9
   827c4:	b9000023 	str	w3, [x1]
    while (*s) {
   827c8:	38401c43 	ldrb	w3, [x2, #1]!
   827cc:	34000143 	cbz	w3, 827f4 <fb_print+0xb4>
        unsigned char *glyph = (unsigned char *)&_binary_font_psf_start +
   827d0:	1b127c66 	mul	w6, w3, w18
   827d4:	6b1e007f 	cmp	w3, w30
   827d8:	8b0d00c6 	add	x6, x6, x13
   827dc:	9a8d30c6 	csel	x6, x6, x13, cc  // cc = lo, ul, last
        if (*s == '\r') {
   827e0:	7100347f 	cmp	w3, #0xd
   827e4:	54fffe61 	b.ne	827b0 <fb_print+0x70>  // b.any
            *x = 0;
   827e8:	b900001f 	str	wzr, [x0]
    while (*s) {
   827ec:	38401c43 	ldrb	w3, [x2, #1]!
   827f0:	35ffff03 	cbnz	w3, 827d0 <fb_print+0x90>
                *x += (font->width + 1);
            }
        // next character
        s++;
    }
}
   827f4:	a94153f3 	ldp	x19, x20, [sp, #16]
   827f8:	a9425bf5 	ldp	x21, x22, [sp, #32]
   827fc:	a8c37bfd 	ldp	x29, x30, [sp], #48
   82800:	d65f03c0 	ret
        int offs = (*y * pitch) + (*x * 4);
   82804:	b9400003 	ldr	w3, [x0]
                for (j = 0; j < font->height; j++) {
   82808:	34000329 	cbz	w9, 8286c <fb_print+0x12c>
        int offs = (*y * pitch) + (*x * 4);
   8280c:	b9400035 	ldr	w21, [x1]
   82810:	531e7463 	lsl	w3, w3, #2
        unsigned char *glyph = (unsigned char *)&_binary_font_psf_start +
   82814:	8b1400c6 	add	x6, x6, x20
                for (j = 0; j < font->height; j++) {
   82818:	52800016 	mov	w22, #0x0                   	// #0
        int offs = (*y * pitch) + (*x * 4);
   8281c:	1b150d75 	madd	w21, w11, w21, w3
                    for (i = 0; i < font->width; i++) {
   82820:	340001aa 	cbz	w10, 82854 <fb_print+0x114>
   82824:	93407ea3 	sxtw	x3, w21
                    mask = 1 << (font->width - 1);
   82828:	2a0e03e4 	mov	w4, w14
   8282c:	8b304867 	add	x7, x3, w16, uxtw #2
   82830:	8b0301e3 	add	x3, x15, x3
   82834:	8b1100e7 	add	x7, x7, x17
                        *((unsigned int *)(fb + line)) = ((int)*glyph) & mask ? 0xFFFFFF : 0;
   82838:	394000c5 	ldrb	w5, [x6]
   8283c:	6a0400bf 	tst	w5, w4
                        mask >>= 1;
   82840:	13017c84 	asr	w4, w4, #1
                        *((unsigned int *)(fb + line)) = ((int)*glyph) & mask ? 0xFFFFFF : 0;
   82844:	1a9f1105 	csel	w5, w8, wzr, ne  // ne = any
   82848:	b8004465 	str	w5, [x3], #4
                    for (i = 0; i < font->width; i++) {
   8284c:	eb07007f 	cmp	x3, x7
   82850:	54ffff41 	b.ne	82838 <fb_print+0xf8>  // b.any
                for (j = 0; j < font->height; j++) {
   82854:	110006d6 	add	w22, w22, #0x1
                    glyph += bytesperline;
   82858:	8b0c00c6 	add	x6, x6, x12
                for (j = 0; j < font->height; j++) {
   8285c:	6b0902df 	cmp	w22, w9
   82860:	0b0b02b5 	add	w21, w21, w11
   82864:	54fffde1 	b.ne	82820 <fb_print+0xe0>  // b.any
   82868:	b9400003 	ldr	w3, [x0]
                *x += (font->width + 1);
   8286c:	0b130063 	add	w3, w3, w19
   82870:	b9000003 	str	w3, [x0]
   82874:	17ffffd5 	b	827c8 <fb_print+0x88>
   82878:	d65f03c0 	ret
   8287c:	d503201f 	nop

0000000000082880 <fb_showpicture>:
#define IMG_DATA header_data      
#define IMG_HEIGHT height
#define IMG_WIDTH width

void fb_showpicture()
{
   82880:	a9bb7bfd 	stp	x29, x30, [sp, #-80]!
    unsigned char *ptr=the_fb.fb;
    char *data=IMG_DATA, pixel[4];
    char res[16]; 

    // fill framebuf. crop img data per the framebuf size
    unsigned int img_fb_height = the_fb.vheight < IMG_HEIGHT ? the_fb.vheight : IMG_HEIGHT; 
   82884:	52800ec9 	mov	w9, #0x76                  	// #118
    unsigned int img_fb_width = the_fb.vwidth < IMG_WIDTH ? the_fb.vwidth : IMG_WIDTH; 
   82888:	52800e88 	mov	w8, #0x74                  	// #116
{
   8288c:	910003fd 	mov	x29, sp
   82890:	a90153f3 	stp	x19, x20, [sp, #16]
    unsigned char *ptr=the_fb.fb;
   82894:	b0000093 	adrp	x19, 93000 <get_el+0xe198>
   82898:	91258267 	add	x7, x19, #0x960
   8289c:	f944b266 	ldr	x6, [x19, #2400]
{
   828a0:	a9025bf5 	stp	x21, x22, [sp, #32]

    // copy the image pixels to the start (top) of framebuf    
    ptr += (the_fb.vwidth-img_fb_width)/2*PIXELSIZE;  // top center
    ptr += (the_fb.vheight-img_fb_height)/2*the_fb.pitch; 
   828a4:	b94018e1 	ldr	w1, [x7, #24]
    unsigned int img_fb_height = the_fb.vheight < IMG_HEIGHT ? the_fb.vheight : IMG_HEIGHT; 
   828a8:	294208ea 	ldp	w10, w2, [x7, #16]
    
    // quest: OS logo
    for(y=0;y<img_fb_height;y++) {
   828ac:	b9003fff 	str	wzr, [sp, #60]
    unsigned int img_fb_height = the_fb.vheight < IMG_HEIGHT ? the_fb.vheight : IMG_HEIGHT; 
   828b0:	6b09005f 	cmp	w2, w9
   828b4:	1a899049 	csel	w9, w2, w9, ls  // ls = plast
    unsigned int img_fb_width = the_fb.vwidth < IMG_WIDTH ? the_fb.vwidth : IMG_WIDTH; 
   828b8:	6b08015f 	cmp	w10, w8
    ptr += (the_fb.vheight-img_fb_height)/2*the_fb.pitch; 
   828bc:	4b090040 	sub	w0, w2, w9
    unsigned int img_fb_width = the_fb.vwidth < IMG_WIDTH ? the_fb.vwidth : IMG_WIDTH; 
   828c0:	1a889148 	csel	w8, w10, w8, ls  // ls = plast
    ptr += (the_fb.vwidth-img_fb_width)/2*PIXELSIZE;  // top center
   828c4:	4b080143 	sub	w3, w10, w8
    ptr += (the_fb.vheight-img_fb_height)/2*the_fb.pitch; 
   828c8:	53017c00 	lsr	w0, w0, #1
    ptr += (the_fb.vwidth-img_fb_width)/2*PIXELSIZE;  // top center
   828cc:	53017c63 	lsr	w3, w3, #1
    ptr += (the_fb.vheight-img_fb_height)/2*the_fb.pitch; 
   828d0:	1b017c00 	mul	w0, w0, w1
    ptr += (the_fb.vwidth-img_fb_width)/2*PIXELSIZE;  // top center
   828d4:	531e7461 	lsl	w1, w3, #2
    ptr += (the_fb.vheight-img_fb_height)/2*the_fb.pitch; 
   828d8:	8b010000 	add	x0, x0, x1
   828dc:	8b0000c6 	add	x6, x6, x0
    for(y=0;y<img_fb_height;y++) {
   828e0:	34000622 	cbz	w2, 829a4 <fb_showpicture+0x124>
    char *data=IMG_DATA, pixel[4];
   828e4:	f0000003 	adrp	x3, 85000 <get_el+0x198>
            *((unsigned int*)ptr)=the_fb.isrgb ? *((unsigned int *)&pixel)  // !STUDENT_DONOT_SEE
                : (unsigned int)(pixel[0]<<16 | pixel[1]<<8 | pixel[2]);    // !STUDENT_DONOT_SEE
            ptr+=4;     //!STUDENT_DONOT_SEE
        }
        // advance ptr to the start of the next line of the pixels
        ptr+=the_fb.pitch-img_fb_width*4;       // !STUDENT_DONOT_SEE
   828e8:	531e750b 	lsl	w11, w8, #2
    char *data=IMG_DATA, pixel[4];
   828ec:	91142063 	add	x3, x3, #0x508
        for(x=0;x<img_fb_width;x++) {
   828f0:	b9003bff 	str	wzr, [sp, #56]
   828f4:	3400042a 	cbz	w10, 82978 <fb_showpicture+0xf8>
            HEADER_PIXEL(data, pixel);
   828f8:	39400461 	ldrb	w1, [x3, #1]
   828fc:	91001063 	add	x3, x3, #0x4
   82900:	385fc060 	ldurb	w0, [x3, #-4]
   82904:	51008421 	sub	w1, w1, #0x21
   82908:	385fe062 	ldurb	w2, [x3, #-2]
   8290c:	51008400 	sub	w0, w0, #0x21
   82910:	385ff065 	ldurb	w5, [x3, #-1]
   82914:	13047c2c 	asr	w12, w1, #4
   82918:	51008442 	sub	w2, w2, #0x21
   8291c:	2a000980 	orr	w0, w12, w0, lsl #2
   82920:	510084a5 	sub	w5, w5, #0x21
   82924:	12001c00 	and	w0, w0, #0xff
   82928:	13027c4c 	asr	w12, w2, #2
   8292c:	2a011181 	orr	w1, w12, w1, lsl #4
   82930:	2a0218a2 	orr	w2, w5, w2, lsl #6
   82934:	33001c04 	bfxil	w4, w0, #0, #8
   82938:	12001c21 	and	w1, w1, #0xff
                : (unsigned int)(pixel[0]<<16 | pixel[1]<<8 | pixel[2]);    // !STUDENT_DONOT_SEE
   8293c:	b94028e5 	ldr	w5, [x7, #40]
            HEADER_PIXEL(data, pixel);
   82940:	12001c42 	and	w2, w2, #0xff
   82944:	33181c24 	bfi	w4, w1, #8, #8
                : (unsigned int)(pixel[0]<<16 | pixel[1]<<8 | pixel[2]);    // !STUDENT_DONOT_SEE
   82948:	53185c21 	lsl	w1, w1, #8
   8294c:	2a004020 	orr	w0, w1, w0, lsl #16
   82950:	710000bf 	cmp	w5, #0x0
            HEADER_PIXEL(data, pixel);
   82954:	33101c44 	bfi	w4, w2, #16, #8
                : (unsigned int)(pixel[0]<<16 | pixel[1]<<8 | pixel[2]);    // !STUDENT_DONOT_SEE
   82958:	2a020000 	orr	w0, w0, w2
   8295c:	1a840000 	csel	w0, w0, w4, eq  // eq = none
            *((unsigned int*)ptr)=the_fb.isrgb ? *((unsigned int *)&pixel)  // !STUDENT_DONOT_SEE
   82960:	b80044c0 	str	w0, [x6], #4
        for(x=0;x<img_fb_width;x++) {
   82964:	b9403be0 	ldr	w0, [sp, #56]
   82968:	11000400 	add	w0, w0, #0x1
   8296c:	b9003be0 	str	w0, [sp, #56]
   82970:	6b08001f 	cmp	w0, w8
   82974:	54fffc23 	b.cc	828f8 <fb_showpicture+0x78>  // b.lo, b.ul, b.last
    for(y=0;y<img_fb_height;y++) {
   82978:	b9403fe0 	ldr	w0, [sp, #60]
        ptr+=the_fb.pitch-img_fb_width*4;       // !STUDENT_DONOT_SEE
   8297c:	b94018e1 	ldr	w1, [x7, #24]
    for(y=0;y<img_fb_height;y++) {
   82980:	11000400 	add	w0, w0, #0x1
   82984:	b9003fe0 	str	w0, [sp, #60]
        ptr+=the_fb.pitch-img_fb_width*4;       // !STUDENT_DONOT_SEE
   82988:	4b0b0021 	sub	w1, w1, w11
    for(y=0;y<img_fb_height;y++) {
   8298c:	6b09001f 	cmp	w0, w9
        ptr+=the_fb.pitch-img_fb_width*4;       // !STUDENT_DONOT_SEE
   82990:	8b0100c6 	add	x6, x6, x1
    for(y=0;y<img_fb_height;y++) {
   82994:	54fffae3 	b.cc	828f0 <fb_showpicture+0x70>  // b.lo, b.ul, b.last
   82998:	294208e3 	ldp	w3, w2, [x7, #16]
   8299c:	4b080063 	sub	w3, w3, w8
   829a0:	53017c63 	lsr	w3, w3, #1

    // show text strings
    // quest: OS logo. 
    // adjust x/y so that the text starts from right below the picture     
    x = (the_fb.vwidth-img_fb_width)/2;         // !STUDENT_DONOT_SEE
    y = the_fb.vheight/2 + img_fb_height/2;     // !STUDENT_DONOT_SEE
   829a4:	53017d29 	lsr	w9, w9, #1
    fb_print(&x, &y, "UVA OS");    
    sprintf(res, " %dx%d", the_fb.width, the_fb.height); // debug info 
   829a8:	91258273 	add	x19, x19, #0x960
    y = the_fb.vheight/2 + img_fb_height/2;     // !STUDENT_DONOT_SEE
   829ac:	0b420529 	add	w9, w9, w2, lsr #1
    fb_print(&x, &y, "UVA OS");    
   829b0:	9100f3f5 	add	x21, sp, #0x3c
   829b4:	9100e3f4 	add	x20, sp, #0x38
   829b8:	aa1503e1 	mov	x1, x21
   829bc:	aa1403e0 	mov	x0, x20
   829c0:	90000082 	adrp	x2, 92000 <get_el+0xd198>
   829c4:	912bc042 	add	x2, x2, #0xaf0
    y = the_fb.vheight/2 + img_fb_height/2;     // !STUDENT_DONOT_SEE
   829c8:	290727e3 	stp	w3, w9, [sp, #56]
    fb_print(&x, &y, "UVA OS");    
   829cc:	97ffff5d 	bl	82740 <fb_print>
    sprintf(res, " %dx%d", the_fb.width, the_fb.height); // debug info 
   829d0:	910103f6 	add	x22, sp, #0x40
   829d4:	29410e62 	ldp	w2, w3, [x19, #8]
   829d8:	aa1603e0 	mov	x0, x22
   829dc:	90000081 	adrp	x1, 92000 <get_el+0xd198>
   829e0:	912be021 	add	x1, x1, #0xaf8
   829e4:	97fffb53 	bl	81730 <tfp_sprintf>
    fb_print(&x, &y, res);
   829e8:	aa1603e2 	mov	x2, x22
   829ec:	aa1503e1 	mov	x1, x21
   829f0:	aa1403e0 	mov	x0, x20
   829f4:	97ffff53 	bl	82740 <fb_print>
}
   829f8:	a94153f3 	ldp	x19, x20, [sp, #16]
   829fc:	a9425bf5 	ldp	x21, x22, [sp, #32]
   82a00:	a8c57bfd 	ldp	x29, x30, [sp], #80
   82a04:	d65f03c0 	ret

0000000000082a08 <fb_init>:
int fb_init(void) {
   82a08:	d10143ff 	sub	sp, sp, #0x50
   82a0c:	a9017bfd 	stp	x29, x30, [sp, #16]
   82a10:	910043fd 	add	x29, sp, #0x10
   82a14:	a90463f7 	stp	x23, x24, [sp, #64]
    mbox[0] = 35 * 4;       // size of the whole buf that follows
   82a18:	d0000097 	adrp	x23, 94000 <_binary_font_psf_start+0x634>
int fb_init(void) {
   82a1c:	a90253f3 	stp	x19, x20, [sp, #32]
   82a20:	a9035bf5 	stp	x21, x22, [sp, #48]
    acquire(&mboxlock);
   82a24:	d0000096 	adrp	x22, 94000 <_binary_font_psf_start+0x634>
   82a28:	9109c2c0 	add	x0, x22, #0x270
   82a2c:	97fffc83 	bl	81c38 <acquire>
    mbox[5] = fbs->width;  //(val) FrameBufferInfo.width
   82a30:	b0000095 	adrp	x21, 93000 <get_el+0xe198>
    mbox[0] = 35 * 4;       // size of the whole buf that follows
   82a34:	f9414af3 	ldr	x19, [x23, #656]
   82a38:	52801182 	mov	w2, #0x8c                  	// #140
    mbox[5] = fbs->width;  //(val) FrameBufferInfo.width
   82a3c:	912582b4 	add	x20, x21, #0x960
    mbox[2] = 0x48003;     // set phy width & height
   82a40:	52900060 	mov	w0, #0x8003                	// #32771
   82a44:	72a00080 	movk	w0, #0x4, lsl #16
    mbox[3] = 8;           // total buf size of this tag
   82a48:	52800101 	mov	w1, #0x8                   	// #8
    mbox[0] = 35 * 4;       // size of the whole buf that follows
   82a4c:	b9000262 	str	w2, [x19]
    mbox[7] = 0x48004; // set virt width & height
   82a50:	52900089 	mov	w9, #0x8004                	// #32772
    mbox[1] = MBOX_REQUEST; // cpu->gpu request
   82a54:	b900067f 	str	wzr, [x19, #4]
    mbox[7] = 0x48004; // set virt width & height
   82a58:	72a00089 	movk	w9, #0x4, lsl #16
    mbox[2] = 0x48003;     // set phy width & height
   82a5c:	b9000a60 	str	w0, [x19, #8]
    mbox[12] = 0x48009; // set virt offset
   82a60:	52900128 	mov	w8, #0x8009                	// #32777
    mbox[3] = 8;           // total buf size of this tag
   82a64:	b9000e61 	str	w1, [x19, #12]
    mbox[12] = 0x48009; // set virt offset
   82a68:	72a00088 	movk	w8, #0x4, lsl #16
    mbox[5] = fbs->width;  //(val) FrameBufferInfo.width
   82a6c:	b9400a80 	ldr	w0, [x20, #8]
    mbox[17] = 0x48005; // set depth
   82a70:	529000a7 	mov	w7, #0x8005                	// #32773
    mbox[4] = 8;           // req val size (needed?), to be overwritten as resp val size
   82a74:	b9001261 	str	w1, [x19, #16]
    mbox[17] = 0x48005; // set depth
   82a78:	72a00087 	movk	w7, #0x4, lsl #16
    mbox[5] = fbs->width;  //(val) FrameBufferInfo.width
   82a7c:	b9001660 	str	w0, [x19, #20]
    mbox[18] = 4;
   82a80:	52800082 	mov	w2, #0x4                   	// #4
    mbox[6] = fbs->height; //(val) FrameBufferInfo.height
   82a84:	b9400e80 	ldr	w0, [x20, #12]
    mbox[21] = 0x48006; // set pixel order
   82a88:	529000c6 	mov	w6, #0x8006                	// #32774
    mbox[6] = fbs->height; //(val) FrameBufferInfo.height
   82a8c:	b9001a60 	str	w0, [x19, #24]
    mbox[21] = 0x48006; // set pixel order
   82a90:	72a00086 	movk	w6, #0x4, lsl #16
    mbox[7] = 0x48004; // set virt width & height
   82a94:	b9001e69 	str	w9, [x19, #28]
    mbox[25] = 0x40001; // get framebuffer, gets alignment on request
   82a98:	52800025 	mov	w5, #0x1                   	// #1
    mbox[8] = 8;
   82a9c:	b9002261 	str	w1, [x19, #32]
    mbox[25] = 0x40001; // get framebuffer, gets alignment on request
   82aa0:	72a00085 	movk	w5, #0x4, lsl #16
    mbox[10] = fbs->vwidth;  // FrameBufferInfo.virtual_width
   82aa4:	b9401289 	ldr	w9, [x20, #16]
    mbox[28] = 4096; // req: alignment; resp: FrameBufferInfo.pointer
   82aa8:	52820004 	mov	w4, #0x1000                	// #4096
    mbox[9] = 8;
   82aac:	b9002661 	str	w1, [x19, #36]
    mbox[30] = 0x40008; // get pitch
   82ab0:	52800103 	mov	w3, #0x8                   	// #8
    mbox[10] = fbs->vwidth;  // FrameBufferInfo.virtual_width
   82ab4:	b9002a69 	str	w9, [x19, #40]
    mbox[30] = 0x40008; // get pitch
   82ab8:	72a00083 	movk	w3, #0x4, lsl #16
    mbox[11] = fbs->vheight; // FrameBufferInfo.virtual_height
   82abc:	b9401689 	ldr	w9, [x20, #20]
    if(mbox_call(MBOX_CH_PROP) 
   82ac0:	2a0103e0 	mov	w0, w1
    mbox[11] = fbs->vheight; // FrameBufferInfo.virtual_height
   82ac4:	b9002e69 	str	w9, [x19, #44]
    mbox[12] = 0x48009; // set virt offset
   82ac8:	b9003268 	str	w8, [x19, #48]
    mbox[13] = 8;
   82acc:	b9003661 	str	w1, [x19, #52]
    mbox[15] = fbs->offsetx;
   82ad0:	b9402e88 	ldr	w8, [x20, #44]
    mbox[14] = 8;
   82ad4:	b9003a61 	str	w1, [x19, #56]
    mbox[15] = fbs->offsetx;
   82ad8:	b9003e68 	str	w8, [x19, #60]
    mbox[16] = fbs->offsety;
   82adc:	b9403288 	ldr	w8, [x20, #48]
   82ae0:	b9004268 	str	w8, [x19, #64]
    mbox[17] = 0x48005; // set depth
   82ae4:	b9004667 	str	w7, [x19, #68]
    mbox[18] = 4;
   82ae8:	b9004a62 	str	w2, [x19, #72]
    mbox[20] = fbs->depth;
   82aec:	b9402687 	ldr	w7, [x20, #36]
    mbox[19] = 4;
   82af0:	b9004e62 	str	w2, [x19, #76]
    mbox[20] = fbs->depth;
   82af4:	b9005267 	str	w7, [x19, #80]
    mbox[21] = 0x48006; // set pixel order
   82af8:	b9005666 	str	w6, [x19, #84]
    mbox[22] = 4;
   82afc:	b9005a62 	str	w2, [x19, #88]
    mbox[23] = 4;
   82b00:	b9005e62 	str	w2, [x19, #92]
    mbox[24] = fbs->isrgb; // RGB, not BGR preferably
   82b04:	b9402a86 	ldr	w6, [x20, #40]
   82b08:	b9006266 	str	w6, [x19, #96]
    mbox[25] = 0x40001; // get framebuffer, gets alignment on request
   82b0c:	b9006665 	str	w5, [x19, #100]
    mbox[26] = 8;
   82b10:	b9006a61 	str	w1, [x19, #104]
    mbox[27] = 8;    // should be 4?? (req para size)
   82b14:	b9006e61 	str	w1, [x19, #108]
    mbox[28] = 4096; // req: alignment; resp: FrameBufferInfo.pointer
   82b18:	b9007264 	str	w4, [x19, #112]
    mbox[29] = 0;    // resp: FrameBufferInfo.size
   82b1c:	b900767f 	str	wzr, [x19, #116]
    mbox[30] = 0x40008; // get pitch
   82b20:	b9007a63 	str	w3, [x19, #120]
    mbox[31] = 4;
   82b24:	b9007e62 	str	w2, [x19, #124]
    mbox[32] = 4;
   82b28:	b9008262 	str	w2, [x19, #128]
    mbox[33] = 0; // FrameBufferInfo.pitch
   82b2c:	b900867f 	str	wzr, [x19, #132]
    mbox[34] = MBOX_TAG_LAST; // the end of tag seq
   82b30:	b9008a7f 	str	wzr, [x19, #136]
    if(mbox_call(MBOX_CH_PROP) 
   82b34:	97fffe2f 	bl	823f0 <mbox_call>
   82b38:	34000a20 	cbz	w0, 82c7c <fb_init+0x274>
        && mbox[20]==fbs->depth /*depth*/ 
   82b3c:	b9405261 	ldr	w1, [x19, #80]
   82b40:	b9402680 	ldr	w0, [x20, #36]
   82b44:	6b00003f 	cmp	w1, w0
   82b48:	540009a1 	b.ne	82c7c <fb_init+0x274>  // b.any
        && mbox[28]!=0 /*framebuf*/) {
   82b4c:	b9407260 	ldr	w0, [x19, #112]
   82b50:	34000960 	cbz	w0, 82c7c <fb_init+0x274>
        mbox[28]&=0x3FFFFFFF;  
   82b54:	b9407260 	ldr	w0, [x19, #112]
   82b58:	f0000018 	adrp	x24, 85000 <get_el+0x198>
   82b5c:	12007400 	and	w0, w0, #0x3fffffff
   82b60:	b9007260 	str	w0, [x19, #112]
        fbs->fb = (unsigned char *)((unsigned long)mbox[28]);       // !STUDENT_DONOT_SEE
   82b64:	b9407260 	ldr	w0, [x19, #112]
        fbs->width=mbox[5];
   82b68:	b9401664 	ldr	w4, [x19, #20]
        fbs->height=mbox[6];    // !STUDENT_DONOT_SEE
   82b6c:	b9401a65 	ldr	w5, [x19, #24]
        fbs->fb = (unsigned char *)((unsigned long)mbox[28]);       // !STUDENT_DONOT_SEE
   82b70:	2a0003e0 	mov	w0, w0
        fbs->vwidth=mbox[10];
   82b74:	b9402a66 	ldr	w6, [x19, #40]
        fbs->vheight=mbox[11];        
   82b78:	b9402e67 	ldr	w7, [x19, #44]
        fbs->depth=mbox[20]; 
   82b7c:	b9405261 	ldr	w1, [x19, #80]
        fbs->isrgb=mbox[24];     // channel order        
   82b80:	b9406268 	ldr	w8, [x19, #96]
        fbs->pitch=mbox[33];    // !STUDENT_DONOT_SEE
   82b84:	b9408662 	ldr	w2, [x19, #132]
        if(fbs->pitch * fbs->vheight > mbox[29])  // possible that pitch*vheight < actual allocation
   82b88:	b9407663 	ldr	w3, [x19, #116]
        fbs->fb = (unsigned char *)((unsigned long)mbox[28]);       // !STUDENT_DONOT_SEE
   82b8c:	f904b2a0 	str	x0, [x21, #2400]
        fbs->height=mbox[6];    // !STUDENT_DONOT_SEE
   82b90:	29011684 	stp	w4, w5, [x20, #8]
        if(fbs->pitch * fbs->vheight > mbox[29])  // possible that pitch*vheight < actual allocation
   82b94:	1b027ce0 	mul	w0, w7, w2
        fbs->vheight=mbox[11];        
   82b98:	29021e86 	stp	w6, w7, [x20, #16]
        fbs->pitch=mbox[33];    // !STUDENT_DONOT_SEE
   82b9c:	b9001a82 	str	w2, [x20, #24]
        fbs->isrgb=mbox[24];     // channel order        
   82ba0:	2904a281 	stp	w1, w8, [x20, #36]
        if(fbs->pitch * fbs->vheight > mbox[29])  // possible that pitch*vheight < actual allocation
   82ba4:	6b03001f 	cmp	w0, w3
   82ba8:	54000308 	b.hi	82c08 <fb_init+0x200>  // b.pmore
        I("OK. fb pa: 0x%08x w %u h %u vw %u vh %u pitch %u isrgb %u", 
   82bac:	f9414af7 	ldr	x23, [x23, #656]
        fbs->size = PGROUNDUP(fbs->pitch * fbs->vheight);  // roundup b/c we'll reserve pages for it
   82bb0:	113ffc00 	add	w0, w0, #0xfff
   82bb4:	912582b5 	add	x21, x21, #0x960
        I("OK. fb pa: 0x%08x w %u h %u vw %u vh %u pitch %u isrgb %u", 
   82bb8:	910e0301 	add	x1, x24, #0x380
   82bbc:	b94072e3 	ldr	w3, [x23, #112]
   82bc0:	b9000be8 	str	w8, [sp, #8]
        fbs->size = PGROUNDUP(fbs->pitch * fbs->vheight);  // roundup b/c we'll reserve pages for it
   82bc4:	12144c08 	and	w8, w0, #0xfffff000
        I("OK. fb pa: 0x%08x w %u h %u vw %u vh %u pitch %u isrgb %u", 
   82bc8:	b90003e2 	str	w2, [sp]
   82bcc:	52802482 	mov	w2, #0x124                 	// #292
   82bd0:	90000080 	adrp	x0, 92000 <get_el+0xd198>
   82bd4:	912ce000 	add	x0, x0, #0xb38
        fbs->size = PGROUNDUP(fbs->pitch * fbs->vheight);  // roundup b/c we'll reserve pages for it
   82bd8:	b90036a8 	str	w8, [x21, #52]
        I("OK. fb pa: 0x%08x w %u h %u vw %u vh %u pitch %u isrgb %u", 
   82bdc:	97fffa71 	bl	815a0 <tfp_printf>
    release(&mboxlock); 
   82be0:	9109c2c0 	add	x0, x22, #0x270
   82be4:	97fffc6d 	bl	81d98 <release>
    if (ret==0 && once)
   82be8:	b9403aa0 	ldr	w0, [x21, #56]
   82bec:	35000360 	cbnz	w0, 82c58 <fb_init+0x250>
}
   82bf0:	a9417bfd 	ldp	x29, x30, [sp, #16]
   82bf4:	a94253f3 	ldp	x19, x20, [sp, #32]
   82bf8:	a9435bf5 	ldp	x21, x22, [sp, #48]
   82bfc:	a94463f7 	ldp	x23, x24, [sp, #64]
   82c00:	910143ff 	add	sp, sp, #0x50
   82c04:	d65f03c0 	ret
            {W("pitch %d x vheight %d!= mbox[29] %u", fbs->pitch, fbs->vheight, mbox[29]);BUG();}
   82c08:	b9407665 	ldr	w5, [x19, #116]
   82c0c:	2a0703e4 	mov	w4, w7
   82c10:	2a0203e3 	mov	w3, w2
   82c14:	910e0313 	add	x19, x24, #0x380
   82c18:	aa1303e1 	mov	x1, x19
   82c1c:	52802442 	mov	w2, #0x122                 	// #290
   82c20:	90000080 	adrp	x0, 92000 <get_el+0xd198>
   82c24:	912c0000 	add	x0, x0, #0xb00
   82c28:	97fffa5e 	bl	815a0 <tfp_printf>
   82c2c:	52802442 	mov	w2, #0x122                 	// #290
   82c30:	aa1303e1 	mov	x1, x19
   82c34:	d0000000 	adrp	x0, 84000 <vectors>
   82c38:	913ce000 	add	x0, x0, #0xf38
   82c3c:	97fffb27 	bl	818d8 <assertion_failed>
   82c40:	29421e86 	ldp	w6, w7, [x20, #16]
   82c44:	b9401a82 	ldr	w2, [x20, #24]
   82c48:	29411684 	ldp	w4, w5, [x20, #8]
   82c4c:	b9402a88 	ldr	w8, [x20, #40]
   82c50:	1b077c40 	mul	w0, w2, w7
   82c54:	17ffffd6 	b	82bac <fb_init+0x1a4>
        {fb_showpicture(); once=0;}
   82c58:	97ffff0a 	bl	82880 <fb_showpicture>
   82c5c:	b9003abf 	str	wzr, [x21, #56]
    return 0;
   82c60:	52800000 	mov	w0, #0x0                   	// #0
}
   82c64:	a9417bfd 	ldp	x29, x30, [sp, #16]
   82c68:	a94253f3 	ldp	x19, x20, [sp, #32]
   82c6c:	a9435bf5 	ldp	x21, x22, [sp, #48]
   82c70:	a94463f7 	ldp	x23, x24, [sp, #64]
   82c74:	910143ff 	add	sp, sp, #0x50
   82c78:	d65f03c0 	ret
        E("Unable to set scr res to %d x %d\n", fbs->width, fbs->height);
   82c7c:	912582b5 	add	x21, x21, #0x960
   82c80:	f0000001 	adrp	x1, 85000 <get_el+0x198>
   82c84:	90000080 	adrp	x0, 92000 <get_el+0xd198>
   82c88:	910e0021 	add	x1, x1, #0x380
   82c8c:	912e2000 	add	x0, x0, #0xb88
   82c90:	52802502 	mov	w2, #0x128                 	// #296
   82c94:	294112a3 	ldp	w3, w4, [x21, #8]
   82c98:	97fffa42 	bl	815a0 <tfp_printf>
        return -2; 
   82c9c:	12800020 	mov	w0, #0xfffffffe            	// #-2
   82ca0:	17ffffd4 	b	82bf0 <fb_init+0x1e8>
   82ca4:	00000000 	udf	#0

0000000000082ca8 <canvas_init>:
static inline void setpixel(unsigned char *buf, int x, int y, int pit, PIXEL p) {
    assert(x >= 0 && y >= 0);
    *(PIXEL *)(buf + y * pit + x * PIXELSIZE) = p;
}

static void canvas_init(void) {
   82ca8:	a9bf7bfd 	stp	x29, x30, [sp, #-16]!
   82cac:	910003fd 	mov	x29, sp
    fb_fini();
   82cb0:	97fffe76 	bl	82688 <fb_fini>
    // acquire(&mboxlock);      //it's a test. so no lock

    the_fb.width = NN;
   82cb4:	d0000080 	adrp	x0, 94000 <_binary_font_psf_start+0x634>
   82cb8:	d2805001 	mov	x1, #0x280                 	// #640
   82cbc:	f2c05001 	movk	x1, #0x280, lsl #32
   82cc0:	f9415400 	ldr	x0, [x0, #680]
    the_fb.height = NN;

    the_fb.vwidth = NN;
   82cc4:	a9008401 	stp	x1, x1, [x0, #8]
    the_fb.vheight = NN;

    if (fb_init() != 0)
   82cc8:	97ffff50 	bl	82a08 <fb_init>
   82ccc:	35000060 	cbnz	w0, 82cd8 <canvas_init+0x30>
        BUG();
}
   82cd0:	a8c17bfd 	ldp	x29, x30, [sp], #16
   82cd4:	d65f03c0 	ret
   82cd8:	a8c17bfd 	ldp	x29, x30, [sp], #16
        BUG();
   82cdc:	90000081 	adrp	x1, 92000 <get_el+0xd198>
   82ce0:	d0000000 	adrp	x0, 84000 <vectors>
   82ce4:	912f4021 	add	x1, x1, #0xbd0
   82ce8:	913ce000 	add	x0, x0, #0xf38
   82cec:	528004a2 	mov	w2, #0x25                  	// #37
   82cf0:	17fffafa 	b	818d8 <assertion_failed>
   82cf4:	d503201f 	nop

0000000000082cf8 <draw_frame>:
static int _;

static PIXEL int2rgb (int value); 

// ktimer callback. NB: called in irq context
static int draw_frame(TKernelTimerHandle hTimer, void *param, void *context) {    
   82cf8:	a9b97bfd 	stp	x29, x30, [sp, #-112]!
    memset(b, 0, 1760);  // text buffer 0: black bkgnd
   82cfc:	d0000080 	adrp	x0, 94000 <_binary_font_psf_start+0x634>
   82d00:	91194003 	add	x3, x0, #0x650
static int draw_frame(TKernelTimerHandle hTimer, void *param, void *context) {    
   82d04:	910003fd 	mov	x29, sp
    memset(b, 0, 1760);  // text buffer 0: black bkgnd
   82d08:	aa0303e0 	mov	x0, x3
   82d0c:	5280dc02 	mov	w2, #0x6e0                 	// #1760
   82d10:	52800001 	mov	w1, #0x0                   	// #0
static int draw_frame(TKernelTimerHandle hTimer, void *param, void *context) {    
   82d14:	a90153f3 	stp	x19, x20, [sp, #16]
   82d18:	a9025bf5 	stp	x21, x22, [sp, #32]
   82d1c:	52801ff6 	mov	w22, #0xff                  	// #255
   82d20:	a90363f7 	stp	x23, x24, [sp, #48]
    memset(z, 127, 1760); // z buffer
   82d24:	911b8078 	add	x24, x3, #0x6e0
                x = 25 + 30 * (cB * x1 - sB * x4) / x6,
                y = 12 + 15 * (cB * x4 + sB * x1) / x6,
                // N = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5) >> 7;
                lumince = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5); 
                // range likely: <0..~1408, scale to 0..255
                lumince = lumince<0? 0 : lumince/5; 
   82d28:	528cccf7 	mov	w23, #0x6667                	// #26215
static int draw_frame(TKernelTimerHandle hTimer, void *param, void *context) {    
   82d2c:	a9046bf9 	stp	x25, x26, [sp, #64]
                lumince = lumince<0? 0 : lumince/5; 
   82d30:	72acccd7 	movk	w23, #0x6666, lsl #16
    int sj = 0, cj = 1024;
   82d34:	52808019 	mov	w25, #0x400                 	// #1024
static int draw_frame(TKernelTimerHandle hTimer, void *param, void *context) {    
   82d38:	a90573fb 	stp	x27, x28, [sp, #80]
                lumince = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5); 
   82d3c:	52800b5c 	mov	w28, #0x5a                  	// #90
    int sj = 0, cj = 1024;
   82d40:	5280001b 	mov	w27, #0x0                   	// #0
    memset(z, 127, 1760); // z buffer
   82d44:	f90037e3 	str	x3, [sp, #104]
    memset(b, 0, 1760);  // text buffer 0: black bkgnd
   82d48:	97fffaf0 	bl	81908 <memset>
    memset(z, 127, 1760); // z buffer
   82d4c:	52800fe1 	mov	w1, #0x7f                  	// #127
   82d50:	aa1803e0 	mov	x0, x24
   82d54:	5280dc02 	mov	w2, #0x6e0                 	// #1760
   82d58:	97fffaec 	bl	81908 <memset>
                x2 = cA * sj >> 10,
   82d5c:	f94037e3 	ldr	x3, [sp, #104]
                x4 = R1 * x2 - (sA * x3 >> 10),
   82d60:	b0000080 	adrp	x0, 93000 <get_el+0xe198>
   82d64:	b0000081 	adrp	x1, 93000 <get_el+0xe198>
   82d68:	91267000 	add	x0, x0, #0x99c
                lumince = lumince<255? lumince : 255; 

            int o = x + 80 * y; // fxl: 80 chars per row
            signed char zz = (x6 - K2) >> 15;
            if (22 > y && y > 0 && x > 0 && 80 > x && zz < z[o]) { // fxl: z depth will control visibility
   82d6c:	aa0303fa 	mov	x26, x3
                // now we lookup the character corresponding to the
                // luminance and plot it in our output:
                // b[o] = ".,-~:;=!*#$@"[N > 0 ? N : 0];
                b[o] = lumince;                    
            }
            R(5, 8, ci, si) // rotate i
   82d70:	52a00612 	mov	w18, #0x300000              	// #3145728
                x4 = R1 * x2 - (sA * x3 >> 10),
   82d74:	b9499c3e 	ldr	w30, [x1, #2460]
                x2 = cA * sj >> 10,
   82d78:	b94dc073 	ldr	w19, [x3, #3520]
                x = 25 + 30 * (cB * x1 - sB * x4) / x6,
   82d7c:	b940040e 	ldr	w14, [x0, #4]
                lumince = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5); 
   82d80:	4b1e03f4 	neg	w20, w30
                x = 25 + 30 * (cB * x1 - sB * x4) / x6,
   82d84:	b94dc46b 	ldr	w11, [x3, #3524]
                lumince = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5); 
   82d88:	4b1303f5 	neg	w21, w19
                x5 = sA * sj >> 10,
   82d8c:	1b1b7fc7 	mul	w7, w30, w27
        int si = 0, ci = 1024; // sine and cosine of angle i
   82d90:	52808000 	mov	w0, #0x400                 	// #1024
                x2 = cA * sj >> 10,
   82d94:	1b1b7e68 	mul	w8, w19, w27
   82d98:	11200329 	add	w9, w25, #0x800
                lumince = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5); 
   82d9c:	1b197dca 	mul	w10, w14, w25
                x6 = K2 + R1 * 1024 * x5 + cA * x3,
   82da0:	121654ec 	and	w12, w7, #0xfffffc00
   82da4:	1154018c 	add	w12, w12, #0x500, lsl #12
                x5 = sA * sj >> 10,
   82da8:	130a7ce7 	asr	w7, w7, #10
                x2 = cA * sj >> 10,
   82dac:	130a7d08 	asr	w8, w8, #10
   82db0:	2a0003ed 	mov	w13, w0
                lumince = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5); 
   82db4:	130a7d4a 	asr	w10, w10, #10
   82db8:	52802886 	mov	w6, #0x144                 	// #324
        int si = 0, ci = 1024; // sine and cosine of angle i
   82dbc:	52800001 	mov	w1, #0x0                   	// #0
                x3 = si * x0 >> 10,
   82dc0:	1b097c23 	mul	w3, w1, w9
            R(5, 8, ci, si) // rotate i
   82dc4:	0b010830 	add	w16, w1, w1, lsl #2
                x1 = ci * x0 >> 10,
   82dc8:	1b097db1 	mul	w17, w13, w9
            R(5, 8, ci, si) // rotate i
   82dcc:	0b0d09a2 	add	w2, w13, w13, lsl #2
   82dd0:	4b9021b0 	sub	w16, w13, w16, asr #8
                x7 = cj * si >> 10,
   82dd4:	4b012c64 	sub	w4, w3, w1, lsl #11
                x3 = si * x0 >> 10,
   82dd8:	130a7c63 	asr	w3, w3, #10
            R(5, 8, ci, si) // rotate i
   82ddc:	0b822021 	add	w1, w1, w2, asr #8
                x1 = ci * x0 >> 10,
   82de0:	130a7e31 	asr	w17, w17, #10
                x7 = cj * si >> 10,
   82de4:	130a7c84 	asr	w4, w4, #10
            R(5, 8, ci, si) // rotate i
   82de8:	1b10ca02 	msub	w2, w16, w16, w18
                x4 = R1 * x2 - (sA * x3 >> 10),
   82dec:	1b037fc5 	mul	w5, w30, w3
                x = 25 + 30 * (cB * x1 - sB * x4) / x6,
   82df0:	1b117d6f 	mul	w15, w11, w17
                lumince = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5); 
   82df4:	1b047e80 	mul	w0, w20, w4
                x4 = R1 * x2 - (sA * x3 >> 10),
   82df8:	4b852905 	sub	w5, w8, w5, asr #10
            R(5, 8, ci, si) // rotate i
   82dfc:	1b018822 	msub	w2, w1, w1, w2
                y = 12 + 15 * (cB * x4 + sB * x1) / x6,
   82e00:	1b117dd1 	mul	w17, w14, w17
                lumince = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5); 
   82e04:	0b802900 	add	w0, w8, w0, asr #10
   82e08:	1b047ea4 	mul	w4, w21, w4
                x = 25 + 30 * (cB * x1 - sB * x4) / x6,
   82e0c:	1b05bdcf 	msub	w15, w14, w5, w15
            R(5, 8, ci, si) // rotate i
   82e10:	130b7c42 	asr	w2, w2, #11
                y = 12 + 15 * (cB * x4 + sB * x1) / x6,
   82e14:	1b054565 	madd	w5, w11, w5, w17
                lumince = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5); 
   82e18:	1b0b9000 	msub	w0, w0, w11, w4
   82e1c:	52800004 	mov	w4, #0x0                   	// #0
                x = 25 + 30 * (cB * x1 - sB * x4) / x6,
   82e20:	531c6df1 	lsl	w17, w15, #4
                lumince = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5); 
   82e24:	1b0d8140 	msub	w0, w10, w13, w0
                x = 25 + 30 * (cB * x1 - sB * x4) / x6,
   82e28:	4b0f022f 	sub	w15, w17, w15
                x6 = K2 + R1 * 1024 * x5 + cA * x3,
   82e2c:	1b033263 	madd	w3, w19, w3, w12
                y = 12 + 15 * (cB * x4 + sB * x1) / x6,
   82e30:	531c6cb1 	lsl	w17, w5, #4
            R(5, 8, ci, si) // rotate i
   82e34:	1b107c4d 	mul	w13, w2, w16
                y = 12 + 15 * (cB * x4 + sB * x1) / x6,
   82e38:	4b050225 	sub	w5, w17, w5
                lumince = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5); 
   82e3c:	130a7c00 	asr	w0, w0, #10
            R(5, 8, ci, si) // rotate i
   82e40:	1b017c41 	mul	w1, w2, w1
                x = 25 + 30 * (cB * x1 - sB * x4) / x6,
   82e44:	531f79ef 	lsl	w15, w15, #1
                lumince = lumince<0? 0 : lumince/5; 
   82e48:	6b070000 	subs	w0, w0, w7
            R(5, 8, ci, si) // rotate i
   82e4c:	130a7dad 	asr	w13, w13, #10
                y = 12 + 15 * (cB * x4 + sB * x1) / x6,
   82e50:	1ac30ca5 	sdiv	w5, w5, w3
                lumince = lumince<0? 0 : lumince/5; 
   82e54:	540000c4 	b.mi	82e6c <draw_frame+0x174>  // b.first
   82e58:	9b377c04 	smull	x4, w0, w23
   82e5c:	9361fc84 	asr	x4, x4, #33
   82e60:	4b807c84 	sub	w4, w4, w0, asr #31
   82e64:	7103fc9f 	cmp	w4, #0xff
   82e68:	1a96d084 	csel	w4, w4, w22, le
            if (22 > y && y > 0 && x > 0 && 80 > x && zz < z[o]) { // fxl: z depth will control visibility
   82e6c:	11002ca0 	add	w0, w5, #0xb
            R(5, 8, ci, si) // rotate i
   82e70:	130a7c21 	asr	w1, w1, #10
            if (22 > y && y > 0 && x > 0 && 80 > x && zz < z[o]) { // fxl: z depth will control visibility
   82e74:	7100501f 	cmp	w0, #0x14
   82e78:	54000208 	b.hi	82eb8 <draw_frame+0x1c0>  // b.pmore
                x = 25 + 30 * (cB * x1 - sB * x4) / x6,
   82e7c:	1ac30def 	sdiv	w15, w15, w3
                y = 12 + 15 * (cB * x4 + sB * x1) / x6,
   82e80:	110030a2 	add	w2, w5, #0xc
            signed char zz = (x6 - K2) >> 15;
   82e84:	51540063 	sub	w3, w3, #0x500, lsl #12
            int o = x + 80 * y; // fxl: 80 chars per row
   82e88:	0b020842 	add	w2, w2, w2, lsl #2
            signed char zz = (x6 - K2) >> 15;
   82e8c:	934f5863 	sbfx	x3, x3, #15, #8
                x = 25 + 30 * (cB * x1 - sB * x4) / x6,
   82e90:	110065e0 	add	w0, w15, #0x19
            if (22 > y && y > 0 && x > 0 && 80 > x && zz < z[o]) { // fxl: z depth will control visibility
   82e94:	110061ef 	add	w15, w15, #0x18
   82e98:	710139ff 	cmp	w15, #0x4e
   82e9c:	540000e8 	b.hi	82eb8 <draw_frame+0x1c0>  // b.pmore
            int o = x + 80 * y; // fxl: 80 chars per row
   82ea0:	0b021002 	add	w2, w0, w2, lsl #4
            if (22 > y && y > 0 && x > 0 && 80 > x && zz < z[o]) { // fxl: z depth will control visibility
   82ea4:	38e2cb00 	ldrsb	w0, [x24, w2, sxtw]
   82ea8:	6b03001f 	cmp	w0, w3
   82eac:	5400006d 	b.le	82eb8 <draw_frame+0x1c0>
                z[o] = zz;
   82eb0:	3822cb03 	strb	w3, [x24, w2, sxtw]
                b[o] = lumince;                    
   82eb4:	3822cb44 	strb	w4, [x26, w2, sxtw]
        for (int i = 0; i < 324; i++) {
   82eb8:	710004c6 	subs	w6, w6, #0x1
   82ebc:	54fff821 	b.ne	82dc0 <draw_frame+0xc8>  // b.any
        }
        R(9, 7, cj, sj) // rotate j
   82ec0:	0b1b0f60 	add	w0, w27, w27, lsl #3
   82ec4:	0b190f21 	add	w1, w25, w25, lsl #3
    for (int j = 0; j < 90; j++) {
   82ec8:	7100079c 	subs	w28, w28, #0x1
        R(9, 7, cj, sj) // rotate j
   82ecc:	4b801f39 	sub	w25, w25, w0, asr #7
   82ed0:	0b811f7b 	add	w27, w27, w1, asr #7
   82ed4:	1b19cb20 	msub	w0, w25, w25, w18
   82ed8:	1b1b8360 	msub	w0, w27, w27, w0
   82edc:	130b7c00 	asr	w0, w0, #11
   82ee0:	1b197c19 	mul	w25, w0, w25
   82ee4:	1b1b7c00 	mul	w0, w0, w27
   82ee8:	130a7f39 	asr	w25, w25, #10
   82eec:	130a7c1b 	asr	w27, w0, #10
    for (int j = 0; j < 90; j++) {
   82ef0:	54fff4e1 	b.ne	82d8c <draw_frame+0x94>  // b.any
    }
    R(5, 7, cA, sA);
    R(5, 8, cB, sB);
   82ef4:	0b0e09c0 	add	w0, w14, w14, lsl #2
    R(5, 7, cA, sA);
   82ef8:	0b1e0bc1 	add	w1, w30, w30, lsl #2
    R(5, 8, cB, sB);
   82efc:	0b0b0962 	add	w2, w11, w11, lsl #2
    R(5, 7, cA, sA);
   82f00:	0b130a63 	add	w3, w19, w19, lsl #2
    R(5, 8, cB, sB);
   82f04:	4b80216b 	sub	w11, w11, w0, asr #8
    R(5, 7, cA, sA);
   82f08:	4b811e73 	sub	w19, w19, w1, asr #7
    R(5, 8, cB, sB);
   82f0c:	0b8221ce 	add	w14, w14, w2, asr #8
    R(5, 7, cA, sA);
   82f10:	d0000080 	adrp	x0, 94000 <_binary_font_psf_start+0x634>
   82f14:	0b831fde 	add	w30, w30, w3, asr #7
   82f18:	9119400c 	add	x12, x0, #0x650
   82f1c:	b0000080 	adrp	x0, 93000 <get_el+0xe198>
   82f20:	9126700d 	add	x13, x0, #0x99c
    R(5, 8, cB, sB);
   82f24:	1b0bc960 	msub	w0, w11, w11, w18
            if (x < 50) {
                // to display, scale x by K, y by 2K (so we have a round donut)
                int K=6, xx=x*K, yy=y*K*2;
                // PIXEL clr = b[k]; // blue only, simple
                PIXEL clr = int2rgb(b[k]); // to a color spectrum
                setpixel(the_fb.fb, xx, yy, the_fb.pitch, clr);
   82f28:	d000008a 	adrp	x10, 94000 <_binary_font_psf_start+0x634>
    R(5, 7, cA, sA);
   82f2c:	1b13ca69 	msub	w9, w19, w19, w18
                setpixel(the_fb.fb, xx, yy, the_fb.pitch, clr);
   82f30:	529999a5 	mov	w5, #0xcccd                	// #52429
    R(5, 8, cB, sB);
   82f34:	1b0e81c0 	msub	w0, w14, w14, w0
        if (k % 80) {
   82f38:	52866664 	mov	w4, #0x3333                	// #13107
    R(5, 7, cA, sA);
   82f3c:	1b1ea7c9 	msub	w9, w30, w30, w9
                PIXEL clr = int2rgb(b[k]); // to a color spectrum
   82f40:	aa0c03e7 	mov	x7, x12
                setpixel(the_fb.fb, xx, yy, the_fb.pitch, clr);
   82f44:	f941554a 	ldr	x10, [x10, #680]
    R(5, 8, cB, sB);
   82f48:	130b7c00 	asr	w0, w0, #11
    R(5, 7, cA, sA);
   82f4c:	130b7d29 	asr	w9, w9, #11
                setpixel(the_fb.fb, xx, yy, the_fb.pitch, clr);
   82f50:	d2800001 	mov	x1, #0x0                   	// #0
   82f54:	aa0a03e8 	mov	x8, x10
    int y = 0, x = 0;
   82f58:	52800002 	mov	w2, #0x0                   	// #0
    R(5, 8, cB, sB);
   82f5c:	1b007d6b 	mul	w11, w11, w0
    int y = 0, x = 0;
   82f60:	52800003 	mov	w3, #0x0                   	// #0
    R(5, 7, cA, sA);
   82f64:	1b097fde 	mul	w30, w30, w9
                setpixel(the_fb.fb, xx, yy, the_fb.pitch, clr);
   82f68:	72b99985 	movk	w5, #0xcccc, lsl #16
    R(5, 7, cA, sA);
   82f6c:	1b097e73 	mul	w19, w19, w9
        if (k % 80) {
   82f70:	72a06664 	movk	w4, #0x333, lsl #16
    R(5, 8, cB, sB);
   82f74:	1b007dce 	mul	w14, w14, w0
   82f78:	130a7d60 	asr	w0, w11, #10
    R(5, 7, cA, sA);
   82f7c:	b000008b 	adrp	x11, 93000 <get_el+0xe198>
   82f80:	130a7fc9 	asr	w9, w30, #10
                setpixel(the_fb.fb, xx, yy, the_fb.pitch, clr);
   82f84:	f940014a 	ldr	x10, [x10]
    R(5, 7, cA, sA);
   82f88:	130a7e66 	asr	w6, w19, #10
   82f8c:	b9099d69 	str	w9, [x11, #2460]
    R(5, 8, cB, sB);
   82f90:	130a7dc9 	asr	w9, w14, #10
   82f94:	b90005a9 	str	w9, [x13, #4]
    R(5, 7, cA, sA);
   82f98:	b90dc186 	str	w6, [x12, #3520]
    R(5, 8, cB, sB);
   82f9c:	b90dc580 	str	w0, [x12, #3524]
                setpixel(the_fb.fb, xx, yy, the_fb.pitch, clr);
   82fa0:	1b057c20 	mul	w0, w1, w5
   82fa4:	13801000 	ror	w0, w0, #4
        if (k % 80) {
   82fa8:	6b04001f 	cmp	w0, w4
   82fac:	54000589 	b.ls	8305c <draw_frame+0x364>  // b.plast
            if (x < 50) {
   82fb0:	7100c45f 	cmp	w2, #0x31
   82fb4:	540001ad 	b.le	82fe8 <draw_frame+0x2f0>
                setpixel(the_fb.fb, xx+1, yy, the_fb.pitch, clr);
                setpixel(the_fb.fb, xx, yy+1, the_fb.pitch, clr);
                setpixel(the_fb.fb, xx+1, yy+1, the_fb.pitch, clr);
            }
            x++;
   82fb8:	11000442 	add	w2, w2, #0x1
    for (int k = 0; 1761 > k; k++) {
   82fbc:	91000421 	add	x1, x1, #0x1
   82fc0:	f11b843f 	cmp	x1, #0x6e1
   82fc4:	54fffee1 	b.ne	82fa0 <draw_frame+0x2a8>  // b.any
            x = 1;
        }
    }

    return 1; // restart timer 
}
   82fc8:	52800020 	mov	w0, #0x1                   	// #1
   82fcc:	a94153f3 	ldp	x19, x20, [sp, #16]
   82fd0:	a9425bf5 	ldp	x21, x22, [sp, #32]
   82fd4:	a94363f7 	ldp	x23, x24, [sp, #48]
   82fd8:	a9446bf9 	ldp	x25, x26, [sp, #64]
   82fdc:	a94573fb 	ldp	x27, x28, [sp, #80]
   82fe0:	a8c77bfd 	ldp	x29, x30, [sp], #112
   82fe4:	d65f03c0 	ret
                int K=6, xx=x*K, yy=y*K*2;
   82fe8:	531f7849 	lsl	w9, w2, #1
                PIXEL clr = int2rgb(b[k]); // to a color spectrum
   82fec:	38676820 	ldrb	w0, [x1, x7]
                int K=6, xx=x*K, yy=y*K*2;
   82ff0:	0b03046b 	add	w11, w3, w3, lsl #1
   82ff4:	0b020126 	add	w6, w9, w2

// map luminance [0..255] to rgb color
// value: 0..255, PIXEL: argb
static PIXEL int2rgb (int value) {
    int r,g,b;     
    if (value >= 0 && value <= 85) {
   82ff8:	7101541f 	cmp	w0, #0x55
                int K=6, xx=x*K, yy=y*K*2;
   82ffc:	531e756b 	lsl	w11, w11, #2
   83000:	531f78c6 	lsl	w6, w6, #1
    if (value >= 0 && value <= 85) {
   83004:	54000328 	b.hi	83068 <draw_frame+0x370>  // b.pmore
        // Black to Yellow (R stays 0, G increases, B stays 0)
        r = 0;
        g = (value * 3);
   83008:	0b000400 	add	w0, w0, w0, lsl #1
   8300c:	53185c00 	lsl	w0, w0, #8
    *(PIXEL *)(buf + y * pit + x * PIXELSIZE) = p;
   83010:	b940190c 	ldr	w12, [x8, #24]
   83014:	0b020129 	add	w9, w9, w2
                setpixel(the_fb.fb, xx+1, yy, the_fb.pitch, clr);
   83018:	110004c6 	add	w6, w6, #0x1
    *(PIXEL *)(buf + y * pit + x * PIXELSIZE) = p;
   8301c:	531d7129 	lsl	w9, w9, #3
   83020:	531e74c6 	lsl	w6, w6, #2
   83024:	1b0c7d6c 	mul	w12, w11, w12
   83028:	8b29c149 	add	x9, x10, w9, sxtw
   8302c:	8b26c146 	add	x6, x10, w6, sxtw
   83030:	b82cc920 	str	w0, [x9, w12, sxtw]
   83034:	b940190c 	ldr	w12, [x8, #24]
   83038:	1b0c7d6c 	mul	w12, w11, w12
   8303c:	b82cc8c0 	str	w0, [x6, w12, sxtw]
   83040:	b940190c 	ldr	w12, [x8, #24]
   83044:	1b0c316c 	madd	w12, w11, w12, w12
   83048:	b82cc920 	str	w0, [x9, w12, sxtw]
   8304c:	b9401909 	ldr	w9, [x8, #24]
   83050:	1b092569 	madd	w9, w11, w9, w9
   83054:	b829c8c0 	str	w0, [x6, w9, sxtw]
}
   83058:	17ffffd8 	b	82fb8 <draw_frame+0x2c0>
            y++;
   8305c:	11000463 	add	w3, w3, #0x1
            x = 1;
   83060:	52800022 	mov	w2, #0x1                   	// #1
   83064:	17ffffd6 	b	82fbc <draw_frame+0x2c4>
        b = 0;
    } else if (value > 85 && value <= 170) {
   83068:	5101580c 	sub	w12, w0, #0x56
   8306c:	7101519f 	cmp	w12, #0x54
   83070:	54000108 	b.hi	83090 <draw_frame+0x398>  // b.pmore
        // Yellow to Cyan (G stays 255, R decreases, B increases)
        r = 255 - ((value - 85) * 3);
   83074:	51015400 	sub	w0, w0, #0x55
   83078:	4b00080c 	sub	w12, w0, w0, lsl #2
        g = 255;
        b = (value - 85) * 3;
   8307c:	0b000400 	add	w0, w0, w0, lsl #1
        r = 255 - ((value - 85) * 3);
   83080:	1103fd8c 	add	w12, w12, #0xff
   83084:	2a0c4000 	orr	w0, w0, w12, lsl #16
   83088:	32181c00 	orr	w0, w0, #0xff00
   8308c:	17ffffe1 	b	83010 <draw_frame+0x318>
    } else if (value > 170 && value <= 255) {
        // Cyan to Blue (G decreases, B stays 255, R stays 0)
        r = 0;
        g = 255 - ((value - 170) * 3);
   83090:	5102a800 	sub	w0, w0, #0xaa
   83094:	4b000800 	sub	w0, w0, w0, lsl #2
   83098:	1103fc00 	add	w0, w0, #0xff
   8309c:	53185c00 	lsl	w0, w0, #8
   830a0:	32001c00 	orr	w0, w0, #0xff
   830a4:	17ffffdb 	b	83010 <draw_frame+0x318>

00000000000830a8 <donut>:
void donut(void) {
   830a8:	a9bf7bfd 	stp	x29, x30, [sp, #-16]!
   830ac:	910003fd 	mov	x29, sp
    canvas_init();
   830b0:	97fffefe 	bl	82ca8 <canvas_init>
    ret = ktimer_start(100, /*firing interval, ms*/
   830b4:	f0ffffe1 	adrp	x1, 82000 <us_delay+0x18>
   830b8:	d2800003 	mov	x3, #0x0                   	// #0
   830bc:	9133e021 	add	x1, x1, #0xcf8
   830c0:	d2800002 	mov	x2, #0x0                   	// #0
   830c4:	52800c80 	mov	w0, #0x64                  	// #100
   830c8:	97fffc0a 	bl	820f0 <ktimer_start>
    BUG_ON(ret<0);     
   830cc:	37f80060 	tbnz	w0, #31, 830d8 <donut+0x30>
}
   830d0:	a8c17bfd 	ldp	x29, x30, [sp], #16
   830d4:	d65f03c0 	ret
   830d8:	a8c17bfd 	ldp	x29, x30, [sp], #16
    BUG_ON(ret<0);     
   830dc:	f0000061 	adrp	x1, 92000 <get_el+0xd198>
   830e0:	f0000060 	adrp	x0, 92000 <get_el+0xd198>
   830e4:	912f4021 	add	x1, x1, #0xbd0
   830e8:	912f6000 	add	x0, x0, #0xbd8
   830ec:	52801022 	mov	w2, #0x81                  	// #129
   830f0:	17fff9fa 	b	818d8 <assertion_failed>
   830f4:	d503201f 	nop

00000000000830f8 <donut_simple>:
void donut_simple(void) {
   830f8:	a9bf7bfd 	stp	x29, x30, [sp, #-16]!
   830fc:	910003fd 	mov	x29, sp
    canvas_init();
   83100:	97fffeea 	bl	82ca8 <canvas_init>
    put32(TIMER_C1, 100 * 1000);	// in us
   83104:	d2860200 	mov	x0, #0x3010                	// #12304
   83108:	5290d401 	mov	w1, #0x86a0                	// #34464
   8310c:	f2a7e000 	movk	x0, #0x3f00, lsl #16
   83110:	72a00021 	movk	w1, #0x1, lsl #16
   83114:	b9000001 	str	w1, [x0]
}
   83118:	a8c17bfd 	ldp	x29, x30, [sp], #16
   8311c:	d65f03c0 	ret

0000000000083120 <sys_timer_irq_simple>:
    BUG_ON(!(get32(TIMER_CS) & TIMER_CS_M1));  
   83120:	d2860000 	mov	x0, #0x3000                	// #12288
{
   83124:	a9bf7bfd 	stp	x29, x30, [sp, #-16]!
    BUG_ON(!(get32(TIMER_CS) & TIMER_CS_M1));  
   83128:	f2a7e000 	movk	x0, #0x3f00, lsl #16
{
   8312c:	910003fd 	mov	x29, sp
    BUG_ON(!(get32(TIMER_CS) & TIMER_CS_M1));  
   83130:	b9400000 	ldr	w0, [x0]
   83134:	36080220 	tbz	w0, #1, 83178 <sys_timer_irq_simple+0x58>
	put32(TIMER_CS, TIMER_CS_M1);	// clear timer1 match
   83138:	d2860000 	mov	x0, #0x3000                	// #12288
   8313c:	52800043 	mov	w3, #0x2                   	// #2
   83140:	f2a7e000 	movk	x0, #0x3f00, lsl #16
    draw_frame(0, 0, 0); 
   83144:	d2800002 	mov	x2, #0x0                   	// #0
   83148:	d2800001 	mov	x1, #0x0                   	// #0
	put32(TIMER_CS, TIMER_CS_M1);	// clear timer1 match
   8314c:	b9000003 	str	w3, [x0]
    draw_frame(0, 0, 0); 
   83150:	d2800000 	mov	x0, #0x0                   	// #0
   83154:	97fffee9 	bl	82cf8 <draw_frame>
    cur = current_counter(); 
   83158:	97fffb8a 	bl	81f80 <current_counter>
	put32(TIMER_C1, cur + 100 * 1000 /*in us*/);	//!STUDENT_DONOT_SEE 
   8315c:	11406000 	add	w0, w0, #0x18, lsl #12
   83160:	d2860201 	mov	x1, #0x3010                	// #12304
   83164:	111a8000 	add	w0, w0, #0x6a0
   83168:	f2a7e001 	movk	x1, #0x3f00, lsl #16
   8316c:	b9000020 	str	w0, [x1]
}
   83170:	a8c17bfd 	ldp	x29, x30, [sp], #16
   83174:	d65f03c0 	ret
    BUG_ON(!(get32(TIMER_CS) & TIMER_CS_M1));  
   83178:	f0000061 	adrp	x1, 92000 <get_el+0xd198>
   8317c:	d0000000 	adrp	x0, 85000 <get_el+0x198>
   83180:	912f4021 	add	x1, x1, #0xbd0
   83184:	910cc000 	add	x0, x0, #0x330
   83188:	52801302 	mov	w2, #0x98                  	// #152
   8318c:	97fff9d3 	bl	818d8 <assertion_failed>
   83190:	17ffffea 	b	83138 <sys_timer_irq_simple+0x18>
   83194:	d503201f 	nop

0000000000083198 <donut_text>:
void donut_text(void) {
   83198:	a9ba7bfd 	stp	x29, x30, [sp, #-96]!
   8319c:	910003fd 	mov	x29, sp
   831a0:	a9046bf9 	stp	x25, x26, [sp, #64]
   831a4:	b0000099 	adrp	x25, 94000 <_binary_font_psf_start+0x634>
        memset(b, 32, 1760);  // text buffer
   831a8:	91194339 	add	x25, x25, #0x650
void donut_text(void) {
   831ac:	a9025bf5 	stp	x21, x22, [sp, #32]
    int sA = 1024, cA = 0, sB = 1024, cB = 0, _;
   831b0:	52808015 	mov	w21, #0x400                 	// #1024
   831b4:	52800016 	mov	w22, #0x0                   	// #0
void donut_text(void) {
   831b8:	a90363f7 	stp	x23, x24, [sp, #48]
        memset(z, 127, 1760); // z buffer
   831bc:	911b8338 	add	x24, x25, #0x6e0
    int sA = 1024, cA = 0, sB = 1024, cB = 0, _;
   831c0:	2a1503f7 	mov	w23, w21
void donut_text(void) {
   831c4:	a90153f3 	stp	x19, x20, [sp, #16]
    int sA = 1024, cA = 0, sB = 1024, cB = 0, _;
   831c8:	52800014 	mov	w20, #0x0                   	// #0
   831cc:	f0000073 	adrp	x19, 92000 <get_el+0xd198>
void donut_text(void) {
   831d0:	a90573fb 	stp	x27, x28, [sp, #80]
        memset(b, 32, 1760);  // text buffer
   831d4:	5280dc02 	mov	w2, #0x6e0                 	// #1760
   831d8:	52800401 	mov	w1, #0x20                  	// #32
   831dc:	aa1903e0 	mov	x0, x25
   831e0:	97fff9ca 	bl	81908 <memset>
        memset(z, 127, 1760); // z buffer
   831e4:	4b1603fc 	neg	w28, w22
   831e8:	aa1803e0 	mov	x0, x24
   831ec:	5280dc02 	mov	w2, #0x6e0                 	// #1760
   831f0:	52800fe1 	mov	w1, #0x7f                  	// #127
   831f4:	4b1703fb 	neg	w27, w23
   831f8:	97fff9c4 	bl	81908 <memset>
                    b[o] = ".,-~:;=!*#$@"[N > 0 ? N : 0];
   831fc:	912fc27a 	add	x26, x19, #0xbf0
        memset(z, 127, 1760); // z buffer
   83200:	52800b5e 	mov	w30, #0x5a                  	// #90
        int sj = 0, cj = 1024;
   83204:	52808012 	mov	w18, #0x400                 	// #1024
   83208:	52800011 	mov	w17, #0x0                   	// #0
                R(5, 8, ci, si) // rotate i
   8320c:	52a0060e 	mov	w14, #0x300000              	// #3145728
                    x5 = sA * sj >> 10,
   83210:	1b117eef 	mul	w15, w23, w17
   83214:	1120024b 	add	w11, w18, #0x800
                    x2 = cA * sj >> 10,
   83218:	1b117ecc 	mul	w12, w22, w17
                    N = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5) >> 7;
   8321c:	5280288a 	mov	w10, #0x144                 	// #324
   83220:	1b127eb0 	mul	w16, w21, w18
                    x6 = K2 + R1 * 1024 * x5 + cA * x3,
   83224:	121655ed 	and	w13, w15, #0xfffffc00
   83228:	115401ad 	add	w13, w13, #0x500, lsl #12
                    x5 = sA * sj >> 10,
   8322c:	130a7def 	asr	w15, w15, #10
                    x2 = cA * sj >> 10,
   83230:	130a7d8c 	asr	w12, w12, #10
            int si = 0, ci = 1024; // sine and cosine of angle i
   83234:	52808007 	mov	w7, #0x400                 	// #1024
                    N = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5) >> 7;
   83238:	130a7e10 	asr	w16, w16, #10
            int si = 0, ci = 1024; // sine and cosine of angle i
   8323c:	52800003 	mov	w3, #0x0                   	// #0
                    x3 = si * x0 >> 10,
   83240:	1b0b7c69 	mul	w9, w3, w11
                R(5, 8, ci, si) // rotate i
   83244:	0b030860 	add	w0, w3, w3, lsl #2
                    x1 = ci * x0 >> 10,
   83248:	1b0b7ce2 	mul	w2, w7, w11
                R(5, 8, ci, si) // rotate i
   8324c:	0b0708e4 	add	w4, w7, w7, lsl #2
   83250:	4b8020e0 	sub	w0, w7, w0, asr #8
                    x3 = si * x0 >> 10,
   83254:	130a7d26 	asr	w6, w9, #10
                R(5, 8, ci, si) // rotate i
   83258:	0b842064 	add	w4, w3, w4, asr #8
                    x1 = ci * x0 >> 10,
   8325c:	130a7c42 	asr	w2, w2, #10
                R(5, 8, ci, si) // rotate i
   83260:	1b00b801 	msub	w1, w0, w0, w14
                    x4 = R1 * x2 - (sA * x3 >> 10),
   83264:	1b067ee5 	mul	w5, w23, w6
                    x = 25 + 30 * (cB * x1 - sB * x4) / x6,
   83268:	1b027e88 	mul	w8, w20, w2
                    y = 12 + 15 * (cB * x4 + sB * x1) / x6,
   8326c:	1b027ea2 	mul	w2, w21, w2
                    x4 = R1 * x2 - (sA * x3 >> 10),
   83270:	4b852985 	sub	w5, w12, w5, asr #10
                    x6 = K2 + R1 * 1024 * x5 + cA * x3,
   83274:	1b0636c6 	madd	w6, w22, w6, w13
                R(5, 8, ci, si) // rotate i
   83278:	1b048481 	msub	w1, w4, w4, w1
                    x = 25 + 30 * (cB * x1 - sB * x4) / x6,
   8327c:	1b05a2a8 	msub	w8, w21, w5, w8
                    y = 12 + 15 * (cB * x4 + sB * x1) / x6,
   83280:	1b050a82 	madd	w2, w20, w5, w2
                R(5, 8, ci, si) // rotate i
   83284:	130b7c21 	asr	w1, w1, #11
                    x = 25 + 30 * (cB * x1 - sB * x4) / x6,
   83288:	531c6d05 	lsl	w5, w8, #4
   8328c:	4b0800a8 	sub	w8, w5, w8
                    y = 12 + 15 * (cB * x4 + sB * x1) / x6,
   83290:	531c6c45 	lsl	w5, w2, #4
   83294:	4b0200a2 	sub	w2, w5, w2
                R(5, 8, ci, si) // rotate i
   83298:	1b017c00 	mul	w0, w0, w1
   8329c:	1b017c81 	mul	w1, w4, w1
                    x = 25 + 30 * (cB * x1 - sB * x4) / x6,
   832a0:	531f7908 	lsl	w8, w8, #1
                    y = 12 + 15 * (cB * x4 + sB * x1) / x6,
   832a4:	1ac60c42 	sdiv	w2, w2, w6
                if (22 > y && y > 0 && x > 0 && 80 > x && zz < z[o]) {
   832a8:	11002c44 	add	w4, w2, #0xb
   832ac:	7100509f 	cmp	w4, #0x14
   832b0:	540003c8 	b.hi	83328 <donut_text+0x190>  // b.pmore
                    x = 25 + 30 * (cB * x1 - sB * x4) / x6,
   832b4:	1ac60d08 	sdiv	w8, w8, w6
                    y = 12 + 15 * (cB * x4 + sB * x1) / x6,
   832b8:	11003042 	add	w2, w2, #0xc
                signed char zz = (x6 - K2) >> 15;
   832bc:	515400c4 	sub	w4, w6, #0x500, lsl #12
                int o = x + 80 * y; // fxl: 80 chars per row
   832c0:	0b020842 	add	w2, w2, w2, lsl #2
                signed char zz = (x6 - K2) >> 15;
   832c4:	934f5884 	sbfx	x4, x4, #15, #8
                    x = 25 + 30 * (cB * x1 - sB * x4) / x6,
   832c8:	11006505 	add	w5, w8, #0x19
                if (22 > y && y > 0 && x > 0 && 80 > x && zz < z[o]) {
   832cc:	11006108 	add	w8, w8, #0x18
                int o = x + 80 * y; // fxl: 80 chars per row
   832d0:	0b0210a2 	add	w2, w5, w2, lsl #4
                if (22 > y && y > 0 && x > 0 && 80 > x && zz < z[o]) {
   832d4:	7101391f 	cmp	w8, #0x4e
   832d8:	54000288 	b.hi	83328 <donut_text+0x190>  // b.pmore
   832dc:	38e2cb05 	ldrsb	w5, [x24, w2, sxtw]
                    x7 = cj * si >> 10,
   832e0:	4b032d23 	sub	w3, w9, w3, lsl #11
                if (22 > y && y > 0 && x > 0 && 80 > x && zz < z[o]) {
   832e4:	6b0400bf 	cmp	w5, w4
                    x7 = cj * si >> 10,
   832e8:	130a7c63 	asr	w3, w3, #10
                if (22 > y && y > 0 && x > 0 && 80 > x && zz < z[o]) {
   832ec:	540001ed 	b.le	83328 <donut_text+0x190>
                    N = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5) >> 7;
   832f0:	1b1b7c65 	mul	w5, w3, w27
                    z[o] = zz;
   832f4:	3822cb04 	strb	w4, [x24, w2, sxtw]
                    N = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5) >> 7;
   832f8:	1b1c7c63 	mul	w3, w3, w28
   832fc:	0b852984 	add	w4, w12, w5, asr #10
   83300:	1b148c83 	msub	w3, w4, w20, w3
   83304:	1b078e03 	msub	w3, w16, w7, w3
   83308:	130a7c63 	asr	w3, w3, #10
   8330c:	4b0f0063 	sub	w3, w3, w15
   83310:	13077c63 	asr	w3, w3, #7
                    b[o] = ".,-~:;=!*#$@"[N > 0 ? N : 0];
   83314:	7100007f 	cmp	w3, #0x0
   83318:	1a9fa063 	csel	w3, w3, wzr, ge  // ge = tcont
   8331c:	3863cb43 	ldrb	w3, [x26, w3, sxtw]
   83320:	3822cb23 	strb	w3, [x25, w2, sxtw]
   83324:	d503201f 	nop
                R(5, 8, ci, si) // rotate i
   83328:	130a7c07 	asr	w7, w0, #10
   8332c:	130a7c23 	asr	w3, w1, #10
            for (int i = 0; i < 324; i++) {
   83330:	7100054a 	subs	w10, w10, #0x1
   83334:	54fff861 	b.ne	83240 <donut_text+0xa8>  // b.any
            R(9, 7, cj, sj) // rotate j
   83338:	0b110e21 	add	w1, w17, w17, lsl #3
   8333c:	0b120e40 	add	w0, w18, w18, lsl #3
        for (int j = 0; j < 90; j++) {
   83340:	710007de 	subs	w30, w30, #0x1
            R(9, 7, cj, sj) // rotate j
   83344:	4b811e52 	sub	w18, w18, w1, asr #7
   83348:	0b801e31 	add	w17, w17, w0, asr #7
   8334c:	1b12ba40 	msub	w0, w18, w18, w14
   83350:	1b118220 	msub	w0, w17, w17, w0
   83354:	130b7c00 	asr	w0, w0, #11
   83358:	1b007e52 	mul	w18, w18, w0
   8335c:	1b007e31 	mul	w17, w17, w0
   83360:	130a7e52 	asr	w18, w18, #10
   83364:	130a7e31 	asr	w17, w17, #10
        for (int j = 0; j < 90; j++) {
   83368:	54fff541 	b.ne	83210 <donut_text+0x78>  // b.any
        R(5, 7, cA, sA);
   8336c:	0b170ae3 	add	w3, w23, w23, lsl #2
        R(5, 8, cB, sB);
   83370:	0b150aa1 	add	w1, w21, w21, lsl #2
        R(5, 7, cA, sA);
   83374:	0b160ac2 	add	w2, w22, w22, lsl #2
        R(5, 8, cB, sB);
   83378:	0b140a80 	add	w0, w20, w20, lsl #2
        R(5, 7, cA, sA);
   8337c:	4b831ed6 	sub	w22, w22, w3, asr #7
        R(5, 8, cB, sB);
   83380:	4b812294 	sub	w20, w20, w1, asr #8
        R(5, 7, cA, sA);
   83384:	0b821ef7 	add	w23, w23, w2, asr #7
        R(5, 8, cB, sB);
   83388:	0b8022b5 	add	w21, w21, w0, asr #8
   8338c:	529999ba 	mov	w26, #0xcccd                	// #52429
   83390:	d280003c 	mov	x28, #0x1                   	// #1
        R(5, 7, cA, sA);
   83394:	1b16bac2 	msub	w2, w22, w22, w14
        R(5, 8, cB, sB);
   83398:	72b9999a 	movk	w26, #0xcccc, lsl #16
   8339c:	1b14ba80 	msub	w0, w20, w20, w14
            putc(0, k % 80 ? b[k] : 10);
   833a0:	52800141 	mov	w1, #0xa                   	// #10
        R(5, 7, cA, sA);
   833a4:	1b178ae2 	msub	w2, w23, w23, w2
            putc(0, k % 80 ? b[k] : 10);
   833a8:	5286667b 	mov	w27, #0x3333                	// #13107
        R(5, 8, cB, sB);
   833ac:	1b1582a0 	msub	w0, w21, w21, w0
            putc(0, k % 80 ? b[k] : 10);
   833b0:	72a0667b 	movk	w27, #0x333, lsl #16
        R(5, 7, cA, sA);
   833b4:	130b7c42 	asr	w2, w2, #11
        R(5, 8, cB, sB);
   833b8:	130b7c00 	asr	w0, w0, #11
        R(5, 7, cA, sA);
   833bc:	1b027ed6 	mul	w22, w22, w2
   833c0:	1b027ef7 	mul	w23, w23, w2
        R(5, 8, cB, sB);
   833c4:	1b007e94 	mul	w20, w20, w0
   833c8:	1b007eb5 	mul	w21, w21, w0
            putc(0, k % 80 ? b[k] : 10);
   833cc:	d2800000 	mov	x0, #0x0                   	// #0
   833d0:	940001b8 	bl	83ab0 <putc>
        R(5, 7, cA, sA);
   833d4:	130a7ed6 	asr	w22, w22, #10
        R(5, 8, cB, sB);
   833d8:	1b1c7f40 	mul	w0, w26, w28
        R(5, 7, cA, sA);
   833dc:	130a7ef7 	asr	w23, w23, #10
        R(5, 8, cB, sB);
   833e0:	130a7e94 	asr	w20, w20, #10
   833e4:	130a7eb5 	asr	w21, w21, #10
        for (int k = 0; 1761 > k; k++)
   833e8:	f11b879f 	cmp	x28, #0x6e1
   833ec:	54000180 	b.eq	8341c <donut_text+0x284>  // b.none
            putc(0, k % 80 ? b[k] : 10);
   833f0:	52800141 	mov	w1, #0xa                   	// #10
        R(5, 8, cB, sB);
   833f4:	13801000 	ror	w0, w0, #4
            putc(0, k % 80 ? b[k] : 10);
   833f8:	6b1b001f 	cmp	w0, w27
   833fc:	54000049 	b.ls	83404 <donut_text+0x26c>  // b.plast
   83400:	38796b81 	ldrb	w1, [x28, x25]
   83404:	9100079c 	add	x28, x28, #0x1
   83408:	d2800000 	mov	x0, #0x0                   	// #0
   8340c:	940001a9 	bl	83ab0 <putc>
        for (int k = 0; 1761 > k; k++)
   83410:	f11b879f 	cmp	x28, #0x6e1
        R(5, 8, cB, sB);
   83414:	1b1c7f40 	mul	w0, w26, w28
        for (int k = 0; 1761 > k; k++)
   83418:	54fffec1 	b.ne	833f0 <donut_text+0x258>  // b.any
        printf("\x1b[23A");  // clear console 
   8341c:	f0000060 	adrp	x0, 92000 <get_el+0xd198>
   83420:	912fa000 	add	x0, x0, #0xbe8
   83424:	97fff85f 	bl	815a0 <tfp_printf>
        ms_delay(10);  // can delay in this way, but inefficient
   83428:	52800140 	mov	w0, #0xa                   	// #10
   8342c:	97fffadf 	bl	81fa8 <ms_delay>
    while (1) {
   83430:	17ffff69 	b	831d4 <donut_text+0x3c>
   83434:	00000000 	udf	#0

0000000000083438 <handler>:

#include "plat.h"
#include "utils.h"
#include "debug.h"

static int handler(TKernelTimerHandle hTimer, void *param, void *context) {
   83438:	d10183ff 	sub	sp, sp, #0x60
   8343c:	a9017bfd 	stp	x29, x30, [sp, #16]
   83440:	910043fd 	add	x29, sp, #0x10
   83444:	a90253f3 	stp	x19, x20, [sp, #32]
   83448:	aa0003f3 	mov	x19, x0
   8344c:	aa0103f4 	mov	x20, x1
	unsigned sec, msec; 
	current_time(&sec, &msec);
   83450:	910163e0 	add	x0, sp, #0x58
   83454:	910173e1 	add	x1, sp, #0x5c
static int handler(TKernelTimerHandle hTimer, void *param, void *context) {
   83458:	a9035bf5 	stp	x21, x22, [sp, #48]
   8345c:	aa0203f5 	mov	x21, x2
   83460:	f90023f7 	str	x23, [sp, #64]
	current_time(&sec, &msec);
   83464:	97fffaef 	bl	82020 <current_time>
	I("%u.%03u: fired. on cpu %d. htimer %ld, param %lx, contex %lx", sec, msec,
   83468:	294b5ff6 	ldp	w22, w23, [sp, #88]
   8346c:	94000673 	bl	84e38 <cpuid>
   83470:	f90003f5 	str	x21, [sp]
   83474:	aa1403e7 	mov	x7, x20
   83478:	aa1303e6 	mov	x6, x19
   8347c:	2a1703e4 	mov	w4, w23
   83480:	2a1603e3 	mov	w3, w22
   83484:	2a0003e5 	mov	w5, w0
   83488:	52800182 	mov	w2, #0xc                   	// #12
   8348c:	f0000061 	adrp	x1, 92000 <get_el+0xd198>
   83490:	f0000060 	adrp	x0, 92000 <get_el+0xd198>
   83494:	91300021 	add	x1, x1, #0xc00
   83498:	91304000 	add	x0, x0, #0xc10
   8349c:	97fff841 	bl	815a0 <tfp_printf>
		cpuid(), hTimer, (unsigned long)param, (unsigned long)context); 
    return 0; // don't restart the timer
}
   834a0:	52800000 	mov	w0, #0x0                   	// #0
   834a4:	a9417bfd 	ldp	x29, x30, [sp, #16]
   834a8:	a94253f3 	ldp	x19, x20, [sp, #32]
   834ac:	a9435bf5 	ldp	x21, x22, [sp, #48]
   834b0:	f94023f7 	ldr	x23, [sp, #64]
   834b4:	910183ff 	add	sp, sp, #0x60
   834b8:	d65f03c0 	ret
   834bc:	d503201f 	nop

00000000000834c0 <test_ktimer2_handler>:
    press 0 to kill all timers
    each ktimer has different firing period
*/    

static int test_ktimer2_handler(TKernelTimerHandle hTimer, void *param, 
    void *context) {
   834c0:	a9bc7bfd 	stp	x29, x30, [sp, #-64]!
   834c4:	910003fd 	mov	x29, sp
   834c8:	a90153f3 	stp	x19, x20, [sp, #16]
   834cc:	aa0003f4 	mov	x20, x0
   834d0:	aa0103f3 	mov	x19, x1
	unsigned sec, msec; 
	current_time(&sec, &msec);
   834d4:	9100e3e0 	add	x0, sp, #0x38
   834d8:	9100f3e1 	add	x1, sp, #0x3c
    void *context) {
   834dc:	a9025bf5 	stp	x21, x22, [sp, #32]
	current_time(&sec, &msec);
   834e0:	97fffad0 	bl	82020 <current_time>
	printf("%s %u.%03u: fired. on cpu %d. htimer %ld\n" _k2clr_none, 
   834e4:	29475bf5 	ldp	w21, w22, [sp, #56]
   834e8:	94000654 	bl	84e38 <cpuid>
   834ec:	aa1403e5 	mov	x5, x20
   834f0:	aa1303e1 	mov	x1, x19
   834f4:	2a1603e3 	mov	w3, w22
   834f8:	2a1503e2 	mov	w2, w21
   834fc:	2a0003e4 	mov	w4, w0
   83500:	f0000060 	adrp	x0, 92000 <get_el+0xd198>
   83504:	91318000 	add	x0, x0, #0xc60
   83508:	97fff826 	bl	815a0 <tfp_printf>
        (char *)param, sec, msec, cpuid(), hTimer); 
    return 1; // restart the timer 
}
   8350c:	52800020 	mov	w0, #0x1                   	// #1
   83510:	a94153f3 	ldp	x19, x20, [sp, #16]
   83514:	a9425bf5 	ldp	x21, x22, [sp, #32]
   83518:	a8c47bfd 	ldp	x29, x30, [sp], #64
   8351c:	d65f03c0 	ret

0000000000083520 <test_ktimer>:
void test_ktimer() {
   83520:	a9bb7bfd 	stp	x29, x30, [sp, #-80]!
   83524:	910003fd 	mov	x29, sp
   83528:	a90153f3 	stp	x19, x20, [sp, #16]
	current_time(&sec, &msec); 
   8352c:	910123f4 	add	x20, sp, #0x48
   83530:	aa1403e0 	mov	x0, x20
void test_ktimer() {
   83534:	a9025bf5 	stp	x21, x22, [sp, #32]
	current_time(&sec, &msec); 
   83538:	910133f5 	add	x21, sp, #0x4c
   8353c:	aa1503e1 	mov	x1, x21
void test_ktimer() {
   83540:	f9001bf7 	str	x23, [sp, #48]
	current_time(&sec, &msec); 
   83544:	97fffab7 	bl	82020 <current_time>
	I("%u.%03u start delaying 500ms...", sec, msec); 
   83548:	294913e3 	ldp	w3, w4, [sp, #72]
   8354c:	f0000077 	adrp	x23, 92000 <get_el+0xd198>
   83550:	913002f3 	add	x19, x23, #0xc00
   83554:	528002c2 	mov	w2, #0x16                  	// #22
   83558:	aa1303e1 	mov	x1, x19
   8355c:	f0000060 	adrp	x0, 92000 <get_el+0xd198>
   83560:	91324000 	add	x0, x0, #0xc90
   83564:	97fff80f 	bl	815a0 <tfp_printf>
	ms_delay(500); 
   83568:	52803e80 	mov	w0, #0x1f4                 	// #500
   8356c:	97fffa8f 	bl	81fa8 <ms_delay>
	current_time(&sec, &msec);
   83570:	aa1503e1 	mov	x1, x21
   83574:	aa1403e0 	mov	x0, x20
   83578:	97fffaaa 	bl	82020 <current_time>
	int t = ktimer_start(500, handler, (void *)0xdeadbeef, (void*)0xdeaddeed);
   8357c:	90000015 	adrp	x21, 83000 <draw_frame+0x308>
	I("%u.%03u ended delaying 500ms", sec, msec); 
   83580:	294913e3 	ldp	w3, w4, [sp, #72]
   83584:	aa1303e1 	mov	x1, x19
   83588:	52800322 	mov	w2, #0x19                  	// #25
   8358c:	f0000060 	adrp	x0, 92000 <get_el+0xd198>
   83590:	91332000 	add	x0, x0, #0xcc8
	int t = ktimer_start(500, handler, (void *)0xdeadbeef, (void*)0xdeaddeed);
   83594:	9110e2b5 	add	x21, x21, #0x438
	I("%u.%03u ended delaying 500ms", sec, msec); 
   83598:	97fff802 	bl	815a0 <tfp_printf>
	I("timer start. timer id %u", t); 
   8359c:	f0000074 	adrp	x20, 92000 <get_el+0xd198>
	int t = ktimer_start(500, handler, (void *)0xdeadbeef, (void*)0xdeaddeed);
   835a0:	d29bdda3 	mov	x3, #0xdeed                	// #57069
   835a4:	d297dde2 	mov	x2, #0xbeef                	// #48879
   835a8:	aa1503e1 	mov	x1, x21
   835ac:	f2bbd5a3 	movk	x3, #0xdead, lsl #16
   835b0:	f2bbd5a2 	movk	x2, #0xdead, lsl #16
   835b4:	52803e80 	mov	w0, #0x1f4                 	// #500
   835b8:	97ffface 	bl	820f0 <ktimer_start>
	I("timer start. timer id %u", t); 
   835bc:	2a0003e3 	mov	w3, w0
   835c0:	aa1303e1 	mov	x1, x19
   835c4:	9133e294 	add	x20, x20, #0xcf8
   835c8:	528003a2 	mov	w2, #0x1d                  	// #29
	int t = ktimer_start(500, handler, (void *)0xdeadbeef, (void*)0xdeaddeed);
   835cc:	2a0003f6 	mov	w22, w0
	I("timer start. timer id %u", t); 
   835d0:	aa1403e0 	mov	x0, x20
   835d4:	97fff7f3 	bl	815a0 <tfp_printf>
	ms_delay(1000);
   835d8:	52807d00 	mov	w0, #0x3e8                 	// #1000
   835dc:	97fffa73 	bl	81fa8 <ms_delay>
	I("timer %d should have fired", t); 
   835e0:	2a1603e3 	mov	w3, w22
   835e4:	aa1303e1 	mov	x1, x19
   835e8:	528003e2 	mov	w2, #0x1f                  	// #31
   835ec:	f0000060 	adrp	x0, 92000 <get_el+0xd198>
   835f0:	9134a000 	add	x0, x0, #0xd28
   835f4:	97fff7eb 	bl	815a0 <tfp_printf>
	t = ktimer_start(500, handler, (void *)0xdeadbeef, (void*)0xdeaddeed);
   835f8:	d29bdda3 	mov	x3, #0xdeed                	// #57069
   835fc:	d297dde2 	mov	x2, #0xbeef                	// #48879
   83600:	aa1503e1 	mov	x1, x21
   83604:	f2bbd5a3 	movk	x3, #0xdead, lsl #16
   83608:	f2bbd5a2 	movk	x2, #0xdead, lsl #16
   8360c:	52803e80 	mov	w0, #0x1f4                 	// #500
   83610:	97fffab8 	bl	820f0 <ktimer_start>
	I("timer start. timer id %u", t); 
   83614:	2a0003e3 	mov	w3, w0
   83618:	aa1303e1 	mov	x1, x19
   8361c:	aa1403e0 	mov	x0, x20
   83620:	52800462 	mov	w2, #0x23                  	// #35
   83624:	97fff7df 	bl	815a0 <tfp_printf>
	t = ktimer_start(1000, handler, (void *)0xdeadbeef, (void*)0xdeaddeed);
   83628:	d29bdda3 	mov	x3, #0xdeed                	// #57069
   8362c:	d297dde2 	mov	x2, #0xbeef                	// #48879
   83630:	aa1503e1 	mov	x1, x21
   83634:	f2bbd5a3 	movk	x3, #0xdead, lsl #16
   83638:	f2bbd5a2 	movk	x2, #0xdead, lsl #16
   8363c:	52807d00 	mov	w0, #0x3e8                 	// #1000
   83640:	97fffaac 	bl	820f0 <ktimer_start>
	I("timer start. timer id %u", t); 
   83644:	2a0003e3 	mov	w3, w0
   83648:	aa1303e1 	mov	x1, x19
   8364c:	528004a2 	mov	w2, #0x25                  	// #37
   83650:	aa1403e0 	mov	x0, x20
   83654:	97fff7d3 	bl	815a0 <tfp_printf>
	ms_delay(2000); 
   83658:	5280fa00 	mov	w0, #0x7d0                 	// #2000
   8365c:	97fffa53 	bl	81fa8 <ms_delay>
	I("both timers should have fired"); 
   83660:	aa1303e1 	mov	x1, x19
   83664:	528004e2 	mov	w2, #0x27                  	// #39
   83668:	f0000060 	adrp	x0, 92000 <get_el+0xd198>
   8366c:	91356000 	add	x0, x0, #0xd58
   83670:	97fff7cc 	bl	815a0 <tfp_printf>
	t = ktimer_start(500, handler, (void *)0xdeadbeef, (void*)0xdeaddeed);
   83674:	d29bdda3 	mov	x3, #0xdeed                	// #57069
   83678:	d297dde2 	mov	x2, #0xbeef                	// #48879
   8367c:	aa1503e1 	mov	x1, x21
   83680:	f2bbd5a3 	movk	x3, #0xdead, lsl #16
   83684:	f2bbd5a2 	movk	x2, #0xdead, lsl #16
   83688:	52803e80 	mov	w0, #0x1f4                 	// #500
   8368c:	97fffa99 	bl	820f0 <ktimer_start>
	I("timer start. timer id %u", t);
   83690:	2a0003e3 	mov	w3, w0
   83694:	aa1303e1 	mov	x1, x19
   83698:	52800562 	mov	w2, #0x2b                  	// #43
	t = ktimer_start(500, handler, (void *)0xdeadbeef, (void*)0xdeaddeed);
   8369c:	2a0003f5 	mov	w21, w0
	I("timer start. timer id %u", t);
   836a0:	aa1403e0 	mov	x0, x20
   836a4:	97fff7bf 	bl	815a0 <tfp_printf>
	ms_delay(100); 
   836a8:	52800c80 	mov	w0, #0x64                  	// #100
   836ac:	97fffa3f 	bl	81fa8 <ms_delay>
	int c = ktimer_cancel(t); 
   836b0:	2a1503e0 	mov	w0, w21
   836b4:	97fffad7 	bl	82210 <ktimer_cancel>
	I("timer cancel return val = %d", c);
   836b8:	aa1303e1 	mov	x1, x19
	int c = ktimer_cancel(t); 
   836bc:	2a0003f4 	mov	w20, w0
	I("timer cancel return val = %d", c);
   836c0:	2a0003e3 	mov	w3, w0
   836c4:	528005c2 	mov	w2, #0x2e                  	// #46
   836c8:	f0000060 	adrp	x0, 92000 <get_el+0xd198>
   836cc:	91364000 	add	x0, x0, #0xd90
   836d0:	97fff7b4 	bl	815a0 <tfp_printf>
	BUG_ON(c < 0);
   836d4:	37f80174 	tbnz	w20, #31, 83700 <test_ktimer+0x1e0>
	I("there shouldn't be more callback"); 
   836d8:	913002e1 	add	x1, x23, #0xc00
   836dc:	52800622 	mov	w2, #0x31                  	// #49
   836e0:	f0000060 	adrp	x0, 92000 <get_el+0xd198>
   836e4:	91374000 	add	x0, x0, #0xdd0
   836e8:	97fff7ae 	bl	815a0 <tfp_printf>
}
   836ec:	a94153f3 	ldp	x19, x20, [sp, #16]
   836f0:	a9425bf5 	ldp	x21, x22, [sp, #32]
   836f4:	f9401bf7 	ldr	x23, [sp, #48]
   836f8:	a8c57bfd 	ldp	x29, x30, [sp], #80
   836fc:	d65f03c0 	ret
	BUG_ON(c < 0);
   83700:	aa1303e1 	mov	x1, x19
   83704:	f0000060 	adrp	x0, 92000 <get_el+0xd198>
   83708:	528005e2 	mov	w2, #0x2f                  	// #47
   8370c:	91370000 	add	x0, x0, #0xdc0
   83710:	97fff872 	bl	818d8 <assertion_failed>
   83714:	17fffff1 	b	836d8 <test_ktimer+0x1b8>

0000000000083718 <test_ktimer2>:
    
/* 
    c: char received from uart, support 1..9; 0 to kill all timers
    to be called in uart rx irq handler 
*/
void test_ktimer2(int c) {
   83718:	a9bc7bfd 	stp	x29, x30, [sp, #-64]!
   8371c:	910003fd 	mov	x29, sp
   83720:	a90153f3 	stp	x19, x20, [sp, #16]
    if (c<'0' || c>'9') return; 
   83724:	5100c014 	sub	w20, w0, #0x30
   83728:	7100269f 	cmp	w20, #0x9
   8372c:	540002e8 	b.hi	83788 <test_ktimer2+0x70>  // b.pmore
   83730:	a9025bf5 	stp	x21, x22, [sp, #32]
    int ret; 
    if (c=='0') {
   83734:	7100c01f 	cmp	w0, #0x30
   83738:	540002e0 	b.eq	83794 <test_ktimer2+0x7c>  // b.none
                timers[i]=-1;
                W("ktimer_cancel idx %d", i+1); 
            }
        }
    } else {
        int idx = c-'1'; 
   8373c:	5100c400 	sub	w0, w0, #0x31
        if (timers[idx]!=-1) { // cancel the timer
   83740:	90000096 	adrp	x22, 93000 <get_el+0xe198>
   83744:	9126a2d5 	add	x21, x22, #0x9a8
   83748:	93407c13 	sxtw	x19, w0
   8374c:	b8737aa0 	ldr	w0, [x21, x19, lsl #2]
   83750:	3100041f 	cmn	w0, #0x1
   83754:	540005c0 	b.eq	8380c <test_ktimer2+0xf4>  // b.none
            W("ktimer_cancel %d", idx+1); 
   83758:	2a1403e3 	mov	w3, w20
   8375c:	52800c62 	mov	w2, #0x63                  	// #99
   83760:	f0000061 	adrp	x1, 92000 <get_el+0xd198>
   83764:	f0000060 	adrp	x0, 92000 <get_el+0xd198>
   83768:	91300021 	add	x1, x1, #0xc00
   8376c:	91390000 	add	x0, x0, #0xe40
   83770:	97fff78c 	bl	815a0 <tfp_printf>
            ret = ktimer_cancel(timers[idx]); 
   83774:	b8737aa0 	ldr	w0, [x21, x19, lsl #2]
   83778:	97fffaa6 	bl	82210 <ktimer_cancel>
            // BUG_ON(ret == -1); // no such timer (maybe benign? like just fired?
            timers[idx]=-1;
   8377c:	12800000 	mov	w0, #0xffffffff            	// #-1
   83780:	b8337aa0 	str	w0, [x21, x19, lsl #2]
   83784:	a9425bf5 	ldp	x21, x22, [sp, #32]
                test_ktimer2_handler, (void*)colors[idx] /*args*/, 0 /* context */); 
            BUG_ON(ret<0); 
            timers[idx]=ret; 
        }
    }
}
   83788:	a94153f3 	ldp	x19, x20, [sp, #16]
   8378c:	a8c47bfd 	ldp	x29, x30, [sp], #64
   83790:	d65f03c0 	ret
   83794:	90000093 	adrp	x19, 93000 <get_el+0xe198>
   83798:	f0000076 	adrp	x22, 92000 <get_el+0xd198>
                W("ktimer_cancel idx %d", i+1); 
   8379c:	f0000075 	adrp	x21, 92000 <get_el+0xd198>
   837a0:	9126a273 	add	x19, x19, #0x9a8
   837a4:	913862b5 	add	x21, x21, #0xe18
   837a8:	a90363f7 	stp	x23, x24, [sp, #48]
                BUG_ON(ret == -1); // no such timer
   837ac:	913002d8 	add	x24, x22, #0xc00
        for (int i=0;i<N_TIMERS_TEST;i++) {
   837b0:	52800014 	mov	w20, #0x0                   	// #0
                timers[i]=-1;
   837b4:	12800017 	mov	w23, #0xffffffff            	// #-1
            if (timers[i]!=-1) {
   837b8:	b9400260 	ldr	w0, [x19]
   837bc:	11000694 	add	w20, w20, #0x1
   837c0:	3100041f 	cmn	w0, #0x1
   837c4:	54000140 	b.eq	837ec <test_ktimer2+0xd4>  // b.none
                ret = ktimer_cancel(timers[i]); 
   837c8:	97fffa92 	bl	82210 <ktimer_cancel>
                BUG_ON(ret == -1); // no such timer
   837cc:	3100041f 	cmn	w0, #0x1
   837d0:	54000500 	b.eq	83870 <test_ktimer2+0x158>  // b.none
                timers[i]=-1;
   837d4:	b9000277 	str	w23, [x19]
                W("ktimer_cancel idx %d", i+1); 
   837d8:	2a1403e3 	mov	w3, w20
   837dc:	913002c1 	add	x1, x22, #0xc00
   837e0:	aa1503e0 	mov	x0, x21
   837e4:	52800ba2 	mov	w2, #0x5d                  	// #93
   837e8:	97fff76e 	bl	815a0 <tfp_printf>
        for (int i=0;i<N_TIMERS_TEST;i++) {
   837ec:	91001273 	add	x19, x19, #0x4
   837f0:	7100269f 	cmp	w20, #0x9
   837f4:	54fffe21 	b.ne	837b8 <test_ktimer2+0xa0>  // b.any
}
   837f8:	a94153f3 	ldp	x19, x20, [sp, #16]
   837fc:	a9425bf5 	ldp	x21, x22, [sp, #32]
   83800:	a94363f7 	ldp	x23, x24, [sp, #48]
   83804:	a8c47bfd 	ldp	x29, x30, [sp], #64
   83808:	d65f03c0 	ret
            W("ktimer_start %d", idx+1); 
   8380c:	f0000075 	adrp	x21, 92000 <get_el+0xd198>
   83810:	913002b5 	add	x21, x21, #0xc00
   83814:	2a1403e3 	mov	w3, w20
   83818:	aa1503e1 	mov	x1, x21
   8381c:	52800d02 	mov	w2, #0x68                  	// #104
   83820:	f0000060 	adrp	x0, 92000 <get_el+0xd198>
   83824:	9139a000 	add	x0, x0, #0xe68
   83828:	97fff75e 	bl	815a0 <tfp_printf>
                test_ktimer2_handler, (void*)colors[idx] /*args*/, 0 /* context */); 
   8382c:	b0000082 	adrp	x2, 94000 <_binary_font_psf_start+0x634>
   83830:	910b6042 	add	x2, x2, #0x2d8
            ret = ktimer_start(200*(idx+1), /*firing interval, ms*/
   83834:	52801900 	mov	w0, #0xc8                  	// #200
   83838:	90000001 	adrp	x1, 83000 <draw_frame+0x308>
   8383c:	d2800003 	mov	x3, #0x0                   	// #0
   83840:	91130021 	add	x1, x1, #0x4c0
   83844:	1b007e80 	mul	w0, w20, w0
   83848:	f8737842 	ldr	x2, [x2, x19, lsl #3]
   8384c:	97fffa29 	bl	820f0 <ktimer_start>
   83850:	2a0003f4 	mov	w20, w0
            BUG_ON(ret<0); 
   83854:	37f801a0 	tbnz	w0, #31, 83888 <test_ktimer2+0x170>
            timers[idx]=ret; 
   83858:	9126a2d6 	add	x22, x22, #0x9a8
   8385c:	b8337ad4 	str	w20, [x22, x19, lsl #2]
}
   83860:	a94153f3 	ldp	x19, x20, [sp, #16]
            timers[idx]=ret; 
   83864:	a9425bf5 	ldp	x21, x22, [sp, #32]
}
   83868:	a8c47bfd 	ldp	x29, x30, [sp], #64
   8386c:	d65f03c0 	ret
                BUG_ON(ret == -1); // no such timer
   83870:	aa1803e1 	mov	x1, x24
   83874:	f0000060 	adrp	x0, 92000 <get_el+0xd198>
   83878:	52800b62 	mov	w2, #0x5b                  	// #91
   8387c:	91382000 	add	x0, x0, #0xe08
   83880:	97fff816 	bl	818d8 <assertion_failed>
   83884:	17ffffd4 	b	837d4 <test_ktimer2+0xbc>
            BUG_ON(ret<0); 
   83888:	aa1503e1 	mov	x1, x21
   8388c:	f0000060 	adrp	x0, 92000 <get_el+0xd198>
   83890:	52800d62 	mov	w2, #0x6b                  	// #107
   83894:	912f6000 	add	x0, x0, #0xbd8
   83898:	97fff810 	bl	818d8 <assertion_failed>
   8389c:	17ffffef 	b	83858 <test_ktimer2+0x140>

00000000000838a0 <test_fb_voffset>:
    efficiency.

    This works correctly on RPi3 hardware. Known bug on QEMU: Some color
    quadrants won't display correctly, likely due to a QEMU bug.
*/ 
void test_fb_voffset() {
   838a0:	a9be7bfd 	stp	x29, x30, [sp, #-32]!
   838a4:	910003fd 	mov	x29, sp
   838a8:	f9000bf3 	str	x19, [sp, #16]

    // acquire(&mboxlock);      //it's a test. so no lock

    fb_fini(); 

    the_fb.width = N;
   838ac:	b0000093 	adrp	x19, 94000 <_binary_font_psf_start+0x634>
    fb_fini(); 
   838b0:	97fffb76 	bl	82688 <fb_fini>
    the_fb.width = N;
   838b4:	f9415660 	ldr	x0, [x19, #680]
   838b8:	b21803e2 	mov	x2, #0x10000000100         	// #1099511628032
    the_fb.height = N;

    the_fb.vwidth = N*2; 
   838bc:	b21703e1 	mov	x1, #0x20000000200         	// #2199023256064
   838c0:	a9008402 	stp	x2, x1, [x0, #8]
    the_fb.vheight = N*2; 

    if (fb_init() != 0) BUG();     
   838c4:	97fffc51 	bl	82a08 <fb_init>
   838c8:	350008e0 	cbnz	w0, 839e4 <test_fb_voffset+0x144>

    // prefill the fb with four color tiles, once 
    PIXEL b=0x00ff0000, g=0x0000ff00, r=0x000000ff; 
    int x, y;
    int pitch = the_fb.pitch; 
   838cc:	f9415673 	ldr	x19, [x19, #680]
    for (y=0;y<N;y++)
        for (x=0;x<N;x++)
            setpixel(the_fb.fb,x,y,pitch,r); 
   838d0:	52802006 	mov	w6, #0x100                 	// #256
    *(PIXEL *)(buf + y*pit + x*PIXELSIZE) = p; 
   838d4:	52801fe4 	mov	w4, #0xff                  	// #255
   838d8:	f9400267 	ldr	x7, [x19]
    int pitch = the_fb.pitch; 
   838dc:	b9401a61 	ldr	w1, [x19, #24]
    for (y=0;y<N;y++)
   838e0:	911000e2 	add	x2, x7, #0x400
            setpixel(the_fb.fb,x,y,pitch,r); 
   838e4:	aa0203e3 	mov	x3, x2
   838e8:	93407c25 	sxtw	x5, w1
        for (x=0;x<N;x++)
   838ec:	d1100060 	sub	x0, x3, #0x400
    *(PIXEL *)(buf + y*pit + x*PIXELSIZE) = p; 
   838f0:	b8004404 	str	w4, [x0], #4
        for (x=0;x<N;x++)
   838f4:	eb03001f 	cmp	x0, x3
   838f8:	54ffffc1 	b.ne	838f0 <test_fb_voffset+0x50>  // b.any
    for (y=0;y<N;y++)
   838fc:	8b050003 	add	x3, x0, x5
   83900:	710004c6 	subs	w6, w6, #0x1
   83904:	54ffff41 	b.ne	838ec <test_fb_voffset+0x4c>  // b.any
   83908:	912000e7 	add	x7, x7, #0x800
   8390c:	52802006 	mov	w6, #0x100                 	// #256
   83910:	aa0703e3 	mov	x3, x7
    *(PIXEL *)(buf + y*pit + x*PIXELSIZE) = p; 
   83914:	32009fe4 	mov	w4, #0xff00ff              	// #16711935

    for (y=0;y<N;y++)
        for (x=N;x<2*N;x++)
   83918:	d1100060 	sub	x0, x3, #0x400
   8391c:	d503201f 	nop
    *(PIXEL *)(buf + y*pit + x*PIXELSIZE) = p; 
   83920:	b8004404 	str	w4, [x0], #4
        for (x=N;x<2*N;x++)
   83924:	eb00007f 	cmp	x3, x0
   83928:	54ffffc1 	b.ne	83920 <test_fb_voffset+0x80>  // b.any
    for (y=0;y<N;y++)
   8392c:	8b050063 	add	x3, x3, x5
   83930:	710004c6 	subs	w6, w6, #0x1
   83934:	54ffff21 	b.ne	83918 <test_fb_voffset+0x78>  // b.any
   83938:	53185c21 	lsl	w1, w1, #8
   8393c:	52802004 	mov	w4, #0x100                 	// #256
    *(PIXEL *)(buf + y*pit + x*PIXELSIZE) = p; 
   83940:	529fe003 	mov	w3, #0xff00                	// #65280
   83944:	93407c21 	sxtw	x1, w1
   83948:	8b020022 	add	x2, x1, x2
            setpixel(the_fb.fb,x,y,pitch,(b|r));             

    for (y=N;y<2*N;y++)
        for (x=0;x<N;x++)
   8394c:	d1100040 	sub	x0, x2, #0x400
    *(PIXEL *)(buf + y*pit + x*PIXELSIZE) = p; 
   83950:	b8004403 	str	w3, [x0], #4
        for (x=0;x<N;x++)
   83954:	eb00005f 	cmp	x2, x0
   83958:	54ffffc1 	b.ne	83950 <test_fb_voffset+0xb0>  // b.any
    for (y=N;y<2*N;y++)
   8395c:	8b050042 	add	x2, x2, x5
   83960:	71000484 	subs	w4, w4, #0x1
   83964:	54ffff41 	b.ne	8394c <test_fb_voffset+0xac>  // b.any
   83968:	8b070021 	add	x1, x1, x7
   8396c:	52802003 	mov	w3, #0x100                 	// #256
    *(PIXEL *)(buf + y*pit + x*PIXELSIZE) = p; 
   83970:	52a01fe2 	mov	w2, #0xff0000              	// #16711680
            setpixel(the_fb.fb,x,y,pitch,g); 

    for (y=N;y<2*N;y++)
        for (x=N;x<2*N;x++)
   83974:	d1100020 	sub	x0, x1, #0x400
    *(PIXEL *)(buf + y*pit + x*PIXELSIZE) = p; 
   83978:	b8004402 	str	w2, [x0], #4
        for (x=N;x<2*N;x++)
   8397c:	eb00003f 	cmp	x1, x0
   83980:	54ffffc1 	b.ne	83978 <test_fb_voffset+0xd8>  // b.any
    for (y=N;y<2*N;y++)
   83984:	8b050021 	add	x1, x1, x5
   83988:	71000463 	subs	w3, w3, #0x1
   8398c:	54ffff41 	b.ne	83974 <test_fb_voffset+0xd4>  // b.any

    //what if we dont flush cache?
    // __asm_flush_dcache_range(the_fb.fb, the_fb.fb + the_fb.size); 

    while (1) {
        fb_set_voffsets(0,0);
   83990:	52800001 	mov	w1, #0x0                   	// #0
   83994:	52800000 	mov	w0, #0x0                   	// #0
   83998:	97fffb02 	bl	825a0 <fb_set_voffsets>
        ms_delay(1500); 
   8399c:	5280bb80 	mov	w0, #0x5dc                 	// #1500
   839a0:	97fff982 	bl	81fa8 <ms_delay>
        fb_set_voffsets(0,N);
   839a4:	52802001 	mov	w1, #0x100                 	// #256
   839a8:	52800000 	mov	w0, #0x0                   	// #0
   839ac:	97fffafd 	bl	825a0 <fb_set_voffsets>
        ms_delay(1500); 
   839b0:	5280bb80 	mov	w0, #0x5dc                 	// #1500
   839b4:	97fff97d 	bl	81fa8 <ms_delay>
        fb_set_voffsets(N,0);
   839b8:	52800001 	mov	w1, #0x0                   	// #0
   839bc:	52802000 	mov	w0, #0x100                 	// #256
   839c0:	97fffaf8 	bl	825a0 <fb_set_voffsets>
        ms_delay(1500); 
   839c4:	5280bb80 	mov	w0, #0x5dc                 	// #1500
   839c8:	97fff978 	bl	81fa8 <ms_delay>
        fb_set_voffsets(N,N);
   839cc:	52802001 	mov	w1, #0x100                 	// #256
   839d0:	2a0103e0 	mov	w0, w1
   839d4:	97fffaf3 	bl	825a0 <fb_set_voffsets>
        ms_delay(1500); 
   839d8:	5280bb80 	mov	w0, #0x5dc                 	// #1500
   839dc:	97fff973 	bl	81fa8 <ms_delay>
    while (1) {
   839e0:	17ffffec 	b	83990 <test_fb_voffset+0xf0>
    if (fb_init() != 0) BUG();     
   839e4:	f0000061 	adrp	x1, 92000 <get_el+0xd198>
   839e8:	b0000000 	adrp	x0, 84000 <vectors>
   839ec:	91300021 	add	x1, x1, #0xc00
   839f0:	913ce000 	add	x0, x0, #0xf38
   839f4:	52801342 	mov	w2, #0x9a                  	// #154
   839f8:	97fff7b8 	bl	818d8 <assertion_failed>
   839fc:	17ffffb4 	b	838cc <test_fb_voffset+0x2c>

0000000000083a00 <uart_send>:
// busy wait
// quest: UART. complete below cf uart_recv()
void uart_send (char c) {
	while(1) {
        // read the status reg to check if the tx fifo is empty
		if(get32(AUX_MU_LSR_REG) & 0x20) // !STUDENT_DONOT_SEE
   83a00:	d28a0a82 	mov	x2, #0x5054                	// #20564
void uart_send (char c) {
   83a04:	12001c00 	and	w0, w0, #0xff
		if(get32(AUX_MU_LSR_REG) & 0x20) // !STUDENT_DONOT_SEE
   83a08:	f2a7e422 	movk	x2, #0x3f21, lsl #16
   83a0c:	d503201f 	nop
   83a10:	b9400041 	ldr	w1, [x2]
   83a14:	362fffe1 	tbz	w1, #5, 83a10 <uart_send+0x10>
			break;                       // !STUDENT_DONOT_SEE
	}
	put32(AUX_MU_IO_REG, c);    // !STUDENT_DONOT_SEE
   83a18:	d28a0801 	mov	x1, #0x5040                	// #20544
   83a1c:	f2a7e421 	movk	x1, #0x3f21, lsl #16
   83a20:	b9000020 	str	w0, [x1]
}
   83a24:	d65f03c0 	ret

0000000000083a28 <uart_recv>:
 
// busy wait until get a char 
char uart_recv (void) {
	while(1) {
		if(get32(AUX_MU_LSR_REG) & 0x01) 
   83a28:	d28a0a81 	mov	x1, #0x5054                	// #20564
   83a2c:	f2a7e421 	movk	x1, #0x3f21, lsl #16
   83a30:	b9400020 	ldr	w0, [x1]
   83a34:	3607ffe0 	tbz	w0, #0, 83a30 <uart_recv+0x8>
			break;
	}
	return(get32(AUX_MU_IO_REG) & 0xFF);
   83a38:	d28a0800 	mov	x0, #0x5040                	// #20544
   83a3c:	f2a7e420 	movk	x0, #0x3f21, lsl #16
   83a40:	b9400000 	ldr	w0, [x0]
}
   83a44:	d65f03c0 	ret

0000000000083a48 <uart_try_recv>:

// try read a char, return -1 if no char (NB: return type is int) 
int uart_try_recv(void) {
    if (!(get32(AUX_MU_STAT_REG) & 0xF0000)) {
   83a48:	d28a0c80 	mov	x0, #0x5064                	// #20580
   83a4c:	f2a7e420 	movk	x0, #0x3f21, lsl #16
   83a50:	b9400000 	ldr	w0, [x0]
   83a54:	72100c1f 	tst	w0, #0xf0000
   83a58:	540000c0 	b.eq	83a70 <uart_try_recv+0x28>  // b.none
        return -1;
    } else {
        // rx fifo has bytes
        return get32(AUX_MU_IO_REG) & 0xFF;
   83a5c:	d28a0800 	mov	x0, #0x5040                	// #20544
   83a60:	f2a7e420 	movk	x0, #0x3f21, lsl #16
   83a64:	b9400000 	ldr	w0, [x0]
   83a68:	12001c00 	and	w0, w0, #0xff
    }
}
   83a6c:	d65f03c0 	ret
        return -1;
   83a70:	12800000 	mov	w0, #0xffffffff            	// #-1
}
   83a74:	d65f03c0 	ret

0000000000083a78 <uart_send_string>:

void uart_send_string(char* str) {
	for (int i = 0; str[i] != '\0'; i ++) {
   83a78:	39400002 	ldrb	w2, [x0]
   83a7c:	34000182 	cbz	w2, 83aac <uart_send_string+0x34>
		if(get32(AUX_MU_LSR_REG) & 0x20) // !STUDENT_DONOT_SEE
   83a80:	d28a0a81 	mov	x1, #0x5054                	// #20564
	put32(AUX_MU_IO_REG, c);    // !STUDENT_DONOT_SEE
   83a84:	d28a0804 	mov	x4, #0x5040                	// #20544
   83a88:	91000403 	add	x3, x0, #0x1
		if(get32(AUX_MU_LSR_REG) & 0x20) // !STUDENT_DONOT_SEE
   83a8c:	f2a7e421 	movk	x1, #0x3f21, lsl #16
	put32(AUX_MU_IO_REG, c);    // !STUDENT_DONOT_SEE
   83a90:	f2a7e424 	movk	x4, #0x3f21, lsl #16
   83a94:	d503201f 	nop
		if(get32(AUX_MU_LSR_REG) & 0x20) // !STUDENT_DONOT_SEE
   83a98:	b9400020 	ldr	w0, [x1]
   83a9c:	362fffe0 	tbz	w0, #5, 83a98 <uart_send_string+0x20>
	put32(AUX_MU_IO_REG, c);    // !STUDENT_DONOT_SEE
   83aa0:	b9000082 	str	w2, [x4]
	for (int i = 0; str[i] != '\0'; i ++) {
   83aa4:	38401462 	ldrb	w2, [x3], #1
   83aa8:	35ffff82 	cbnz	w2, 83a98 <uart_send_string+0x20>
		uart_send((char)str[i]);
	}
}
   83aac:	d65f03c0 	ret

0000000000083ab0 <putc>:
		if(get32(AUX_MU_LSR_REG) & 0x20) // !STUDENT_DONOT_SEE
   83ab0:	d28a0a82 	mov	x2, #0x5054                	// #20564

// This function is required by printf function
void putc(void* p, char c) {
   83ab4:	12001c21 	and	w1, w1, #0xff
		if(get32(AUX_MU_LSR_REG) & 0x20) // !STUDENT_DONOT_SEE
   83ab8:	f2a7e422 	movk	x2, #0x3f21, lsl #16
   83abc:	d503201f 	nop
   83ac0:	b9400040 	ldr	w0, [x2]
   83ac4:	362fffe0 	tbz	w0, #5, 83ac0 <putc+0x10>
	put32(AUX_MU_IO_REG, c);    // !STUDENT_DONOT_SEE
   83ac8:	d28a0800 	mov	x0, #0x5040                	// #20544
   83acc:	f2a7e420 	movk	x0, #0x3f21, lsl #16
   83ad0:	b9000001 	str	w1, [x0]
	uart_send(c);
}
   83ad4:	d65f03c0 	ret

0000000000083ad8 <uart_irq>:
 */
void uart_irq(void) {
    //  check AUX_MU_IIR_REG bit0 for pending irq
    //    and bit 2:1 for irq causes
	int c; 
    uint iir = get32(AUX_MU_IIR_REG);
   83ad8:	d28a0900 	mov	x0, #0x5048                	// #20552
   83adc:	f2a7e420 	movk	x0, #0x3f21, lsl #16
   83ae0:	b9400000 	ldr	w0, [x0]
    if (iir & 1) // no pending
   83ae4:	370002c0 	tbnz	w0, #0, 83b3c <uart_irq+0x64>
        return;
    V("pending irq: p %d w %d r %d", (iir & 1), (iir & 2), (iir & 4));

    // clear rx irq, must be done before we read 
    if (IS_RECEIVE_INTERRUPT(iir)) {
   83ae8:	361002a0 	tbz	w0, #2, 83b3c <uart_irq+0x64>
void uart_irq(void) {
   83aec:	a9be7bfd 	stp	x29, x30, [sp, #-32]!
   83af0:	910003fd 	mov	x29, sp
   83af4:	a90153f3 	stp	x19, x20, [sp, #16]
    if (!(get32(AUX_MU_STAT_REG) & 0xF0000)) {
   83af8:	d28a0c93 	mov	x19, #0x5064                	// #20580
   83afc:	f2a7e433 	movk	x19, #0x3f21, lsl #16
   83b00:	b9400260 	ldr	w0, [x19]
   83b04:	72100c1f 	tst	w0, #0xf0000
   83b08:	54000140 	b.eq	83b30 <uart_irq+0x58>  // b.none
        return get32(AUX_MU_IO_REG) & 0xFF;
   83b0c:	d28a0814 	mov	x20, #0x5040                	// #20544
   83b10:	f2a7e434 	movk	x20, #0x3f21, lsl #16
   83b14:	d503201f 	nop
   83b18:	b9400280 	ldr	w0, [x20]
            // quest (side): UART rx irq
            c = uart_try_recv();   //!STUDENT_DONOT_SEE
            if (c == -1)  //!STUDENT_DONOT_SEE
                break;      //!STUDENT_DONOT_SEE
			V("char %d", c); 
			test_ktimer2(c);    //!STUDENT_DONOT_SEE
   83b1c:	12001c00 	and	w0, w0, #0xff
   83b20:	97fffefe 	bl	83718 <test_ktimer2>
    if (!(get32(AUX_MU_STAT_REG) & 0xF0000)) {
   83b24:	b9400260 	ldr	w0, [x19]
   83b28:	72100c1f 	tst	w0, #0xf0000
   83b2c:	54ffff61 	b.ne	83b18 <uart_irq+0x40>  // b.any
        }
    }
}
   83b30:	a94153f3 	ldp	x19, x20, [sp, #16]
   83b34:	a8c27bfd 	ldp	x29, x30, [sp], #32
   83b38:	d65f03c0 	ret
   83b3c:	d65f03c0 	ret

0000000000083b40 <uart_init>:
void uart_init(void) {
    unsigned int selector;
    // code below also showcases how to configure GPIO pins
    // cf: https://github.com/bztsrc/raspi3-tutorial/blob/master/03_uart1/uart.c#L45
    // select gpio functions for pin14,15. note 3bits per pin.
    selector = get32(GPFSEL1);
   83b40:	d2800082 	mov	x2, #0x4                   	// #4
void uart_init(void) {
   83b44:	a9be7bfd 	stp	x29, x30, [sp, #-32]!
    selector = get32(GPFSEL1);
   83b48:	f2a7e402 	movk	x2, #0x3f20, lsl #16
void uart_init(void) {
   83b4c:	910003fd 	mov	x29, sp
    selector = get32(GPFSEL1);
   83b50:	b9400041 	ldr	w1, [x2]

    // Below: set up GPIO pull modes. protocol recommended by the bcm2837 manual
    //    (pg 101, "GPIO Pull-up/down Clock Registers")
    // We need neither the pull-up nor the pull-down state, because both
    //  the 14 and 15 pins are going to be connected all the time.
    put32(GPPUD, 0); // disable pull up/down control (for pins below)
   83b54:	d2801283 	mov	x3, #0x94                  	// #148
   83b58:	f2a7e403 	movk	x3, #0x3f20, lsl #16
    selector |= 2 << 15;    // set alt5 for gpio15
   83b5c:	52840004 	mov	w4, #0x2000                	// #8192
   83b60:	120e6421 	and	w1, w1, #0xfffc0fff
void uart_init(void) {
   83b64:	f9000bf3 	str	x19, [sp, #16]
    selector |= 2 << 15;    // set alt5 for gpio15
   83b68:	72a00024 	movk	w4, #0x1, lsl #16
   83b6c:	2a040021 	orr	w1, w1, w4
    put32(GPFSEL1, selector);
   83b70:	b9000041 	str	w1, [x2]
    delay(150);
    // "control the actuation of internal pull-downs on the respective GPIO pins."
    put32(GPPUDCLK0, (1 << 14) | (1 << 15)); // "clock the control signal into the GPIO pads"
   83b74:	d2801313 	mov	x19, #0x98                  	// #152
    put32(GPPUD, 0); // disable pull up/down control (for pins below)
   83b78:	b900007f 	str	wzr, [x3]
    put32(GPPUDCLK0, (1 << 14) | (1 << 15)); // "clock the control signal into the GPIO pads"
   83b7c:	f2a7e413 	movk	x19, #0x3f20, lsl #16
    delay(150);
   83b80:	d28012c0 	mov	x0, #0x96                  	// #150
   83b84:	97fff943 	bl	82090 <delay>
    put32(GPPUDCLK0, (1 << 14) | (1 << 15)); // "clock the control signal into the GPIO pads"
   83b88:	52980000 	mov	w0, #0xc000                	// #49152
   83b8c:	b9000260 	str	w0, [x19]
    delay(150);
   83b90:	d28012c0 	mov	x0, #0x96                  	// #150
   83b94:	97fff93f 	bl	82090 <delay>
    put32(GPPUDCLK0, 0);               // remote the clock, flush GPIO setup
   83b98:	b900027f 	str	wzr, [x19]
    put32(AUX_MU_IIR_REG, FLUSH_UART); // flush FIFO
   83b9c:	d28a0900 	mov	x0, #0x5048                	// #20552

    put32(AUX_ENABLES, 1);     // Enable mini uart (this also enables access to it registers)
   83ba0:	d28a0081 	mov	x1, #0x5004                	// #20484
    put32(AUX_MU_IIR_REG, FLUSH_UART); // flush FIFO
   83ba4:	f2a7e420 	movk	x0, #0x3f21, lsl #16
    put32(AUX_ENABLES, 1);     // Enable mini uart (this also enables access to it registers)
   83ba8:	f2a7e421 	movk	x1, #0x3f21, lsl #16
    put32(AUX_MU_CNTL_REG, 0); // Disable auto flow control and disable receiver and transmitter (for now)
   83bac:	d28a0c02 	mov	x2, #0x5060                	// #20576
    put32(AUX_MU_IIR_REG, FLUSH_UART); // flush FIFO
   83bb0:	528018c3 	mov	w3, #0xc6                  	// #198
    put32(AUX_MU_CNTL_REG, 0); // Disable auto flow control and disable receiver and transmitter (for now)
   83bb4:	f2a7e422 	movk	x2, #0x3f21, lsl #16
		unsigned int ier = get32(AUX_MU_IER_REG); 
        // flip the bits of ier that enable rx irq, and write back ier to the reg
  		put32(AUX_MU_IER_REG, ier | AUX_MU_IER_RXIRQ_ENABLE); //!STUDENT_DONOT_SEE
	} // leave tx irq disabled

    put32(AUX_MU_LCR_REG, 3);    // Enable 8 bit mode
   83bb8:	d28a0987 	mov	x7, #0x504c                	// #20556
    put32(AUX_MU_MCR_REG, 0);    // Set RTS line to be always high
    put32(AUX_MU_BAUD_REG, 270); // Set baud rate to 115200

    put32(AUX_MU_CNTL_REG, 3); // Finally, enable transmitter and receiver
}
   83bbc:	f9400bf3 	ldr	x19, [sp, #16]
    put32(AUX_MU_IIR_REG, FLUSH_UART); // flush FIFO
   83bc0:	b9000003 	str	w3, [x0]
    put32(AUX_MU_IER_REG, (3 << 2) | (0xf << 4)); // bit 7:4 3:2 must be 1
   83bc4:	d28a0880 	mov	x0, #0x5044                	// #20548
    put32(AUX_ENABLES, 1);     // Enable mini uart (this also enables access to it registers)
   83bc8:	52800023 	mov	w3, #0x1                   	// #1
    put32(AUX_MU_IER_REG, (3 << 2) | (0xf << 4)); // bit 7:4 3:2 must be 1
   83bcc:	f2a7e420 	movk	x0, #0x3f21, lsl #16
    put32(AUX_ENABLES, 1);     // Enable mini uart (this also enables access to it registers)
   83bd0:	b9000023 	str	w3, [x1]
    put32(AUX_MU_CNTL_REG, 0); // Disable auto flow control and disable receiver and transmitter (for now)
   83bd4:	b900005f 	str	wzr, [x2]
    put32(AUX_MU_IER_REG, (3 << 2) | (0xf << 4)); // bit 7:4 3:2 must be 1
   83bd8:	52801f81 	mov	w1, #0xfc                  	// #252
   83bdc:	b9000001 	str	w1, [x0]
    put32(AUX_MU_LCR_REG, 3);    // Enable 8 bit mode
   83be0:	f2a7e427 	movk	x7, #0x3f21, lsl #16
    put32(AUX_MU_MCR_REG, 0);    // Set RTS line to be always high
   83be4:	d28a0a06 	mov	x6, #0x5050                	// #20560
    put32(AUX_MU_BAUD_REG, 270); // Set baud rate to 115200
   83be8:	d28a0d04 	mov	x4, #0x5068                	// #20584
		unsigned int ier = get32(AUX_MU_IER_REG); 
   83bec:	b9400001 	ldr	w1, [x0]
    put32(AUX_MU_MCR_REG, 0);    // Set RTS line to be always high
   83bf0:	f2a7e426 	movk	x6, #0x3f21, lsl #16
    put32(AUX_MU_LCR_REG, 3);    // Enable 8 bit mode
   83bf4:	52800063 	mov	w3, #0x3                   	// #3
    put32(AUX_MU_BAUD_REG, 270); // Set baud rate to 115200
   83bf8:	f2a7e424 	movk	x4, #0x3f21, lsl #16
  		put32(AUX_MU_IER_REG, ier | AUX_MU_IER_RXIRQ_ENABLE); //!STUDENT_DONOT_SEE
   83bfc:	32000021 	orr	w1, w1, #0x1
   83c00:	b9000001 	str	w1, [x0]
    put32(AUX_MU_LCR_REG, 3);    // Enable 8 bit mode
   83c04:	b90000e3 	str	w3, [x7]
    put32(AUX_MU_BAUD_REG, 270); // Set baud rate to 115200
   83c08:	528021c5 	mov	w5, #0x10e                 	// #270
    put32(AUX_MU_MCR_REG, 0);    // Set RTS line to be always high
   83c0c:	b90000df 	str	wzr, [x6]
    put32(AUX_MU_BAUD_REG, 270); // Set baud rate to 115200
   83c10:	b9000085 	str	w5, [x4]
    put32(AUX_MU_CNTL_REG, 3); // Finally, enable transmitter and receiver
   83c14:	b9000043 	str	w3, [x2]
}
   83c18:	a8c27bfd 	ldp	x29, x30, [sp], #32
   83c1c:	d65f03c0 	ret
	...

0000000000084000 <vectors>:
.align	11
.globl vectors 
vectors:
	/* EL1t -- Exception happens when CPU is at EL1 while the stack pointer (SP)
	was set to be shared with EL0 */
	ventry	sync_invalid_el1t			// Synchronous EL1t
   84000:	140001e1 	b	84784 <sync_invalid_el1t>
   84004:	d503201f 	nop
   84008:	d503201f 	nop
   8400c:	d503201f 	nop
   84010:	d503201f 	nop
   84014:	d503201f 	nop
   84018:	d503201f 	nop
   8401c:	d503201f 	nop
   84020:	d503201f 	nop
   84024:	d503201f 	nop
   84028:	d503201f 	nop
   8402c:	d503201f 	nop
   84030:	d503201f 	nop
   84034:	d503201f 	nop
   84038:	d503201f 	nop
   8403c:	d503201f 	nop
   84040:	d503201f 	nop
   84044:	d503201f 	nop
   84048:	d503201f 	nop
   8404c:	d503201f 	nop
   84050:	d503201f 	nop
   84054:	d503201f 	nop
   84058:	d503201f 	nop
   8405c:	d503201f 	nop
   84060:	d503201f 	nop
   84064:	d503201f 	nop
   84068:	d503201f 	nop
   8406c:	d503201f 	nop
   84070:	d503201f 	nop
   84074:	d503201f 	nop
   84078:	d503201f 	nop
   8407c:	d503201f 	nop
	ventry	irq_invalid_el1t			// IRQ EL1t
   84080:	140001d9 	b	847e4 <irq_invalid_el1t>
   84084:	d503201f 	nop
   84088:	d503201f 	nop
   8408c:	d503201f 	nop
   84090:	d503201f 	nop
   84094:	d503201f 	nop
   84098:	d503201f 	nop
   8409c:	d503201f 	nop
   840a0:	d503201f 	nop
   840a4:	d503201f 	nop
   840a8:	d503201f 	nop
   840ac:	d503201f 	nop
   840b0:	d503201f 	nop
   840b4:	d503201f 	nop
   840b8:	d503201f 	nop
   840bc:	d503201f 	nop
   840c0:	d503201f 	nop
   840c4:	d503201f 	nop
   840c8:	d503201f 	nop
   840cc:	d503201f 	nop
   840d0:	d503201f 	nop
   840d4:	d503201f 	nop
   840d8:	d503201f 	nop
   840dc:	d503201f 	nop
   840e0:	d503201f 	nop
   840e4:	d503201f 	nop
   840e8:	d503201f 	nop
   840ec:	d503201f 	nop
   840f0:	d503201f 	nop
   840f4:	d503201f 	nop
   840f8:	d503201f 	nop
   840fc:	d503201f 	nop
	ventry	fiq_invalid_el1t			// FIQ EL1t
   84100:	140001d1 	b	84844 <fiq_invalid_el1t>
   84104:	d503201f 	nop
   84108:	d503201f 	nop
   8410c:	d503201f 	nop
   84110:	d503201f 	nop
   84114:	d503201f 	nop
   84118:	d503201f 	nop
   8411c:	d503201f 	nop
   84120:	d503201f 	nop
   84124:	d503201f 	nop
   84128:	d503201f 	nop
   8412c:	d503201f 	nop
   84130:	d503201f 	nop
   84134:	d503201f 	nop
   84138:	d503201f 	nop
   8413c:	d503201f 	nop
   84140:	d503201f 	nop
   84144:	d503201f 	nop
   84148:	d503201f 	nop
   8414c:	d503201f 	nop
   84150:	d503201f 	nop
   84154:	d503201f 	nop
   84158:	d503201f 	nop
   8415c:	d503201f 	nop
   84160:	d503201f 	nop
   84164:	d503201f 	nop
   84168:	d503201f 	nop
   8416c:	d503201f 	nop
   84170:	d503201f 	nop
   84174:	d503201f 	nop
   84178:	d503201f 	nop
   8417c:	d503201f 	nop
	ventry	error_invalid_el1t			// Error EL1t
   84180:	140001c9 	b	848a4 <error_invalid_el1t>
   84184:	d503201f 	nop
   84188:	d503201f 	nop
   8418c:	d503201f 	nop
   84190:	d503201f 	nop
   84194:	d503201f 	nop
   84198:	d503201f 	nop
   8419c:	d503201f 	nop
   841a0:	d503201f 	nop
   841a4:	d503201f 	nop
   841a8:	d503201f 	nop
   841ac:	d503201f 	nop
   841b0:	d503201f 	nop
   841b4:	d503201f 	nop
   841b8:	d503201f 	nop
   841bc:	d503201f 	nop
   841c0:	d503201f 	nop
   841c4:	d503201f 	nop
   841c8:	d503201f 	nop
   841cc:	d503201f 	nop
   841d0:	d503201f 	nop
   841d4:	d503201f 	nop
   841d8:	d503201f 	nop
   841dc:	d503201f 	nop
   841e0:	d503201f 	nop
   841e4:	d503201f 	nop
   841e8:	d503201f 	nop
   841ec:	d503201f 	nop
   841f0:	d503201f 	nop
   841f4:	d503201f 	nop
   841f8:	d503201f 	nop
   841fc:	d503201f 	nop

	/* EL1h -- Exception happens at EL1 at the time when a dedicated SP was
	 	allocated for EL1. This is the mode that our kernel is currently
	 	using */
	ventry	sync_invalid_el1h			// Synchronous EL1h
   84200:	140001c1 	b	84904 <sync_invalid_el1h>
   84204:	d503201f 	nop
   84208:	d503201f 	nop
   8420c:	d503201f 	nop
   84210:	d503201f 	nop
   84214:	d503201f 	nop
   84218:	d503201f 	nop
   8421c:	d503201f 	nop
   84220:	d503201f 	nop
   84224:	d503201f 	nop
   84228:	d503201f 	nop
   8422c:	d503201f 	nop
   84230:	d503201f 	nop
   84234:	d503201f 	nop
   84238:	d503201f 	nop
   8423c:	d503201f 	nop
   84240:	d503201f 	nop
   84244:	d503201f 	nop
   84248:	d503201f 	nop
   8424c:	d503201f 	nop
   84250:	d503201f 	nop
   84254:	d503201f 	nop
   84258:	d503201f 	nop
   8425c:	d503201f 	nop
   84260:	d503201f 	nop
   84264:	d503201f 	nop
   84268:	d503201f 	nop
   8426c:	d503201f 	nop
   84270:	d503201f 	nop
   84274:	d503201f 	nop
   84278:	d503201f 	nop
   8427c:	d503201f 	nop
	// IRQ EL1h
	ventry	el1_irq						//!STUDENT_WILL_SEE_AS (ventry	irq_invalid_el1h)
   84280:	140002c1 	b	84d84 <el1_irq>
   84284:	d503201f 	nop
   84288:	d503201f 	nop
   8428c:	d503201f 	nop
   84290:	d503201f 	nop
   84294:	d503201f 	nop
   84298:	d503201f 	nop
   8429c:	d503201f 	nop
   842a0:	d503201f 	nop
   842a4:	d503201f 	nop
   842a8:	d503201f 	nop
   842ac:	d503201f 	nop
   842b0:	d503201f 	nop
   842b4:	d503201f 	nop
   842b8:	d503201f 	nop
   842bc:	d503201f 	nop
   842c0:	d503201f 	nop
   842c4:	d503201f 	nop
   842c8:	d503201f 	nop
   842cc:	d503201f 	nop
   842d0:	d503201f 	nop
   842d4:	d503201f 	nop
   842d8:	d503201f 	nop
   842dc:	d503201f 	nop
   842e0:	d503201f 	nop
   842e4:	d503201f 	nop
   842e8:	d503201f 	nop
   842ec:	d503201f 	nop
   842f0:	d503201f 	nop
   842f4:	d503201f 	nop
   842f8:	d503201f 	nop
   842fc:	d503201f 	nop
	ventry	fiq_invalid_el1h			// FIQ EL1h
   84300:	14000199 	b	84964 <fiq_invalid_el1h>
   84304:	d503201f 	nop
   84308:	d503201f 	nop
   8430c:	d503201f 	nop
   84310:	d503201f 	nop
   84314:	d503201f 	nop
   84318:	d503201f 	nop
   8431c:	d503201f 	nop
   84320:	d503201f 	nop
   84324:	d503201f 	nop
   84328:	d503201f 	nop
   8432c:	d503201f 	nop
   84330:	d503201f 	nop
   84334:	d503201f 	nop
   84338:	d503201f 	nop
   8433c:	d503201f 	nop
   84340:	d503201f 	nop
   84344:	d503201f 	nop
   84348:	d503201f 	nop
   8434c:	d503201f 	nop
   84350:	d503201f 	nop
   84354:	d503201f 	nop
   84358:	d503201f 	nop
   8435c:	d503201f 	nop
   84360:	d503201f 	nop
   84364:	d503201f 	nop
   84368:	d503201f 	nop
   8436c:	d503201f 	nop
   84370:	d503201f 	nop
   84374:	d503201f 	nop
   84378:	d503201f 	nop
   8437c:	d503201f 	nop
	ventry	error_invalid_el1h			// Error EL1h
   84380:	14000191 	b	849c4 <error_invalid_el1h>
   84384:	d503201f 	nop
   84388:	d503201f 	nop
   8438c:	d503201f 	nop
   84390:	d503201f 	nop
   84394:	d503201f 	nop
   84398:	d503201f 	nop
   8439c:	d503201f 	nop
   843a0:	d503201f 	nop
   843a4:	d503201f 	nop
   843a8:	d503201f 	nop
   843ac:	d503201f 	nop
   843b0:	d503201f 	nop
   843b4:	d503201f 	nop
   843b8:	d503201f 	nop
   843bc:	d503201f 	nop
   843c0:	d503201f 	nop
   843c4:	d503201f 	nop
   843c8:	d503201f 	nop
   843cc:	d503201f 	nop
   843d0:	d503201f 	nop
   843d4:	d503201f 	nop
   843d8:	d503201f 	nop
   843dc:	d503201f 	nop
   843e0:	d503201f 	nop
   843e4:	d503201f 	nop
   843e8:	d503201f 	nop
   843ec:	d503201f 	nop
   843f0:	d503201f 	nop
   843f4:	d503201f 	nop
   843f8:	d503201f 	nop
   843fc:	d503201f 	nop

	/*  EL0_64 -- Exception is taken from EL0 executing in 64-bit mode. 
		The exceptions caused in 64-bit user programs */
	ventry	sync_invalid_el0_64			// Synchronous 64-bit EL0
   84400:	14000189 	b	84a24 <sync_invalid_el0_64>
   84404:	d503201f 	nop
   84408:	d503201f 	nop
   8440c:	d503201f 	nop
   84410:	d503201f 	nop
   84414:	d503201f 	nop
   84418:	d503201f 	nop
   8441c:	d503201f 	nop
   84420:	d503201f 	nop
   84424:	d503201f 	nop
   84428:	d503201f 	nop
   8442c:	d503201f 	nop
   84430:	d503201f 	nop
   84434:	d503201f 	nop
   84438:	d503201f 	nop
   8443c:	d503201f 	nop
   84440:	d503201f 	nop
   84444:	d503201f 	nop
   84448:	d503201f 	nop
   8444c:	d503201f 	nop
   84450:	d503201f 	nop
   84454:	d503201f 	nop
   84458:	d503201f 	nop
   8445c:	d503201f 	nop
   84460:	d503201f 	nop
   84464:	d503201f 	nop
   84468:	d503201f 	nop
   8446c:	d503201f 	nop
   84470:	d503201f 	nop
   84474:	d503201f 	nop
   84478:	d503201f 	nop
   8447c:	d503201f 	nop
	ventry	irq_invalid_el0_64			// IRQ 64-bit EL0
   84480:	14000181 	b	84a84 <irq_invalid_el0_64>
   84484:	d503201f 	nop
   84488:	d503201f 	nop
   8448c:	d503201f 	nop
   84490:	d503201f 	nop
   84494:	d503201f 	nop
   84498:	d503201f 	nop
   8449c:	d503201f 	nop
   844a0:	d503201f 	nop
   844a4:	d503201f 	nop
   844a8:	d503201f 	nop
   844ac:	d503201f 	nop
   844b0:	d503201f 	nop
   844b4:	d503201f 	nop
   844b8:	d503201f 	nop
   844bc:	d503201f 	nop
   844c0:	d503201f 	nop
   844c4:	d503201f 	nop
   844c8:	d503201f 	nop
   844cc:	d503201f 	nop
   844d0:	d503201f 	nop
   844d4:	d503201f 	nop
   844d8:	d503201f 	nop
   844dc:	d503201f 	nop
   844e0:	d503201f 	nop
   844e4:	d503201f 	nop
   844e8:	d503201f 	nop
   844ec:	d503201f 	nop
   844f0:	d503201f 	nop
   844f4:	d503201f 	nop
   844f8:	d503201f 	nop
   844fc:	d503201f 	nop
	ventry	fiq_invalid_el0_64			// FIQ 64-bit EL0
   84500:	14000191 	b	84b44 <fiq_invalid_el0_64>
   84504:	d503201f 	nop
   84508:	d503201f 	nop
   8450c:	d503201f 	nop
   84510:	d503201f 	nop
   84514:	d503201f 	nop
   84518:	d503201f 	nop
   8451c:	d503201f 	nop
   84520:	d503201f 	nop
   84524:	d503201f 	nop
   84528:	d503201f 	nop
   8452c:	d503201f 	nop
   84530:	d503201f 	nop
   84534:	d503201f 	nop
   84538:	d503201f 	nop
   8453c:	d503201f 	nop
   84540:	d503201f 	nop
   84544:	d503201f 	nop
   84548:	d503201f 	nop
   8454c:	d503201f 	nop
   84550:	d503201f 	nop
   84554:	d503201f 	nop
   84558:	d503201f 	nop
   8455c:	d503201f 	nop
   84560:	d503201f 	nop
   84564:	d503201f 	nop
   84568:	d503201f 	nop
   8456c:	d503201f 	nop
   84570:	d503201f 	nop
   84574:	d503201f 	nop
   84578:	d503201f 	nop
   8457c:	d503201f 	nop
	ventry	error_invalid_el0_64			// Error 64-bit EL0
   84580:	14000189 	b	84ba4 <error_invalid_el0_64>
   84584:	d503201f 	nop
   84588:	d503201f 	nop
   8458c:	d503201f 	nop
   84590:	d503201f 	nop
   84594:	d503201f 	nop
   84598:	d503201f 	nop
   8459c:	d503201f 	nop
   845a0:	d503201f 	nop
   845a4:	d503201f 	nop
   845a8:	d503201f 	nop
   845ac:	d503201f 	nop
   845b0:	d503201f 	nop
   845b4:	d503201f 	nop
   845b8:	d503201f 	nop
   845bc:	d503201f 	nop
   845c0:	d503201f 	nop
   845c4:	d503201f 	nop
   845c8:	d503201f 	nop
   845cc:	d503201f 	nop
   845d0:	d503201f 	nop
   845d4:	d503201f 	nop
   845d8:	d503201f 	nop
   845dc:	d503201f 	nop
   845e0:	d503201f 	nop
   845e4:	d503201f 	nop
   845e8:	d503201f 	nop
   845ec:	d503201f 	nop
   845f0:	d503201f 	nop
   845f4:	d503201f 	nop
   845f8:	d503201f 	nop
   845fc:	d503201f 	nop

	/*  EL0_32 -- Exception is taken from EL0 executing in 32-bit mode
			The exceptions caused in 32-bit user programs  */
	ventry	sync_invalid_el0_32			// Synchronous 32-bit EL0
   84600:	14000181 	b	84c04 <sync_invalid_el0_32>
   84604:	d503201f 	nop
   84608:	d503201f 	nop
   8460c:	d503201f 	nop
   84610:	d503201f 	nop
   84614:	d503201f 	nop
   84618:	d503201f 	nop
   8461c:	d503201f 	nop
   84620:	d503201f 	nop
   84624:	d503201f 	nop
   84628:	d503201f 	nop
   8462c:	d503201f 	nop
   84630:	d503201f 	nop
   84634:	d503201f 	nop
   84638:	d503201f 	nop
   8463c:	d503201f 	nop
   84640:	d503201f 	nop
   84644:	d503201f 	nop
   84648:	d503201f 	nop
   8464c:	d503201f 	nop
   84650:	d503201f 	nop
   84654:	d503201f 	nop
   84658:	d503201f 	nop
   8465c:	d503201f 	nop
   84660:	d503201f 	nop
   84664:	d503201f 	nop
   84668:	d503201f 	nop
   8466c:	d503201f 	nop
   84670:	d503201f 	nop
   84674:	d503201f 	nop
   84678:	d503201f 	nop
   8467c:	d503201f 	nop
	ventry	irq_invalid_el0_32			// IRQ 32-bit EL0
   84680:	14000179 	b	84c64 <irq_invalid_el0_32>
   84684:	d503201f 	nop
   84688:	d503201f 	nop
   8468c:	d503201f 	nop
   84690:	d503201f 	nop
   84694:	d503201f 	nop
   84698:	d503201f 	nop
   8469c:	d503201f 	nop
   846a0:	d503201f 	nop
   846a4:	d503201f 	nop
   846a8:	d503201f 	nop
   846ac:	d503201f 	nop
   846b0:	d503201f 	nop
   846b4:	d503201f 	nop
   846b8:	d503201f 	nop
   846bc:	d503201f 	nop
   846c0:	d503201f 	nop
   846c4:	d503201f 	nop
   846c8:	d503201f 	nop
   846cc:	d503201f 	nop
   846d0:	d503201f 	nop
   846d4:	d503201f 	nop
   846d8:	d503201f 	nop
   846dc:	d503201f 	nop
   846e0:	d503201f 	nop
   846e4:	d503201f 	nop
   846e8:	d503201f 	nop
   846ec:	d503201f 	nop
   846f0:	d503201f 	nop
   846f4:	d503201f 	nop
   846f8:	d503201f 	nop
   846fc:	d503201f 	nop
	ventry	fiq_invalid_el0_32			// FIQ 32-bit EL0
   84700:	14000171 	b	84cc4 <fiq_invalid_el0_32>
   84704:	d503201f 	nop
   84708:	d503201f 	nop
   8470c:	d503201f 	nop
   84710:	d503201f 	nop
   84714:	d503201f 	nop
   84718:	d503201f 	nop
   8471c:	d503201f 	nop
   84720:	d503201f 	nop
   84724:	d503201f 	nop
   84728:	d503201f 	nop
   8472c:	d503201f 	nop
   84730:	d503201f 	nop
   84734:	d503201f 	nop
   84738:	d503201f 	nop
   8473c:	d503201f 	nop
   84740:	d503201f 	nop
   84744:	d503201f 	nop
   84748:	d503201f 	nop
   8474c:	d503201f 	nop
   84750:	d503201f 	nop
   84754:	d503201f 	nop
   84758:	d503201f 	nop
   8475c:	d503201f 	nop
   84760:	d503201f 	nop
   84764:	d503201f 	nop
   84768:	d503201f 	nop
   8476c:	d503201f 	nop
   84770:	d503201f 	nop
   84774:	d503201f 	nop
   84778:	d503201f 	nop
   8477c:	d503201f 	nop
	ventry	error_invalid_el0_32			// Error 32-bit EL0
   84780:	14000169 	b	84d24 <error_invalid_el0_32>

0000000000084784 <sync_invalid_el1t>:

sync_invalid_el1t:
	handle_invalid_entry  SYNC_INVALID_EL1t
   84784:	d10483ff 	sub	sp, sp, #0x120
   84788:	a90007e0 	stp	x0, x1, [sp]
   8478c:	a9010fe2 	stp	x2, x3, [sp, #16]
   84790:	a90217e4 	stp	x4, x5, [sp, #32]
   84794:	a9031fe6 	stp	x6, x7, [sp, #48]
   84798:	a90427e8 	stp	x8, x9, [sp, #64]
   8479c:	a9052fea 	stp	x10, x11, [sp, #80]
   847a0:	a90637ec 	stp	x12, x13, [sp, #96]
   847a4:	a9073fee 	stp	x14, x15, [sp, #112]
   847a8:	a90847f0 	stp	x16, x17, [sp, #128]
   847ac:	a9094ff2 	stp	x18, x19, [sp, #144]
   847b0:	a90a57f4 	stp	x20, x21, [sp, #160]
   847b4:	a90b5ff6 	stp	x22, x23, [sp, #176]
   847b8:	a90c67f8 	stp	x24, x25, [sp, #192]
   847bc:	a90d6ffa 	stp	x26, x27, [sp, #208]
   847c0:	a90e77fc 	stp	x28, x29, [sp, #224]
   847c4:	f9007bfe 	str	x30, [sp, #240]
   847c8:	d2800000 	mov	x0, #0x0                   	// #0
   847cc:	d5385201 	mrs	x1, esr_el1
   847d0:	d5384022 	mrs	x2, elr_el1
   847d4:	d5386003 	mrs	x3, far_el1
   847d8:	97fff05a 	bl	80940 <show_invalid_entry_message>
   847dc:	d50342df 	msr	daifset, #0x2
   847e0:	1400018d 	b	84e14 <err_hang>

00000000000847e4 <irq_invalid_el1t>:

irq_invalid_el1t:
	handle_invalid_entry  IRQ_INVALID_EL1t
   847e4:	d10483ff 	sub	sp, sp, #0x120
   847e8:	a90007e0 	stp	x0, x1, [sp]
   847ec:	a9010fe2 	stp	x2, x3, [sp, #16]
   847f0:	a90217e4 	stp	x4, x5, [sp, #32]
   847f4:	a9031fe6 	stp	x6, x7, [sp, #48]
   847f8:	a90427e8 	stp	x8, x9, [sp, #64]
   847fc:	a9052fea 	stp	x10, x11, [sp, #80]
   84800:	a90637ec 	stp	x12, x13, [sp, #96]
   84804:	a9073fee 	stp	x14, x15, [sp, #112]
   84808:	a90847f0 	stp	x16, x17, [sp, #128]
   8480c:	a9094ff2 	stp	x18, x19, [sp, #144]
   84810:	a90a57f4 	stp	x20, x21, [sp, #160]
   84814:	a90b5ff6 	stp	x22, x23, [sp, #176]
   84818:	a90c67f8 	stp	x24, x25, [sp, #192]
   8481c:	a90d6ffa 	stp	x26, x27, [sp, #208]
   84820:	a90e77fc 	stp	x28, x29, [sp, #224]
   84824:	f9007bfe 	str	x30, [sp, #240]
   84828:	d2800020 	mov	x0, #0x1                   	// #1
   8482c:	d5385201 	mrs	x1, esr_el1
   84830:	d5384022 	mrs	x2, elr_el1
   84834:	d5386003 	mrs	x3, far_el1
   84838:	97fff042 	bl	80940 <show_invalid_entry_message>
   8483c:	d50342df 	msr	daifset, #0x2
   84840:	14000175 	b	84e14 <err_hang>

0000000000084844 <fiq_invalid_el1t>:

fiq_invalid_el1t:
	handle_invalid_entry  FIQ_INVALID_EL1t
   84844:	d10483ff 	sub	sp, sp, #0x120
   84848:	a90007e0 	stp	x0, x1, [sp]
   8484c:	a9010fe2 	stp	x2, x3, [sp, #16]
   84850:	a90217e4 	stp	x4, x5, [sp, #32]
   84854:	a9031fe6 	stp	x6, x7, [sp, #48]
   84858:	a90427e8 	stp	x8, x9, [sp, #64]
   8485c:	a9052fea 	stp	x10, x11, [sp, #80]
   84860:	a90637ec 	stp	x12, x13, [sp, #96]
   84864:	a9073fee 	stp	x14, x15, [sp, #112]
   84868:	a90847f0 	stp	x16, x17, [sp, #128]
   8486c:	a9094ff2 	stp	x18, x19, [sp, #144]
   84870:	a90a57f4 	stp	x20, x21, [sp, #160]
   84874:	a90b5ff6 	stp	x22, x23, [sp, #176]
   84878:	a90c67f8 	stp	x24, x25, [sp, #192]
   8487c:	a90d6ffa 	stp	x26, x27, [sp, #208]
   84880:	a90e77fc 	stp	x28, x29, [sp, #224]
   84884:	f9007bfe 	str	x30, [sp, #240]
   84888:	d2800040 	mov	x0, #0x2                   	// #2
   8488c:	d5385201 	mrs	x1, esr_el1
   84890:	d5384022 	mrs	x2, elr_el1
   84894:	d5386003 	mrs	x3, far_el1
   84898:	97fff02a 	bl	80940 <show_invalid_entry_message>
   8489c:	d50342df 	msr	daifset, #0x2
   848a0:	1400015d 	b	84e14 <err_hang>

00000000000848a4 <error_invalid_el1t>:

error_invalid_el1t:
	handle_invalid_entry  ERROR_INVALID_EL1t
   848a4:	d10483ff 	sub	sp, sp, #0x120
   848a8:	a90007e0 	stp	x0, x1, [sp]
   848ac:	a9010fe2 	stp	x2, x3, [sp, #16]
   848b0:	a90217e4 	stp	x4, x5, [sp, #32]
   848b4:	a9031fe6 	stp	x6, x7, [sp, #48]
   848b8:	a90427e8 	stp	x8, x9, [sp, #64]
   848bc:	a9052fea 	stp	x10, x11, [sp, #80]
   848c0:	a90637ec 	stp	x12, x13, [sp, #96]
   848c4:	a9073fee 	stp	x14, x15, [sp, #112]
   848c8:	a90847f0 	stp	x16, x17, [sp, #128]
   848cc:	a9094ff2 	stp	x18, x19, [sp, #144]
   848d0:	a90a57f4 	stp	x20, x21, [sp, #160]
   848d4:	a90b5ff6 	stp	x22, x23, [sp, #176]
   848d8:	a90c67f8 	stp	x24, x25, [sp, #192]
   848dc:	a90d6ffa 	stp	x26, x27, [sp, #208]
   848e0:	a90e77fc 	stp	x28, x29, [sp, #224]
   848e4:	f9007bfe 	str	x30, [sp, #240]
   848e8:	d2800060 	mov	x0, #0x3                   	// #3
   848ec:	d5385201 	mrs	x1, esr_el1
   848f0:	d5384022 	mrs	x2, elr_el1
   848f4:	d5386003 	mrs	x3, far_el1
   848f8:	97fff012 	bl	80940 <show_invalid_entry_message>
   848fc:	d50342df 	msr	daifset, #0x2
   84900:	14000145 	b	84e14 <err_hang>

0000000000084904 <sync_invalid_el1h>:

sync_invalid_el1h:
	handle_invalid_entry  SYNC_INVALID_EL1h
   84904:	d10483ff 	sub	sp, sp, #0x120
   84908:	a90007e0 	stp	x0, x1, [sp]
   8490c:	a9010fe2 	stp	x2, x3, [sp, #16]
   84910:	a90217e4 	stp	x4, x5, [sp, #32]
   84914:	a9031fe6 	stp	x6, x7, [sp, #48]
   84918:	a90427e8 	stp	x8, x9, [sp, #64]
   8491c:	a9052fea 	stp	x10, x11, [sp, #80]
   84920:	a90637ec 	stp	x12, x13, [sp, #96]
   84924:	a9073fee 	stp	x14, x15, [sp, #112]
   84928:	a90847f0 	stp	x16, x17, [sp, #128]
   8492c:	a9094ff2 	stp	x18, x19, [sp, #144]
   84930:	a90a57f4 	stp	x20, x21, [sp, #160]
   84934:	a90b5ff6 	stp	x22, x23, [sp, #176]
   84938:	a90c67f8 	stp	x24, x25, [sp, #192]
   8493c:	a90d6ffa 	stp	x26, x27, [sp, #208]
   84940:	a90e77fc 	stp	x28, x29, [sp, #224]
   84944:	f9007bfe 	str	x30, [sp, #240]
   84948:	d2800080 	mov	x0, #0x4                   	// #4
   8494c:	d5385201 	mrs	x1, esr_el1
   84950:	d5384022 	mrs	x2, elr_el1
   84954:	d5386003 	mrs	x3, far_el1
   84958:	97ffeffa 	bl	80940 <show_invalid_entry_message>
   8495c:	d50342df 	msr	daifset, #0x2
   84960:	1400012d 	b	84e14 <err_hang>

0000000000084964 <fiq_invalid_el1h>:

fiq_invalid_el1h:
	handle_invalid_entry  FIQ_INVALID_EL1h
   84964:	d10483ff 	sub	sp, sp, #0x120
   84968:	a90007e0 	stp	x0, x1, [sp]
   8496c:	a9010fe2 	stp	x2, x3, [sp, #16]
   84970:	a90217e4 	stp	x4, x5, [sp, #32]
   84974:	a9031fe6 	stp	x6, x7, [sp, #48]
   84978:	a90427e8 	stp	x8, x9, [sp, #64]
   8497c:	a9052fea 	stp	x10, x11, [sp, #80]
   84980:	a90637ec 	stp	x12, x13, [sp, #96]
   84984:	a9073fee 	stp	x14, x15, [sp, #112]
   84988:	a90847f0 	stp	x16, x17, [sp, #128]
   8498c:	a9094ff2 	stp	x18, x19, [sp, #144]
   84990:	a90a57f4 	stp	x20, x21, [sp, #160]
   84994:	a90b5ff6 	stp	x22, x23, [sp, #176]
   84998:	a90c67f8 	stp	x24, x25, [sp, #192]
   8499c:	a90d6ffa 	stp	x26, x27, [sp, #208]
   849a0:	a90e77fc 	stp	x28, x29, [sp, #224]
   849a4:	f9007bfe 	str	x30, [sp, #240]
   849a8:	d28000c0 	mov	x0, #0x6                   	// #6
   849ac:	d5385201 	mrs	x1, esr_el1
   849b0:	d5384022 	mrs	x2, elr_el1
   849b4:	d5386003 	mrs	x3, far_el1
   849b8:	97ffefe2 	bl	80940 <show_invalid_entry_message>
   849bc:	d50342df 	msr	daifset, #0x2
   849c0:	14000115 	b	84e14 <err_hang>

00000000000849c4 <error_invalid_el1h>:

error_invalid_el1h:
	handle_invalid_entry  ERROR_INVALID_EL1h
   849c4:	d10483ff 	sub	sp, sp, #0x120
   849c8:	a90007e0 	stp	x0, x1, [sp]
   849cc:	a9010fe2 	stp	x2, x3, [sp, #16]
   849d0:	a90217e4 	stp	x4, x5, [sp, #32]
   849d4:	a9031fe6 	stp	x6, x7, [sp, #48]
   849d8:	a90427e8 	stp	x8, x9, [sp, #64]
   849dc:	a9052fea 	stp	x10, x11, [sp, #80]
   849e0:	a90637ec 	stp	x12, x13, [sp, #96]
   849e4:	a9073fee 	stp	x14, x15, [sp, #112]
   849e8:	a90847f0 	stp	x16, x17, [sp, #128]
   849ec:	a9094ff2 	stp	x18, x19, [sp, #144]
   849f0:	a90a57f4 	stp	x20, x21, [sp, #160]
   849f4:	a90b5ff6 	stp	x22, x23, [sp, #176]
   849f8:	a90c67f8 	stp	x24, x25, [sp, #192]
   849fc:	a90d6ffa 	stp	x26, x27, [sp, #208]
   84a00:	a90e77fc 	stp	x28, x29, [sp, #224]
   84a04:	f9007bfe 	str	x30, [sp, #240]
   84a08:	d28000e0 	mov	x0, #0x7                   	// #7
   84a0c:	d5385201 	mrs	x1, esr_el1
   84a10:	d5384022 	mrs	x2, elr_el1
   84a14:	d5386003 	mrs	x3, far_el1
   84a18:	97ffefca 	bl	80940 <show_invalid_entry_message>
   84a1c:	d50342df 	msr	daifset, #0x2
   84a20:	140000fd 	b	84e14 <err_hang>

0000000000084a24 <sync_invalid_el0_64>:

sync_invalid_el0_64:
	handle_invalid_entry  SYNC_INVALID_EL0_64
   84a24:	d10483ff 	sub	sp, sp, #0x120
   84a28:	a90007e0 	stp	x0, x1, [sp]
   84a2c:	a9010fe2 	stp	x2, x3, [sp, #16]
   84a30:	a90217e4 	stp	x4, x5, [sp, #32]
   84a34:	a9031fe6 	stp	x6, x7, [sp, #48]
   84a38:	a90427e8 	stp	x8, x9, [sp, #64]
   84a3c:	a9052fea 	stp	x10, x11, [sp, #80]
   84a40:	a90637ec 	stp	x12, x13, [sp, #96]
   84a44:	a9073fee 	stp	x14, x15, [sp, #112]
   84a48:	a90847f0 	stp	x16, x17, [sp, #128]
   84a4c:	a9094ff2 	stp	x18, x19, [sp, #144]
   84a50:	a90a57f4 	stp	x20, x21, [sp, #160]
   84a54:	a90b5ff6 	stp	x22, x23, [sp, #176]
   84a58:	a90c67f8 	stp	x24, x25, [sp, #192]
   84a5c:	a90d6ffa 	stp	x26, x27, [sp, #208]
   84a60:	a90e77fc 	stp	x28, x29, [sp, #224]
   84a64:	f9007bfe 	str	x30, [sp, #240]
   84a68:	d2800100 	mov	x0, #0x8                   	// #8
   84a6c:	d5385201 	mrs	x1, esr_el1
   84a70:	d5384022 	mrs	x2, elr_el1
   84a74:	d5386003 	mrs	x3, far_el1
   84a78:	97ffefb2 	bl	80940 <show_invalid_entry_message>
   84a7c:	d50342df 	msr	daifset, #0x2
   84a80:	140000e5 	b	84e14 <err_hang>

0000000000084a84 <irq_invalid_el0_64>:

irq_invalid_el0_64:
	handle_invalid_entry  IRQ_INVALID_EL0_64
   84a84:	d10483ff 	sub	sp, sp, #0x120
   84a88:	a90007e0 	stp	x0, x1, [sp]
   84a8c:	a9010fe2 	stp	x2, x3, [sp, #16]
   84a90:	a90217e4 	stp	x4, x5, [sp, #32]
   84a94:	a9031fe6 	stp	x6, x7, [sp, #48]
   84a98:	a90427e8 	stp	x8, x9, [sp, #64]
   84a9c:	a9052fea 	stp	x10, x11, [sp, #80]
   84aa0:	a90637ec 	stp	x12, x13, [sp, #96]
   84aa4:	a9073fee 	stp	x14, x15, [sp, #112]
   84aa8:	a90847f0 	stp	x16, x17, [sp, #128]
   84aac:	a9094ff2 	stp	x18, x19, [sp, #144]
   84ab0:	a90a57f4 	stp	x20, x21, [sp, #160]
   84ab4:	a90b5ff6 	stp	x22, x23, [sp, #176]
   84ab8:	a90c67f8 	stp	x24, x25, [sp, #192]
   84abc:	a90d6ffa 	stp	x26, x27, [sp, #208]
   84ac0:	a90e77fc 	stp	x28, x29, [sp, #224]
   84ac4:	f9007bfe 	str	x30, [sp, #240]
   84ac8:	d2800120 	mov	x0, #0x9                   	// #9
   84acc:	d5385201 	mrs	x1, esr_el1
   84ad0:	d5384022 	mrs	x2, elr_el1
   84ad4:	d5386003 	mrs	x3, far_el1
   84ad8:	97ffef9a 	bl	80940 <show_invalid_entry_message>
   84adc:	d50342df 	msr	daifset, #0x2
   84ae0:	140000cd 	b	84e14 <err_hang>

0000000000084ae4 <irq_invalid_el1h>:

irq_invalid_el1h:
	handle_invalid_entry  IRQ_INVALID_EL1h
   84ae4:	d10483ff 	sub	sp, sp, #0x120
   84ae8:	a90007e0 	stp	x0, x1, [sp]
   84aec:	a9010fe2 	stp	x2, x3, [sp, #16]
   84af0:	a90217e4 	stp	x4, x5, [sp, #32]
   84af4:	a9031fe6 	stp	x6, x7, [sp, #48]
   84af8:	a90427e8 	stp	x8, x9, [sp, #64]
   84afc:	a9052fea 	stp	x10, x11, [sp, #80]
   84b00:	a90637ec 	stp	x12, x13, [sp, #96]
   84b04:	a9073fee 	stp	x14, x15, [sp, #112]
   84b08:	a90847f0 	stp	x16, x17, [sp, #128]
   84b0c:	a9094ff2 	stp	x18, x19, [sp, #144]
   84b10:	a90a57f4 	stp	x20, x21, [sp, #160]
   84b14:	a90b5ff6 	stp	x22, x23, [sp, #176]
   84b18:	a90c67f8 	stp	x24, x25, [sp, #192]
   84b1c:	a90d6ffa 	stp	x26, x27, [sp, #208]
   84b20:	a90e77fc 	stp	x28, x29, [sp, #224]
   84b24:	f9007bfe 	str	x30, [sp, #240]
   84b28:	d28000a0 	mov	x0, #0x5                   	// #5
   84b2c:	d5385201 	mrs	x1, esr_el1
   84b30:	d5384022 	mrs	x2, elr_el1
   84b34:	d5386003 	mrs	x3, far_el1
   84b38:	97ffef82 	bl	80940 <show_invalid_entry_message>
   84b3c:	d50342df 	msr	daifset, #0x2
   84b40:	140000b5 	b	84e14 <err_hang>

0000000000084b44 <fiq_invalid_el0_64>:
	
fiq_invalid_el0_64:
	handle_invalid_entry  FIQ_INVALID_EL0_64
   84b44:	d10483ff 	sub	sp, sp, #0x120
   84b48:	a90007e0 	stp	x0, x1, [sp]
   84b4c:	a9010fe2 	stp	x2, x3, [sp, #16]
   84b50:	a90217e4 	stp	x4, x5, [sp, #32]
   84b54:	a9031fe6 	stp	x6, x7, [sp, #48]
   84b58:	a90427e8 	stp	x8, x9, [sp, #64]
   84b5c:	a9052fea 	stp	x10, x11, [sp, #80]
   84b60:	a90637ec 	stp	x12, x13, [sp, #96]
   84b64:	a9073fee 	stp	x14, x15, [sp, #112]
   84b68:	a90847f0 	stp	x16, x17, [sp, #128]
   84b6c:	a9094ff2 	stp	x18, x19, [sp, #144]
   84b70:	a90a57f4 	stp	x20, x21, [sp, #160]
   84b74:	a90b5ff6 	stp	x22, x23, [sp, #176]
   84b78:	a90c67f8 	stp	x24, x25, [sp, #192]
   84b7c:	a90d6ffa 	stp	x26, x27, [sp, #208]
   84b80:	a90e77fc 	stp	x28, x29, [sp, #224]
   84b84:	f9007bfe 	str	x30, [sp, #240]
   84b88:	d2800140 	mov	x0, #0xa                   	// #10
   84b8c:	d5385201 	mrs	x1, esr_el1
   84b90:	d5384022 	mrs	x2, elr_el1
   84b94:	d5386003 	mrs	x3, far_el1
   84b98:	97ffef6a 	bl	80940 <show_invalid_entry_message>
   84b9c:	d50342df 	msr	daifset, #0x2
   84ba0:	1400009d 	b	84e14 <err_hang>

0000000000084ba4 <error_invalid_el0_64>:

error_invalid_el0_64:
	handle_invalid_entry  ERROR_INVALID_EL0_64
   84ba4:	d10483ff 	sub	sp, sp, #0x120
   84ba8:	a90007e0 	stp	x0, x1, [sp]
   84bac:	a9010fe2 	stp	x2, x3, [sp, #16]
   84bb0:	a90217e4 	stp	x4, x5, [sp, #32]
   84bb4:	a9031fe6 	stp	x6, x7, [sp, #48]
   84bb8:	a90427e8 	stp	x8, x9, [sp, #64]
   84bbc:	a9052fea 	stp	x10, x11, [sp, #80]
   84bc0:	a90637ec 	stp	x12, x13, [sp, #96]
   84bc4:	a9073fee 	stp	x14, x15, [sp, #112]
   84bc8:	a90847f0 	stp	x16, x17, [sp, #128]
   84bcc:	a9094ff2 	stp	x18, x19, [sp, #144]
   84bd0:	a90a57f4 	stp	x20, x21, [sp, #160]
   84bd4:	a90b5ff6 	stp	x22, x23, [sp, #176]
   84bd8:	a90c67f8 	stp	x24, x25, [sp, #192]
   84bdc:	a90d6ffa 	stp	x26, x27, [sp, #208]
   84be0:	a90e77fc 	stp	x28, x29, [sp, #224]
   84be4:	f9007bfe 	str	x30, [sp, #240]
   84be8:	d2800160 	mov	x0, #0xb                   	// #11
   84bec:	d5385201 	mrs	x1, esr_el1
   84bf0:	d5384022 	mrs	x2, elr_el1
   84bf4:	d5386003 	mrs	x3, far_el1
   84bf8:	97ffef52 	bl	80940 <show_invalid_entry_message>
   84bfc:	d50342df 	msr	daifset, #0x2
   84c00:	14000085 	b	84e14 <err_hang>

0000000000084c04 <sync_invalid_el0_32>:

sync_invalid_el0_32:
	handle_invalid_entry  SYNC_INVALID_EL0_32
   84c04:	d10483ff 	sub	sp, sp, #0x120
   84c08:	a90007e0 	stp	x0, x1, [sp]
   84c0c:	a9010fe2 	stp	x2, x3, [sp, #16]
   84c10:	a90217e4 	stp	x4, x5, [sp, #32]
   84c14:	a9031fe6 	stp	x6, x7, [sp, #48]
   84c18:	a90427e8 	stp	x8, x9, [sp, #64]
   84c1c:	a9052fea 	stp	x10, x11, [sp, #80]
   84c20:	a90637ec 	stp	x12, x13, [sp, #96]
   84c24:	a9073fee 	stp	x14, x15, [sp, #112]
   84c28:	a90847f0 	stp	x16, x17, [sp, #128]
   84c2c:	a9094ff2 	stp	x18, x19, [sp, #144]
   84c30:	a90a57f4 	stp	x20, x21, [sp, #160]
   84c34:	a90b5ff6 	stp	x22, x23, [sp, #176]
   84c38:	a90c67f8 	stp	x24, x25, [sp, #192]
   84c3c:	a90d6ffa 	stp	x26, x27, [sp, #208]
   84c40:	a90e77fc 	stp	x28, x29, [sp, #224]
   84c44:	f9007bfe 	str	x30, [sp, #240]
   84c48:	d2800180 	mov	x0, #0xc                   	// #12
   84c4c:	d5385201 	mrs	x1, esr_el1
   84c50:	d5384022 	mrs	x2, elr_el1
   84c54:	d5386003 	mrs	x3, far_el1
   84c58:	97ffef3a 	bl	80940 <show_invalid_entry_message>
   84c5c:	d50342df 	msr	daifset, #0x2
   84c60:	1400006d 	b	84e14 <err_hang>

0000000000084c64 <irq_invalid_el0_32>:

irq_invalid_el0_32:
	handle_invalid_entry  IRQ_INVALID_EL0_32
   84c64:	d10483ff 	sub	sp, sp, #0x120
   84c68:	a90007e0 	stp	x0, x1, [sp]
   84c6c:	a9010fe2 	stp	x2, x3, [sp, #16]
   84c70:	a90217e4 	stp	x4, x5, [sp, #32]
   84c74:	a9031fe6 	stp	x6, x7, [sp, #48]
   84c78:	a90427e8 	stp	x8, x9, [sp, #64]
   84c7c:	a9052fea 	stp	x10, x11, [sp, #80]
   84c80:	a90637ec 	stp	x12, x13, [sp, #96]
   84c84:	a9073fee 	stp	x14, x15, [sp, #112]
   84c88:	a90847f0 	stp	x16, x17, [sp, #128]
   84c8c:	a9094ff2 	stp	x18, x19, [sp, #144]
   84c90:	a90a57f4 	stp	x20, x21, [sp, #160]
   84c94:	a90b5ff6 	stp	x22, x23, [sp, #176]
   84c98:	a90c67f8 	stp	x24, x25, [sp, #192]
   84c9c:	a90d6ffa 	stp	x26, x27, [sp, #208]
   84ca0:	a90e77fc 	stp	x28, x29, [sp, #224]
   84ca4:	f9007bfe 	str	x30, [sp, #240]
   84ca8:	d28001a0 	mov	x0, #0xd                   	// #13
   84cac:	d5385201 	mrs	x1, esr_el1
   84cb0:	d5384022 	mrs	x2, elr_el1
   84cb4:	d5386003 	mrs	x3, far_el1
   84cb8:	97ffef22 	bl	80940 <show_invalid_entry_message>
   84cbc:	d50342df 	msr	daifset, #0x2
   84cc0:	14000055 	b	84e14 <err_hang>

0000000000084cc4 <fiq_invalid_el0_32>:

fiq_invalid_el0_32:
	handle_invalid_entry  FIQ_INVALID_EL0_32
   84cc4:	d10483ff 	sub	sp, sp, #0x120
   84cc8:	a90007e0 	stp	x0, x1, [sp]
   84ccc:	a9010fe2 	stp	x2, x3, [sp, #16]
   84cd0:	a90217e4 	stp	x4, x5, [sp, #32]
   84cd4:	a9031fe6 	stp	x6, x7, [sp, #48]
   84cd8:	a90427e8 	stp	x8, x9, [sp, #64]
   84cdc:	a9052fea 	stp	x10, x11, [sp, #80]
   84ce0:	a90637ec 	stp	x12, x13, [sp, #96]
   84ce4:	a9073fee 	stp	x14, x15, [sp, #112]
   84ce8:	a90847f0 	stp	x16, x17, [sp, #128]
   84cec:	a9094ff2 	stp	x18, x19, [sp, #144]
   84cf0:	a90a57f4 	stp	x20, x21, [sp, #160]
   84cf4:	a90b5ff6 	stp	x22, x23, [sp, #176]
   84cf8:	a90c67f8 	stp	x24, x25, [sp, #192]
   84cfc:	a90d6ffa 	stp	x26, x27, [sp, #208]
   84d00:	a90e77fc 	stp	x28, x29, [sp, #224]
   84d04:	f9007bfe 	str	x30, [sp, #240]
   84d08:	d28001c0 	mov	x0, #0xe                   	// #14
   84d0c:	d5385201 	mrs	x1, esr_el1
   84d10:	d5384022 	mrs	x2, elr_el1
   84d14:	d5386003 	mrs	x3, far_el1
   84d18:	97ffef0a 	bl	80940 <show_invalid_entry_message>
   84d1c:	d50342df 	msr	daifset, #0x2
   84d20:	1400003d 	b	84e14 <err_hang>

0000000000084d24 <error_invalid_el0_32>:

error_invalid_el0_32:
	handle_invalid_entry  ERROR_INVALID_EL0_32
   84d24:	d10483ff 	sub	sp, sp, #0x120
   84d28:	a90007e0 	stp	x0, x1, [sp]
   84d2c:	a9010fe2 	stp	x2, x3, [sp, #16]
   84d30:	a90217e4 	stp	x4, x5, [sp, #32]
   84d34:	a9031fe6 	stp	x6, x7, [sp, #48]
   84d38:	a90427e8 	stp	x8, x9, [sp, #64]
   84d3c:	a9052fea 	stp	x10, x11, [sp, #80]
   84d40:	a90637ec 	stp	x12, x13, [sp, #96]
   84d44:	a9073fee 	stp	x14, x15, [sp, #112]
   84d48:	a90847f0 	stp	x16, x17, [sp, #128]
   84d4c:	a9094ff2 	stp	x18, x19, [sp, #144]
   84d50:	a90a57f4 	stp	x20, x21, [sp, #160]
   84d54:	a90b5ff6 	stp	x22, x23, [sp, #176]
   84d58:	a90c67f8 	stp	x24, x25, [sp, #192]
   84d5c:	a90d6ffa 	stp	x26, x27, [sp, #208]
   84d60:	a90e77fc 	stp	x28, x29, [sp, #224]
   84d64:	f9007bfe 	str	x30, [sp, #240]
   84d68:	d28001e0 	mov	x0, #0xf                   	// #15
   84d6c:	d5385201 	mrs	x1, esr_el1
   84d70:	d5384022 	mrs	x2, elr_el1
   84d74:	d5386003 	mrs	x3, far_el1
   84d78:	97ffeef2 	bl	80940 <show_invalid_entry_message>
   84d7c:	d50342df 	msr	daifset, #0x2
   84d80:	14000025 	b	84e14 <err_hang>

0000000000084d84 <el1_irq>:

/* ---- end of EL1 vectors ----- */


el1_irq:
	kernel_entry 
   84d84:	d10483ff 	sub	sp, sp, #0x120
   84d88:	a90007e0 	stp	x0, x1, [sp]
   84d8c:	a9010fe2 	stp	x2, x3, [sp, #16]
   84d90:	a90217e4 	stp	x4, x5, [sp, #32]
   84d94:	a9031fe6 	stp	x6, x7, [sp, #48]
   84d98:	a90427e8 	stp	x8, x9, [sp, #64]
   84d9c:	a9052fea 	stp	x10, x11, [sp, #80]
   84da0:	a90637ec 	stp	x12, x13, [sp, #96]
   84da4:	a9073fee 	stp	x14, x15, [sp, #112]
   84da8:	a90847f0 	stp	x16, x17, [sp, #128]
   84dac:	a9094ff2 	stp	x18, x19, [sp, #144]
   84db0:	a90a57f4 	stp	x20, x21, [sp, #160]
   84db4:	a90b5ff6 	stp	x22, x23, [sp, #176]
   84db8:	a90c67f8 	stp	x24, x25, [sp, #192]
   84dbc:	a90d6ffa 	stp	x26, x27, [sp, #208]
   84dc0:	a90e77fc 	stp	x28, x29, [sp, #224]
   84dc4:	f9007bfe 	str	x30, [sp, #240]
	bl	handle_irq
   84dc8:	97ffee9a 	bl	80830 <handle_irq>
	kernel_exit 
   84dcc:	a94007e0 	ldp	x0, x1, [sp]
   84dd0:	a9410fe2 	ldp	x2, x3, [sp, #16]
   84dd4:	a94217e4 	ldp	x4, x5, [sp, #32]
   84dd8:	a9431fe6 	ldp	x6, x7, [sp, #48]
   84ddc:	a94427e8 	ldp	x8, x9, [sp, #64]
   84de0:	a9452fea 	ldp	x10, x11, [sp, #80]
   84de4:	a94637ec 	ldp	x12, x13, [sp, #96]
   84de8:	a9473fee 	ldp	x14, x15, [sp, #112]
   84dec:	a94847f0 	ldp	x16, x17, [sp, #128]
   84df0:	a9494ff2 	ldp	x18, x19, [sp, #144]
   84df4:	a94a57f4 	ldp	x20, x21, [sp, #160]
   84df8:	a94b5ff6 	ldp	x22, x23, [sp, #176]
   84dfc:	a94c67f8 	ldp	x24, x25, [sp, #192]
   84e00:	a94d6ffa 	ldp	x26, x27, [sp, #208]
   84e04:	a94e77fc 	ldp	x28, x29, [sp, #224]
   84e08:	f9407bfe 	ldr	x30, [sp, #240]
   84e0c:	910483ff 	add	sp, sp, #0x120
   84e10:	d69f03e0 	eret

0000000000084e14 <err_hang>:

.globl err_hang
err_hang: b err_hang
   84e14:	14000000 	b	84e14 <err_hang>

0000000000084e18 <enable_irq>:

// ----------------- irq related --------------------------- //
// daifclr/set 
.globl enable_irq
enable_irq:
	msr    daifclr, #0b0010 
   84e18:	d50342ff 	msr	daifclr, #0x2
	ret
   84e1c:	d65f03c0 	ret

0000000000084e20 <disable_irq>:

.globl disable_irq
disable_irq:
	msr	    daifset, #0b0010 
   84e20:	d50342df 	msr	daifset, #0x2
	ret 
   84e24:	d65f03c0 	ret

0000000000084e28 <is_irq_masked>:

.global is_irq_masked
is_irq_masked:
	// whereas daifset/clr are lowest four bits, daif bits are bit9--6
	// https://developer.arm.com/documentation/ddi0601/2023-12/AArch64-Registers/DAIF--Interrupt-Mask-Bits
	mrs x0, daif 
   84e28:	d53b4220 	mrs	x0, daif
	lsr x0, x0, #7 
   84e2c:	d347fc00 	lsr	x0, x0, #7
	and x0, x0, #1
   84e30:	92400000 	and	x0, x0, #0x1
	ret
   84e34:	d65f03c0 	ret

0000000000084e38 <cpuid>:

.global cpuid
cpuid: 
	mrs	x0, mpidr_el1
   84e38:	d53800a0 	mrs	x0, mpidr_el1
	and	x0, x0, #0xFF
   84e3c:	92401c00 	and	x0, x0, #0xff
	ret
   84e40:	d65f03c0 	ret

0000000000084e44 <memcpy_aligned>:
/* Below: the XXX_aligned funcs are faster than normal (unaligned) variants, but
    MUST BE used with care to avoid nasty bugs. unaligned addr will corrupt/miss
    contents. unless the buf is large, the extra speed is not worth it */
.globl memcpy_aligned
memcpy_aligned:
 	ldr x3, [x1], #8
   84e44:	f8408423 	ldr	x3, [x1], #8
 	str x3, [x0], #8
   84e48:	f8008403 	str	x3, [x0], #8
	subs x2, x2, #8
   84e4c:	f1002042 	subs	x2, x2, #0x8
 	b.gt memcpy_aligned
   84e50:	54ffffac 	b.gt	84e44 <memcpy_aligned>
 	ret
   84e54:	d65f03c0 	ret

0000000000084e58 <memzero_aligned>:

.globl memzero_aligned
memzero_aligned:
	str xzr, [x0], #8
   84e58:	f800841f 	str	xzr, [x0], #8
	subs x1, x1, #8
   84e5c:	f1002021 	subs	x1, x1, #0x8
	b.gt memzero_aligned
   84e60:	54ffffcc 	b.gt	84e58 <memzero_aligned>
	ret
   84e64:	d65f03c0 	ret

0000000000084e68 <get_el>:

.globl get_el
get_el:
	mrs x0, CurrentEL
   84e68:	d5384240 	mrs	x0, currentel
	lsr x0, x0, #2
   84e6c:	d342fc00 	lsr	x0, x0, #2
	ret
   84e70:	d65f03c0 	ret
