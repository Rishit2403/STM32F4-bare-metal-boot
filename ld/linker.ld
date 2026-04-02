/* Linker script for STM32F4 bare-metal firmware
   Defines memory layout and section placement
   Flash: 0x08000000 (512 KB) - read-only, code and constants
   SRAM: 0x20000000 (128 KB) - read-write, data and stack */

MEMORY
{
    FLASH (rx)  : ORIGIN = 0x08000000, LENGTH = 512K
    RAM (rwx)   : ORIGIN = 0x20000000, LENGTH = 128K
}

SECTIONS
{
    /* Interrupt vector table section
       Placed at start of Flash (0x08000000)
       KEEP() prevents linker from discarding it as unused */
    .isr_vector :
    {
        KEEP(*(.isr_vector))
    } > FLASH

    /* Code and read-only data sections
       Placed in Flash immediately after vector table
       Contains executable instructions and constant strings */
    .text :
    {
        *(.text*)
        *(.rodata*)
    } > FLASH

    /* Symbol for .data load address (in Flash)
       Used by Reset_Handler to copy initialized data */
    _sidata = LOADADDR(.data);

    /* Initialized data section
       Load address: Flash (AT > FLASH)
       Run address: SRAM (> RAM)
       Reset_Handler copies this section from Flash to SRAM */
    .data :
    {
        _sdata = .;
        *(.data*)
        _edata = .;
    } > RAM AT > FLASH

    /* Uninitialized data section (Block Started by Symbol)
       Placed in SRAM after .data
       Reset_Handler zero-initializes this section */
    .bss :
    {
        _sbss = .;
        *(.bss*)
        *(COMMON)
        _ebss = .;
    } > RAM

    /* End of stack pointer: top of SRAM
       Stack grows downward; initial SP loaded from vector[0] */
    _estack = ORIGIN(RAM) + LENGTH(RAM);
}
