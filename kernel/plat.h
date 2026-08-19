#if defined PLAT_RPI3QEMU || defined PLAT_RPI3
#include "plat-rpi3qemu.h"
#else
#error "unimpl"
#endif

// -------------------------- page size constants  ------------------------------ //
#define PAGE_MASK			    0xfffffffffffff000
#define PAGE_SHIFT	 	        12
#define TABLE_SHIFT 		    9
#define SECTION_SHIFT		(PAGE_SHIFT + TABLE_SHIFT)
#define SUPERSECTION_SHIFT      (PAGE_SHIFT + 2*TABLE_SHIFT)      //30, 2^30 = 1GB

#define PAGE_SIZE   		(1 << PAGE_SHIFT)	
#define SECTION_SIZE		(1 << SECTION_SHIFT)	
#define SUPERSECTION_SIZE       (1 << SUPERSECTION_SHIFT)
