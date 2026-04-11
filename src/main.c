#include "semihosting.h"
#include <stdint.h>

/* These global variables are used to test if our startup code works.
   initialized = 123 ends up in .data, so if the Flash-to-RAM copy
   worked it should still be 123 when we check it in main().
   uninitialized has no value so it goes in .bss - if the zero-fill
   worked it should be 0. systick_count is marked volatile because
   it gets changed inside the interrupt handler and we need the
   compiler to actually re-read it every time */

int initialized = 123;
int uninitialized;

volatile uint32_t systick_count = 0;

/* This function gets called automatically by the CPU every time
   the SysTick timer counts down to zero. All we do here is bump
   the counter by one so we can tell from main() that interrupts
   are actually firing */

void SysTick_Handler(void)
{
    systick_count++;
}

/* This is where we end up after the startup code finishes setting
   up RAM. We first check that our test variables have the right
   values to make sure .data and .bss init worked, then we set up
   the SysTick timer to generate periodic interrupts, and finally
   we just loop forever while the interrupts do their thing */

int main(void)
{
    /* Print a message so we can see that we actually made it to main().
   Since there's no real serial port on this QEMU machine we use
   semihosting which lets QEMU print stuff to our terminal */
    sh_puts("Boot OK\r\n");

    /* Check if the startup code did its job properly. If initialized
   is still 123 that means .data was copied from Flash to RAM ok.
   If uninitialized is 0 that means .bss got zeroed correctly */
    if (initialized == 123 && uninitialized == 0) {
        sh_puts("Data/BSS verified\r\n");
    }

    /* SysTick is controlled through three registers at fixed addresses.
   We make pointers to them so we can read and write the hardware.
   RVR is what the counter reloads to after hitting zero,
   CVR is the current count, and CSR controls whether its
   enabled and whether it fires interrupts */
    volatile uint32_t *syst_rvr = (volatile uint32_t *)0xE000E014;
    volatile uint32_t *syst_cvr = (volatile uint32_t *)0xE000E018;
    volatile uint32_t *syst_csr = (volatile uint32_t *)0xE000E010;

    /* Set up SysTick to interrupt every 8000 clock cycles.
   We clear the current counter so it starts fresh, then
   write 0x07 to the control register which turns on the
   counter, enables interrupts, and uses the processor clock */
    *syst_rvr = 8000;
    *syst_cvr = 0;
    *syst_csr = 0x00000007;

    sh_puts("SysTick enabled\r\n");

    
   /* Sit in a loop forever and every 5000 SysTick interrupts
   print a message to show that the timer is still running.
   We track the last time we printed so we don't spam output */ 
    uint32_t last_print = 0;
    while (1) {
    if (systick_count - last_print >= 5000) {
        sh_puts("SysTick running\r\n");
        last_print = systick_count;
    }
}

    return 0;
}
