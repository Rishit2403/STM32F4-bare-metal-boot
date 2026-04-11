/* This is the linker script for our STM32F4 project.
   It tells the linker where Flash and RAM are on the chip
   so it knows where to put code and variables.
   Flash starts at 0x08000000 and we have 512 KB of it.
   RAM starts at 0x20000000 and we have 128 KB of it. */

MEMORY
{
    FLASH (rx)  : ORIGIN = 0x08000000, LENGTH = 512K
    RAM (rwx)   : ORIGIN = 0x20000000, LENGTH = 128K
}

SECTIONS
{
    /* This is where the vector table goes - right at the beginning of Flash.
   We use KEEP() because the linker might throw it away thinking
   nothing references it, but the CPU actually needs it at boot */
    .isr_vector :
    {
        KEEP(*(.isr_vector))
    } > FLASH

    .text :
   {
      *(.text*)
   } > FLASH

   /* This section holds things like string literals ("Boot OK", etc.)
   and any const variables. It goes in Flash right after the code
   since we never need to modify this stuff at runtime */
   .rodata :
   {
      *(.rodata*)
   } > FLASH

    /* This gives us the Flash address where the initial values of
   our .data variables are stored. The startup code needs this
   to know where to copy from when setting up RAM */
    _sidata = LOADADDR(.data);

    /* Variables that have an initial value (like int x = 123) go here.
   The tricky part is they live in two places - the initial values
   are stored in Flash, but at runtime the variables need to be in
   RAM so we can actually write to them. The startup code handles
   copying the values from Flash into RAM before main() runs */
    .data :
    {
        _sdata = .;
        *(.data*)
        _edata = .;
    } > RAM AT > FLASH

    /* This is for global variables that don't have an initial value
   (like int x; with no = something). The C standard says these
   have to be zero when the program starts, so the startup code
   fills this whole region with zeros before calling main() */
    .bss :
    {
        _sbss = .;
        *(.bss*)
        *(COMMON)
        _ebss = .;
    } > RAM

    /* Stack pointer starts at the very top of RAM because on ARM
   the stack grows downward. The CPU automatically picks this
   value up from the first word of the vector table at reset */
    _estack = ORIGIN(RAM) + LENGTH(RAM);
}
