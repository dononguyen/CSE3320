/* 
    Kernel configuration 
    included by: both the kernel (c and asm) and mkfs
*/

#define NCPU	        1   // # of cpu cores

#ifndef __ASSEMBLER__
// keep xv6 code happy. TODO: separate them out...
typedef unsigned int   uint;
typedef unsigned short ushort;
typedef unsigned char  uchar;

typedef unsigned char uint8;
typedef unsigned short uint16;
typedef unsigned int  uint32;
typedef unsigned long uint64;
#endif