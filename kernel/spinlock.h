#ifndef SPINLOCK_H
#define SPINLOCK_H
struct spinlock {
    unsigned int locked; // Is the lock held?
    /* Below for debugging */
    char *name;      // Name of lock.
    struct cpu *cpu; // The cpu holding the lock.
};
#endif

/* derived from xv6 */