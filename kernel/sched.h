#ifndef _SCHED_H
#define _SCHED_H

// --------------- cpu related ----------------------- // 
struct cpu {
  int noff;                   		// Depth of push_off() nesting.
  int intena;                 		// Were interrupts enabled before push_off()?
  // # of ticks
  int busy; 		// # of busy ticks in current measurement interval
  int last_util;	// out of 100, cpu util in the past interval
  unsigned long total; // since cpu boot 
};
extern struct cpu cpus[NCPU];		// sched.c

// irq must be disabled
extern int cpuid(void); 
static inline struct cpu* mycpu(void) {return &cpus[cpuid()];};

#endif

