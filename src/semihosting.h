#ifndef SEMIHOSTING_H
#define SEMIHOSTING_H

/* Semihosting lets our bare-metal code print text to the host PC.
   It works by executing a special breakpoint instruction (BKPT 0xAB)
   which makes QEMU pause, check what we put in R0 and R1, do the
   I/O for us, and then let the program continue running.
   For this to work QEMU needs to be started with the flag
   -semihosting-config enable=on,target=native */

/* Operation code 0x04 tells the semihosting system to print
   a null-terminated string. We pass this in R0 and the
   address of the string goes in R1 */
#define SEMIHOSTING_SYS_WRITE0 0x04

/* This does the actual semihosting call using inline assembly.
   It loads the operation code into R0 and the argument into R1,
   then hits BKPT 0xAB which QEMU catches and acts on */
static inline int semihosting_call(int reason, void *arg)
{
    int value;
    __asm__ volatile (
        "mov r0, %1\n"
        "mov r1, %2\n"
        "bkpt 0xAB\n"
        "mov %0, r0\n"
        : "=r"(value)
        : "r"(reason), "r"(arg)
        : "r0", "r1", "memory"
    );
    return value;
}

/* Wrapper to print a string - just calls semihosting with SYS_WRITE0 */
static inline void sh_puts(const char *s)
{
    semihosting_call(SEMIHOSTING_SYS_WRITE0, (void *)s);
}

#endif