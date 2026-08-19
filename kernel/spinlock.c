/* Mutual exclusion with spin locks, derived from xv6 

  On a single core CPU, the spinlock really boils down to interrupt off/on. 
  Atop that, the push_off/pop_off code is crucial. 

  cpu cache and memory attributes must be configured (cacheable, shareable)
  otherwise exclusive load/str instructions (e.g. ldxr) will throw memory 
  exception. cf: https://forums.raspberrypi.com/viewtopic.php?t=207173  
*/

#include "utils.h"
#include "sched.h"
#include "spinlock.h"

// #define SPINLOCK_DEBUG 1

void initlock(struct spinlock *lk, char *name) {
    lk->name = name;
    lk->locked = 0;
    lk->cpu = 0;
}

/* Acquire the lock.
  Loops (spins) until the lock is acquired. */
void acquire(struct spinlock *lk) {
#if SPINLOCK_DEBUG
    volatile long cnt = 0;
#endif
    push_off(); // disable interrupts to avoid deadlock.
    if (!lk || holding(lk)) {
        printf("%s ", lk->name);
        panic("acquire");
    }

    /* just to appease holding(). should use CAS, but that triggers exception b/c
    cpu cache is still off for lab1 */
    while (lk->locked == 1)
        ;
    lk->locked = 1;

    /* Tell the C compiler and the processor to not move loads or stores
    past this point, to ensure that the critical section's memory
    references happen strictly after the lock is acquired.
    On RISC-V, this emits a fence instruction. */
    __sync_synchronize();

    /* Record info about lock acquisition for holding() and debugging. */
    lk->cpu = mycpu();
}

/* Release the lock. */
void release(struct spinlock *lk) {
    if (!lk || !holding(lk)) {
        printf("%s ", lk->name);
        panic("release");
    }

    lk->cpu = 0;

    /* Tell the C compiler and the CPU to not move loads or stores
    past this point, to ensure that all the stores in the critical
    section are visible to other CPUs before the lock is released,
    and that loads in the critical section occur strictly before
    the lock is released.
    On RISC-V, this emits a fence instruction. */
    __sync_synchronize();

    /* just to appease holding(). should use CAS, but that triggers exception b/c
    cpu cache is still off for lab1   */
    lk->locked = 0;

    pop_off();
}

/* Check whether this cpu is holding the lock.
  Interrupts must be off. */
int holding(struct spinlock *lk) {
    int r;
    r = (lk->locked && lk->cpu == mycpu());
    return r;
}

/* push_off/pop_off are like intr_off()/intr_on() except that they are matched:
  it takes two pop_off()s to undo two push_off()s.  Also, if interrupts
  are initially off, then push_off, pop_off leaves them off.

  "intena" is the irq status (on/off) when noff (i.e. the "balance") is 0. 
  hence, the irq status must be restored when noff reaches 0 again */
void push_off(void) {
    int old = intr_get();

    // intr_off();
    disable_irq();
    if (mycpu()->noff == 0)
        mycpu()->intena = old;
    mycpu()->noff += 1;
}

/* pop_off must be done with a positive counter (noff)
  i.e. it's a bug if irq is already enabled and then pop_off */
void pop_off(void) {
    struct cpu *c = mycpu();
    if (intr_get())
        panic("pop_off - interruptible");
    if (c->noff < 1)
        panic("pop_off");
    c->noff -= 1;
    if (c->noff == 0 && c->intena)
        enable_irq();
}
