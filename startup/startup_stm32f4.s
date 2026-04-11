.syntax unified
.cpu cortex-m4
.thumb

.extern _estack
.extern _sidata
.extern _sdata
.extern _edata
.extern _sbss
.extern _ebss
.extern main

.global g_pfnVectors
.global Reset_Handler

.section .isr_vector,"a",%progbits
.align 8

/* This is the vector table - it has to be at the very start of Flash.
   When the chip powers on it reads the first word as the stack pointer
   and the second word as the address to start running code from.
   After that come the exception handlers like NMI, HardFault, SysTick
   etc. that the CPU jumps to when something happens */

g_pfnVectors:
    .word _estack
    .word Reset_Handler 
    .word NMI_Handler
    .word HardFault_Handler
    .word MemManage_Handler
    .word BusFault_Handler
    .word UsageFault_Handler
    .word 0
    .word 0
    .word 0
    .word 0
    .word SVC_Handler
    .word DebugMon_Handler
    .word 0
    .word PendSV_Handler
    .word SysTick_Handler

.section .text.Reset_Handler,"ax",%progbits
.thumb_func

/* This is the first thing that runs after the CPU resets.
   Before we can call main() we need to set up the C environment:
   copy .data variables from Flash into RAM so they have their
   initial values, zero out .bss so uninitialized globals start
   at zero, and then finally jump to main() */

Reset_Handler:
    /* Set up registers for the .data copy loop.
   r0 points to where the initial values are in Flash,
   r1 points to where they need to go in RAM,
   r2 is the end of .data in RAM so we know when to stop */
    ldr r0, =_sidata
    ldr r1, =_sdata
    ldr r2, =_edata

    /* If .data has nothing in it just skip straight to .bss init */
    cmp r1, r2
    beq bss_init

/* Copy loop - grab a word from Flash, store it in RAM, move both
   pointers forward by 4 bytes, and keep going until we reach the end */
data_copy:
    ldr r3, [r0], #4
    str r3, [r1], #4
    cmp r1, r2
    blo data_copy

/* Now set up for zeroing .bss. r1 is the start of .bss in RAM,
   r2 is the end, and r3 is just zero which we write over and over */
bss_init:
    ldr r1, =_sbss
    ldr r2, =_ebss
    movs r3, #0

    cmp r1, r2
    beq main_call

/* Write zeros one word at a time until we've cleared all of .bss */
bss_zero:
    str r3, [r1], #4
    cmp r1, r2
    blo bss_zero

/* Everything is set up now, jump to main() */
main_call:
    bl main
    b .

.section .text.default_handler,"ax",%progbits
.thumb_func

/* If an exception fires that we haven't written a handler for,
   we just loop here forever. This makes it easy to spot in the
   debugger because the PC will be stuck at this address */
Default_Handler:
    b .

/* All the exception handlers are set as weak aliases pointing to
   Default_Handler. This means if we don't define our own version
   (like we do for SysTick_Handler in main.c) they just fall back
   to the default infinite loop. If we do define one, the linker
   picks our version instead */
.weak NMI_Handler
.thumb_set NMI_Handler, Default_Handler

.weak HardFault_Handler
.thumb_set HardFault_Handler, Default_Handler

.weak MemManage_Handler
.thumb_set MemManage_Handler, Default_Handler

.weak BusFault_Handler
.thumb_set BusFault_Handler, Default_Handler

.weak UsageFault_Handler
.thumb_set UsageFault_Handler, Default_Handler

.weak SVC_Handler
.thumb_set SVC_Handler, Default_Handler

.weak DebugMon_Handler
.thumb_set DebugMon_Handler, Default_Handler

.weak PendSV_Handler
.thumb_set PendSV_Handler, Default_Handler

.weak SysTick_Handler
.thumb_set SysTick_Handler, Default_Handler
