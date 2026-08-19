/* common util functions written in assembly */

// ----------------- irq related --------------------------- //
// daifclr/set 
.globl enable_irq
enable_irq:
	msr    daifclr, #0b0010 
	ret

.globl disable_irq
disable_irq:
	msr	    daifset, #0b0010 
	ret 

.global is_irq_masked
is_irq_masked:
	// whereas daifset/clr are lowest four bits, daif bits are bit9--6
	// https://developer.arm.com/documentation/ddi0601/2023-12/AArch64-Registers/DAIF--Interrupt-Mask-Bits
	mrs x0, daif 
	lsr x0, x0, #7 
	and x0, x0, #1
	ret

.global cpuid
cpuid: 
	mrs	x0, mpidr_el1
	and	x0, x0, #0xFF
	ret

// ---------------------- misc -------------------------------------------- //
/* Below: the XXX_aligned funcs are faster than normal (unaligned) variants, but
    MUST BE used with care to avoid nasty bugs. unaligned addr will corrupt/miss
    contents. unless the buf is large, the extra speed is not worth it */
.globl memcpy_aligned
memcpy_aligned:
 	ldr x3, [x1], #8
 	str x3, [x0], #8
	subs x2, x2, #8
 	b.gt memcpy_aligned
 	ret

.globl memzero_aligned
memzero_aligned:
	str xzr, [x0], #8
	subs x1, x1, #8
	b.gt memzero_aligned
	ret

.globl get_el
get_el:
	mrs x0, CurrentEL
	lsr x0, x0, #2
	ret

/* 
.globl put32
put32:
	str w1,[x0]
	ret

.globl get32
get32:
	ldr w0,[x0]
	ret
 */
 
//.globl delay
//delay:
//	subs x0, x0, #1
//	bne delay
//	ret
