#ifndef SEMIHOSTING_H
#define SEMIHOSTING_H

#define SEMIHOSTING_SYS_WRITE0 0x04

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

static inline void sh_puts(const char *s)
{
    semihosting_call(SEMIHOSTING_SYS_WRITE0, (void *)s);
}

#endif