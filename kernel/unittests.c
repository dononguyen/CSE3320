/*
    kernel unit tests
*/

#include "plat.h"
#include "utils.h"
#include "debug.h"

static int handler(TKernelTimerHandle hTimer, void *param, void *context) {
	unsigned sec, msec; 
	current_time(&sec, &msec);
	I("%u.%03u: fired. on cpu %d. htimer %ld, param %lx, contex %lx", sec, msec,
		cpuid(), hTimer, (unsigned long)param, (unsigned long)context); 
    return 0; // don't restart the timer
}

// to be called in a kernel process
void test_ktimer() {
	unsigned sec, msec; 

	current_time(&sec, &msec); 
	I("%u.%03u start delaying 500ms...", sec, msec); 
	ms_delay(500); 
	current_time(&sec, &msec);
	I("%u.%03u ended delaying 500ms", sec, msec); 

	// start, fire 
	int t = ktimer_start(500, handler, (void *)0xdeadbeef, (void*)0xdeaddeed);
	I("timer start. timer id %u", t); 
	ms_delay(1000);
	I("timer %d should have fired", t); 

	// start two, fire
	t = ktimer_start(500, handler, (void *)0xdeadbeef, (void*)0xdeaddeed);
	I("timer start. timer id %u", t); 
	t = ktimer_start(1000, handler, (void *)0xdeadbeef, (void*)0xdeaddeed);
	I("timer start. timer id %u", t); 
	ms_delay(2000); 
	I("both timers should have fired"); 

	// start, cancel 
	t = ktimer_start(500, handler, (void *)0xdeadbeef, (void*)0xdeaddeed);
	I("timer start. timer id %u", t);
	ms_delay(100); 
	int c = ktimer_cancel(t); 
	I("timer cancel return val = %d", c);
	BUG_ON(c < 0);

	I("there shouldn't be more callback"); 
}

///////////////////
/* 
    test multiple ktimers periodically firing
    pressing key 1,2,3,4...9 to toggle on/off ktimer instances, 
    each printing a msg in different periods, in different colors 
    press 0 to kill all timers
    each ktimer has different firing period
*/    

static int test_ktimer2_handler(TKernelTimerHandle hTimer, void *param, 
    void *context) {
	unsigned sec, msec; 
	current_time(&sec, &msec);
	printf("%s %u.%03u: fired. on cpu %d. htimer %ld\n" _k2clr_none, 
        (char *)param, sec, msec, cpuid(), hTimer); 
    return 1; // restart the timer 
}

#define N_TIMERS_TEST 9
static int timers[N_TIMERS_TEST]= \
    {-1,-1,-1,-1,-1,-1,-1,-1,-1};

// color-coded msgs from diff timers. cf debug.h 
static const char *colors[]= \
    { _k2clr_gray, _k2clr_gray_bold, _k2clr_gray_underline, 
     _k2clr_red, _k2clr_red_bold, _k2clr_red_underline, 
     _k2clr_brown, _k2clr_brown_bold, _k2clr_brown_underline};
    
/* 
    c: char received from uart, support 1..9; 0 to kill all timers
    to be called in uart rx irq handler 
*/
void test_ktimer2(int c) {
    if (c<'0' || c>'9') return; 
    int ret; 
    if (c=='0') {
        for (int i=0;i<N_TIMERS_TEST;i++) {
            if (timers[i]!=-1) {
                ret = ktimer_cancel(timers[i]); 
                BUG_ON(ret == -1); // no such timer
                timers[i]=-1;
                W("ktimer_cancel idx %d", i+1); 
            }
        }
    } else {
        int idx = c-'1'; 
        if (timers[idx]!=-1) { // cancel the timer
            W("ktimer_cancel %d", idx+1); 
            ret = ktimer_cancel(timers[idx]); 
            // BUG_ON(ret == -1); // no such timer (maybe benign? like just fired?
            timers[idx]=-1;
        } else { // start a new timer
            W("ktimer_start %d", idx+1); 
            ret = ktimer_start(200*(idx+1), /*firing interval, ms*/
                test_ktimer2_handler, (void*)colors[idx] /*args*/, 0 /* context */); 
            BUG_ON(ret<0); 
            timers[idx]=ret; 
        }
    }
}

///////////////////
extern void fb_showpicture(void); 
#include "fb.h"

#define PIXELSIZE 4 /*ARGB, expected by /dev/fb*/ 
typedef unsigned int PIXEL; 
#define N 256       // project idea: four color quads has glitches. fix it 

static inline void setpixel(unsigned char *buf, int x, int y, int pit, PIXEL p) {
    assert(x>=0 && y>=0); 
    *(PIXEL *)(buf + y*pit + x*PIXELSIZE) = p; 
}

/* 
    This function demonstrates how to flip the framebuffer (fb), i.e., change
    display contents by changing only the "viewport" into the underlying pixel
    buffers.     

    It creates a virtual framebuffer with four quadrants, each with a different
    color: R/G/B/black. The physical (viewport) size is one quadrant. The
    function then cycles the viewport through the four quadrants.

    Dependency: delay Project idea: Use a virtual timer instead for better
    efficiency.

    This works correctly on RPi3 hardware. Known bug on QEMU: Some color
    quadrants won't display correctly, likely due to a QEMU bug.
*/ 
void test_fb_voffset() {
    // fb_showpicture();        // works

    // acquire(&mboxlock);      //it's a test. so no lock

    fb_fini(); 

    the_fb.width = N;
    the_fb.height = N;

    the_fb.vwidth = N*2; 
    the_fb.vheight = N*2; 

    if (fb_init() != 0) BUG();     

    // prefill the fb with four color tiles, once 
    PIXEL b=0x00ff0000, g=0x0000ff00, r=0x000000ff; 
    int x, y;
    int pitch = the_fb.pitch; 
    for (y=0;y<N;y++)
        for (x=0;x<N;x++)
            setpixel(the_fb.fb,x,y,pitch,r); 

    for (y=0;y<N;y++)
        for (x=N;x<2*N;x++)
            setpixel(the_fb.fb,x,y,pitch,(b|r));             

    for (y=N;y<2*N;y++)
        for (x=0;x<N;x++)
            setpixel(the_fb.fb,x,y,pitch,g); 

    for (y=N;y<2*N;y++)
        for (x=N;x<2*N;x++)
            setpixel(the_fb.fb,x,y,pitch,b);             

    // // test --- fill all quads the same color
    // for (y=0;y<2*N;y++)
    //     for (x=0;x<2*N;x++)
    //         setpixel(the_fb.fb,x,y,pitch,b);             

    //what if we dont flush cache?
    // __asm_flush_dcache_range(the_fb.fb, the_fb.fb + the_fb.size); 

    while (1) {
        fb_set_voffsets(0,0);
        ms_delay(1500); 
        fb_set_voffsets(0,N);
        ms_delay(1500); 
        fb_set_voffsets(N,0);
        ms_delay(1500); 
        fb_set_voffsets(N,N);
        ms_delay(1500); 
    }
}