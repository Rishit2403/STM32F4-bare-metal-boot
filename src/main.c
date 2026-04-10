#include "semihosting.h"
#include <stdint.h>

/* Global variables for .data and .bss verification
   initialized: placed in .data, initialized to 123 at compile time
   uninitialized: placed in .bss, zero-initialized at runtime by Reset_Handler
   systick_count: volatile counter incremented by SysTick_Handler */

int initialized = 123;
int uninitialized;

volatile uint32_t systick_count = 0;

/* SysTick interrupt handler: fires every SYST_RVR clock cycles
   Increments counter for timing measurements
   Handler priority: lowest (executes only when main context blocked) */

void SysTick_Handler(void)
{
    systick_count++;
}

/* Main entry point after Reset_Handler initialization
   1. Verify .data/.bss initialization via semihosting output
   2. Configure and enable SysTick timer
   3. Loop indefinitely; SysTick fires asynchronously */

int main(void)
{
    /* Output boot message via semihosting
       Semihosting allows QEMU to forward output to host stdout */
    sh_puts("Boot OK\r\n");

    /* Verify correct initialization:
       initialized must equal 123 (from .data section)
       uninitialized must equal 0 (from .bss zero-fill) */
    if (initialized == 123 && uninitialized == 0) {
        sh_puts("Data/BSS verified\r\n");
    }

    /* Get pointers to SysTick memory-mapped registers
       SYST_RVR (0xE000E014): reload value for counter
       SYST_CVR (0xE000E018): current counter value
       SYST_CSR (0xE000E010): control and status register */
    volatile uint32_t *syst_rvr = (volatile uint32_t *)0xE000E014;
    volatile uint32_t *syst_cvr = (volatile uint32_t *)0xE000E018;
    volatile uint32_t *syst_csr = (volatile uint32_t *)0xE000E010;

    /* Configure SysTick timer:
       Reload value: 8000 cycles between interrupts
       Current value: 0 (reset counter)
       Control bits: 0x00000007 = CLKSOURCE(1)|TICKINT(1)|ENABLE(1) */
    *syst_rvr = 8000;
    *syst_cvr = 0;
    *syst_csr = 0x00000007;

    sh_puts("SysTick enabled\r\n");

    
   /* Main loop: SysTick_Handler increments counter asynchronously
   Output message every 5000 interrupts for verification */ 
    uint32_t last_print = 0;
    while (1) {
    if (systick_count - last_print >= 5000) {
        sh_puts("SysTick running\r\n");
        last_print = systick_count;
    }
}

    return 0;
}
