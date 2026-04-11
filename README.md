# STM32F4 Bare-Metal Boot — Assignment 1

Course: Embedded Systems
Target MCU: STM32F4 (Cortex-M4F)
Platform: QEMU (olimex-stm32-h405)

---

## Memory Map

Our chip has two main memory areas that matter for this project:

- Flash at `0x08000000`, 512 KB — this is where our program lives. It keeps its contents even when power is off, but we can't write to it at runtime. All our code, string constants, and the initial values for global variables are stored here.
-  SRAM  at `0x20000000`, 128 KB — this is working memory. Variables go here because we need to read and write them. The stack also lives here. It loses everything when you power off.

One thing to note is that the STM32 maps Flash to address `0x00000000` at boot, so when the CPU tries to read the vector table from address zero, it actually ends up reading from `0x08000000`.

### How Flash is laid out

Looking at the linker map, things are arranged in Flash like this:

- `0x08000000` — `.isr_vector` (64 bytes): our vector table with the initial SP, Reset_Handler address, and exception handler entries.
- `0x08000040` — `.text` (306 bytes): all the actual code — `main()`, `SysTick_Handler()`, `Reset_Handler`, and the default exception handlers.
- `0x08000174` — `.rodata` (70 bytes): read-only stuff like the string literals we pass to `sh_puts()`.
- `0x080001BA` — `.data` initial values (4 bytes): just the number 123 for our `initialized` variable, sitting in Flash waiting to be copied to RAM.

Total Flash used comes out to about 444 bytes.

### How SRAM is laid out

- `0x20000000` — `.data` (4 bytes): where `initialized` actually lives at runtime. Gets its value copied over from Flash by the startup code.
- `0x20000004` — `.bss` (8 bytes): holds `uninitialized` (4 bytes) and `systick_count` (4 bytes). The startup code fills all of this with zeros.
- `0x20020000` — this is `_estack`, the very top of RAM. Our stack starts here and grows downward.

Total SRAM used is just 12 bytes for variables, plus whatever the stack needs.

### Linker symbols the startup code uses

These are defined in the linker script and the startup assembly references them to know where things are:

- `_estack = 0x20020000` — top of RAM, used as initial stack pointer
- `_sidata = 0x080001BA` — where the .data initial values sit in Flash (this is the copy source)
- `_sdata = 0x20000000` — start of .data in RAM (copy destination)
- `_edata = 0x20000004` — end of .data in RAM
- `_sbss = 0x20000004` — start of .bss in RAM
- `_ebss = 0x2000000C` — end of .bss in RAM

---

## File Structure

```
STM32F4-bare-metal-boot/
├── src/
│   ├── main.c              # main application, SysTick setup, runtime verification
│   └── semihosting.h       # semihosting API for printing to host console
├── startup/
│   └── startup_stm32f4.s   # vector table, Reset_Handler, default handlers
├── ld/
│   └── linker.ld           # memory regions and section placement
├── Makefile
├── README.md
└── firmware.map             # generated linker map file
```

---

## Building

On Windows you need QEMU and the ARM GNU toolchain installed and added to PATH.
On Linux its just: `sudo apt install qemu-system-arm gcc-arm-none-eabi gdb-multiarch make`

Then to build:
```
make clean
make all
```

This compiles both source files into `.o` object files, links them together using our linker script, and then extracts the raw binary with `objcopy`. After building you'll have `firmware.elf`, `firmware.bin`, and `firmware.map`.

Size output from my build:
```
   text    data     bss     dec     hex filename
    440       4       8     452     1c4 firmware.elf
```

---

## QEMU Run and Debug Commands

### Running it

```
qemu-system-arm -M olimex-stm32-h405 -kernel firmware.bin -semihosting-config enable=on,target=native -nographic
```

Or just `make run`. To quit QEMU press Ctrl+A then X.

What you should see:
```
Boot OK
Data/BSS verified
SysTick enabled
SysTick running
SysTick running
...
```

### Debugging with GDB

You need two terminals for this.

Terminal 1 — start QEMU but keep the CPU paused:
```
qemu-system-arm -M olimex-stm32-h405 -kernel firmware.bin -semihosting-config enable=on,target=native -S -gdb tcp::3333 -nographic
```

Terminal 2 — connect with GDB (on Linux use `gdb-multiarch` instead):
```
arm-none-eabi-gdb firmware.elf
(gdb) target remote :3333
```

---

## Boot Sequence Explanation

Heres what happens step by step from the moment the CPU resets until our code is running:

1.  CPU comes out of reset  — everything is at default values. The CPU is going to read the first two words from address 0x00000000 which is really Flash at 0x08000000 because of the aliasing.

2.  Stack pointer gets set up  — the CPU reads the word at 0x08000000 and gets `0x20020000` which is the top of our 128 KB RAM. It loads this into SP. Now we have a working stack.

3.  Program counter gets loaded  — the CPU reads the next word at 0x08000004 which has the Reset_Handler address with the Thumb bit set (bit 0 = 1). It puts this in PC and starts executing from there.

4.  Startup code copies .data  — Reset_Handler takes the initial values stored in Flash at `0x080001BA` and copies them into RAM starting at `0x20000000`. After this our `initialized` variable actually has the value 123 in RAM where we can use it.

5.  Startup code zeros .bss  — Reset_Handler fills the .bss area (from `0x20000004` to `0x2000000C`) with zeros. This is why `uninitialized` and `systick_count` start at zero like the C standard requires.

6.  Jump to main()  — the startup code does `bl main` and we're finally in C land.

7.  Print boot message  — first thing main() does is call `sh_puts("Boot OK")`. This uses semihosting (BKPT 0xAB) so QEMU prints it to our terminal. If we see this, we know the whole boot path worked.

8.  Check that init worked  — main() verifies `initialized == 123` and `uninitialized == 0`. If both are correct it prints "Data/BSS verified". This tells us the .data copy and .bss zeroing both did their job.

9.  Set up SysTick  — main() writes to the SysTick registers at 0xE000E010-0xE000E018. We set the reload value to 8000, clear the counter, and enable everything by writing 0x07 to the control register (that turns on the counter, enables interrupts, and selects the processor clock).

10.  Interrupts start firing  — from here on, every 8000 clock cycles SysTick counts down to zero and triggers an interrupt. The CPU jumps to `SysTick_Handler()` (vector table entry 15), increments `systick_count`, and returns. The main loop watches this counter and prints a message every 5000 ticks.

---

## GDB Evidence

I ran the following GDB session to verify that everything works as expected. QEMU was started in debug mode and I connected GDB to it.

### Part A — checking the vector table, SP, PC, and Thumb bit

First I connected to QEMU which was halted right at reset:

```
(gdb) target remote :3333
Remote debugging using :3333
Reset_Handler () at startup/startup_stm32f4.s:39
39          ldr r0, =_sidata
```

Then I looked at the first two entries of the vector table directly in memory:

```
(gdb) x/2xw 0x08000000
0x8000000:      0x20020000      0x0800012D
```

So entry 0 is `0x20020000` which is our initial SP (top of RAM). Entry 1 is `0x0800012D` — thats the Reset_Handler address and since its an odd number (ends in D) the Thumb bit is definitely set.

Next I checked that the CPU actually loaded SP from the vector table:

```
(gdb) info registers sp
sp             0x20020000          0x20020000
```

Yep, SP is `0x20020000` — exactly what was in vector table entry 0.

And PC should be at Reset_Handler:

```
(gdb) info registers pc
pc             0x800012c           0x800012c <Reset_Handler>
```

PC is at `0x0800012C` which is Reset_Handler. Makes sense since `0x0800012D` minus the Thumb bit gives `0x0800012C`.

I also dumped the entire vector table to make sure all exception handler entries have the Thumb bit set:

```
(gdb) x/16xw 0x08000000
0x8000000:      0x20020000      0x0800012d      0x08000171      0x08000171
0x8000010:      0x08000171      0x08000171      0x08000171      0x00000000
0x8000020:      0x00000000      0x00000000      0x00000000      0x08000171
0x8000030:      0x08000171      0x00000000      0x08000171      0x0800007d
```

All the handler addresses end in odd digits (0x0800012d, 0x08000171, 0x0800007d) so they all have bit 0 set. The zeros are just reserved entries. Entry 15 at the end is `0x0800007D` which is our SysTick_Handler from main.c.

### Part B — checking .data copy and .bss zeroing

I set a breakpoint at main and let it run through the startup code:

```
(gdb) break main
Breakpoint 1 at 0x8000098: file src/main.c, line 31.

(gdb) continue
Continuing.

Breakpoint 1, main () at src/main.c:31
31          sh_puts("Boot OK\r\n");
```

Now Reset_Handler has already done its thing. Lets see if the variables are correct:

```
(gdb) print initialized
$1 = 123

(gdb) print uninitialized
$2 = 0
```

`initialized` is 123 so the .data copy from Flash to RAM worked. `uninitialized` is 0 so the .bss zeroing worked too.

To really prove the copy happened I checked the addresses of these variables:

```
(gdb) print &initialized
$3 = (int *) 0x20000000

(gdb) print &uninitialized
$4 = (int *) 0x20000004
```

Both are in SRAM (0x2000xxxx range), not in Flash. So `initialized` really was copied from its Flash location at `0x080001BA` to RAM at `0x20000000`. If the startup code hadn't run, this value wouldn't be here.

### Part D — semihosting output

After continuing from the breakpoint, these messages showed up on the QEMU terminal:

```
Boot OK
Data/BSS verified
SysTick enabled
```

This proves we reached main() and semihosting is working properly.

### Part E — SysTick is actually running

I let the program run for a few seconds then hit Ctrl+C to pause it:

```
(gdb) continue
Continuing.
^C
Program received signal SIGINT, Interrupt.

(gdb) print systick_count
$5 = 48352

(gdb) print &systick_count
$6 = (volatile uint32_t *) 0x20000008
```

`systick_count` is 48352 which is definitely not zero, so the SysTick interrupt has been firing and the handler has been incrementing the counter. The variable is at `0x20000008` which is in .bss in SRAM.

I also read the SysTick control register directly to confirm it's configured right:

```
(gdb) x/xw 0xE000E010
0xe000e010:     0x00010007
```

The bottom 3 bits are all 1 (0x7) which means CLKSOURCE, TICKINT, and ENABLE are all on. Bit 16 is also set — thats the COUNTFLAG which means the counter has counted down to zero at least once. So SysTick is running and generating interrupts as expected.

---

## Map File Analysis

The `firmware.map` file gets generated during linking. Here are the important parts from it:

### Where the vector table ended up

```
.isr_vector     0x08000000       0x40
 .isr_vector    0x08000000       0x40 startup/startup_stm32f4.o
                0x08000000                g_pfnVectors
```

Its right at `0x08000000` which is the start of Flash — exactly where the Cortex-M CPU expects to find it. The 0x40 = 64 bytes covers all 16 entries (initial SP + 15 exception vectors).

### The .data section has two addresses

```
.data           0x20000000        0x4 load address 0x080001ba
                0x20000000                        _sdata = .
 .data          0x20000000        0x4 src/main.o
                0x20000000                initialized
                0x20000004                        _edata = .
```

This is the interesting part. The .data section shows up at `0x20000000` in RAM (thats where the code uses it from) but it also says "load address 0x080001ba" — thats where the actual bytes are stored in the binary in Flash. The startup code bridges this gap by copying from `0x080001BA` to `0x20000000` before main() runs.

### How much memory we actually used

Flash: .isr_vector (64 bytes) + .text (306 bytes) + .rodata (70 bytes) + .data initial values (4 bytes) = 444 bytes out of 512 KB. We're barely using any of it.

SRAM: .data (4 bytes) + .bss (8 bytes) = 12 bytes out of 128 KB, plus the stack growing down from the top. Again barely anything.