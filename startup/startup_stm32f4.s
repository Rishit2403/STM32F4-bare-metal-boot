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

/* Interrupt vector table placed at start of Flash memory (0x08000000)
   Entry 0: Initial stack pointer value (MSP)
   Entry 1: Reset handler entry point with Thumb bit set
   Entries 2-16: Exception handlers (NMI, HardFault, SVC, SysTick, etc.)
   CPU loads SP from [0x00] and PC from [0x04] on power-up */

g_pfnVectors:
    .word _estack
    .word Reset_Handler + 1
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

/* Reset handler: entry point after CPU reset
   Performs runtime initialization before main() execution
   1. Copy initialized data from Flash to SRAM (.data section)
   2. Zero-initialize uninitialized data in SRAM (.bss section)
   3. Jump to main() function */

Reset_Handler:
    /* Load addresses for .data copy operation
       r0: source address (_sidata) - Flash
       r1: destination address (_sdata) - SRAM
       r2: end address (_edata) - SRAM */
    ldr r0, =_sidata
    ldr r1, =_sdata
    ldr r2, =_edata

    /* Skip .data copy if section is empty */
    cmp r1, r2
    beq bss_init

/* Copy .data from Flash (load address) to SRAM (run address)
   Loop: read 4 bytes from Flash, write to SRAM, increment pointers */
data_copy:
    ldr r3, [r0], #4
    str r3, [r1], #4
    cmp r1, r2
    blt data_copy

/* Initialize .bss section: zero all uninitialized variables
   r1: start address (_sbss)
   r2: end address (_ebss)
   r3: zero value */
bss_init:
    ldr r1, =_sbss
    ldr r2, =_ebss
    movs r3, #0

    cmp r1, r2
    beq main_call

/* Zero-fill loop: write 4 bytes of zeros to SRAM, increment pointer */
bss_zero:
    str r3, [r1], #4
    cmp r1, r2
    blt bss_zero

/* Call main() function after all initialization complete */
main_call:
    bl main
    b .

.section .text.default_handler,"ax",%progbits
.thumb_func

/* Default weak exception handlers: catch unimplemented exceptions
   Handlers return to caller (bx lr) to prevent system lockup
   User code can override these by defining strong symbols */

.weak NMI_Handler
.weak HardFault_Handler
.weak MemManage_Handler
.weak BusFault_Handler
.weak UsageFault_Handler
.weak SVC_Handler
.weak DebugMon_Handler
.weak PendSV_Handler
.weak SysTick_Handler

NMI_Handler:
HardFault_Handler:
MemManage_Handler:
BusFault_Handler:
UsageFault_Handler:
SVC_Handler:
DebugMon_Handler:
PendSV_Handler:
SysTick_Handler:
    bx lr
