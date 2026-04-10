# STM32F4 Bare-Metal Boot — Assignment 1

Course: Embedded Systems
Target MCU: STM32F4 (Cortex-M4F)
Platform: QEMU (olimex-stm32-h405)

---

## Memory Map

The STM32F405 has two memory regions relevant to this project:

-  Flash  starts at `0x08000000`, size 512 KB. This is non-volatile storage where our code, constants, and initial values for .data live. It is read-only at runtime.
-  SRAM  starts at `0x20000000`, size 128 KB. This is volatile read-write memory used for variables (.data and .bss sections) and the stack.

At boot the STM32 aliases Flash to address `0x00000000` so the CPU can read the vector table from address zero.

### Flash layout (from linker map)

The sections are placed in Flash in this order:

- `0x08000000` — `.isr_vector` (64 bytes): the vector table containing initial SP, Reset_Handler address, and all exception handler addresses.
- `0x08000040` — `.text` (382 bytes): all executable code including `main()`, `SysTick_Handler()`, `Reset_Handler`, and default exception handlers. Read-only data (string literals) is also placed here.
- `0x080001BE` — `.data` initial values (4 bytes): the value `123` for the `initialized` variable, stored here in Flash and copied to SRAM by the startup code.

Total Flash used: ~450 bytes.

### SRAM layout

- `0x20000000` — `.data` (4 bytes): runtime location of `initialized`. Copied from Flash at startup.
- `0x20000004` — `.bss` (8 bytes): contains `uninitialized` (4 bytes) and `systick_count` (4 bytes). Zeroed by startup code.
- `0x20020000` — `_estack`: top of SRAM, initial stack pointer. Stack grows downward from here.

Total SRAM used: 12 bytes plus stack.

### Linker symbols used by startup code

- `_estack = 0x20020000` — initial stack pointer, top of SRAM
- `_sidata = 0x080001BE` — where .data initial values are stored in Flash (copy source)
- `_sdata = 0x20000000` — start of .data in SRAM (copy destination)
- `_edata = 0x20000004` — end of .data in SRAM
- `_sbss = 0x20000004` — start of .bss in SRAM
- `_ebss = 0x2000000C` — end of .bss in SRAM

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

On Windows, install QEMU and the ARM GNU toolchain and add both to PATH.
On Linux: `sudo apt install qemu-system-arm gcc-arm-none-eabi gdb-multiarch make`

Then:
```
make clean
make all
```

This compiles `main.c` and `startup_stm32f4.s` into object files, links them using `linker.ld`, and extracts the raw binary with `objcopy`. The build produces `firmware.elf`, `firmware.bin`, and `firmware.map`.

Size output from a clean build:
```
   text    data     bss     dec     hex filename
    446       4       8     458     1ca firmware.elf
```

---

## QEMU Run and Debug Commands

### Running

```
qemu-system-arm -M olimex-stm32-h405 -kernel firmware.bin -semihosting-config enable=on,target=native -nographic
```

Or just `make run`. Press Ctrl+A then X to exit QEMU.

Expected output:
```
Boot OK
Data/BSS verified
SysTick enabled
SysTick running
SysTick running
...
```

### Debugging with GDB

Terminal 1 — start QEMU stopped, waiting for GDB:
```
qemu-system-arm -M olimex-stm32-h405 -kernel firmware.bin -semihosting-config enable=on,target=native -S -gdb tcp::3333 -nographic
```

Terminal 2 — connect GDB (use `gdb-multiarch` on Linux):
```
arm-none-eabi-gdb firmware.elf
(gdb) target remote :3333
```

---

## Boot Sequence Explanation

Here is the sequence of events from power-on reset to running C code:

1.  CPU reset  — all registers go to defaults. The CPU prepares to read the first two words from address 0x00000000 (aliased to Flash 0x08000000).

2.  SP loaded  — the CPU reads the 32-bit word at 0x08000000 which is `_estack = 0x20020000`. This becomes the initial Main Stack Pointer. The stack is now set up at the top of SRAM.

3.  PC loaded  — the CPU reads the word at 0x08000004 which is the address of `Reset_Handler` with the Thumb bit (bit 0) set. This goes into the Program Counter and execution starts.

4.  Copy .data  — `Reset_Handler` copies initialized variable values from their storage location in Flash (`_sidata = 0x080001BE`) to their runtime location in SRAM (`_sdata` to `_edata`). After this, `initialized` contains the value 123 in RAM.

5.  Zero .bss  — `Reset_Handler` fills the .bss region (`_sbss` to `_ebss`) with zeros. This ensures `uninitialized` and `systick_count` start at zero, as required by the C standard.

6.  Call main()  — with the C runtime environment prepared, the handler executes `bl main` to jump to our application code.

7.  Observable output  — `main()` calls `sh_puts("Boot OK")` which triggers a semihosting call (BKPT 0xAB). QEMU intercepts this and prints the string to the host terminal. This proves the entire boot path worked.

8.  Verify initialization  — `main()` checks that `initialized == 123` and `uninitialized == 0`, then prints "Data/BSS verified". This confirms both the .data copy and .bss zeroing worked correctly.

9.  Configure SysTick  — `main()` writes to the SysTick registers at 0xE000E010–0xE000E018. It sets the reload value to 8000, clears the current value, and enables the timer with interrupt generation (CSR = 0x07).

10.  Interrupts running  — every 8000 clock cycles the SysTick counter reaches zero and fires an interrupt. The CPU looks up entry 15 in the vector table, jumps to `SysTick_Handler()` which increments `systick_count`. The main loop detects the change and prints periodic status messages.

---

## GDB Evidence

Below is the captured output from a GDB debugging session.

### Verifying the vector table

```
(gdb) target remote :3333
Remote debugging using :3333
Reset_Handler () at startup/startup_stm32f4.s:39
39          ldr r0, =_sidata

(gdb) x/2xw 0x08000000
0x8000000:      0x20020000      0x08000131
```

First word is 0x20020000 — the initial SP pointing to top of SRAM. Second word is 0x08000131 — the Reset_Handler address. Bit 0 is 1, confirming the Thumb bit is set.

### Verifying SP and PC after reset

```
(gdb) info registers sp
sp             0x20020000          0x20020000

(gdb) info registers pc
pc             0x8000130           0x8000130 <Reset_Handler>
```

SP matches `_estack` (0x20020000). PC is at Reset_Handler (0x08000130).

### Verifying runtime initialization at main()

```
(gdb) break main
Breakpoint 1 at 0x800009c: file src/main.c, line 31.

(gdb) continue
Continuing.

Breakpoint 1, main () at src/main.c:31
31          sh_puts("Boot OK\r\n");

(gdb) print initialized
$1 = 123

(gdb) print uninitialized
$2 = 0

(gdb) print &initialized
$3 = (int *) 0x20000000

(gdb) print &uninitialized
$4 = (int *) 0x20000004
```

`initialized` is 123 and lives at 0x20000000 (SRAM, not Flash), so the .data copy worked. `uninitialized` is 0 at 0x20000004 in SRAM, so the .bss zeroing worked.

### Verifying SysTick interrupt

```
(gdb) continue
Continuing.
^C
Program received signal SIGINT, Interrupt.

(gdb) print systick_count
$5 = 48352
```

The counter is non-zero, which proves the SysTick interrupt handler has been executing repeatedly and incrementing the variable.

---

## Map File Analysis

The generated `firmware.map` file shows how the linker placed everything. Here are the key parts:

### Vector table placement

```
.isr_vector     0x08000000       0x40
 .isr_vector    0x08000000       0x40 startup/startup_stm32f4.o
                0x08000000                g_pfnVectors
```

The vector table is at the very start of Flash (0x08000000), exactly where the Cortex-M expects it. It is 0x40 = 64 bytes, covering 16 entries (SP + 15 exception vectors).

### .data load address vs run address

```
.data           0x20000000        0x4 load address 0x080001be
                0x20000000                        _sdata = .
 .data          0x20000000        0x4 src/main.o
                0x20000000                initialized
                0x20000004                        _edata = .
```

The `.data` section runs from SRAM at 0x20000000 (VMA) but is loaded/stored in Flash at 0x080001BE (LMA). The variable `initialized` is the only thing in .data (4 bytes). The startup code copies from the LMA to the VMA before main() runs.

### Flash and SRAM usage

Flash usage: .isr_vector (64 bytes) + .text (382 bytes) + .data initial values (4 bytes) = 450 bytes out of 512 KB.

SRAM usage: .data (4 bytes) + .bss (8 bytes) = 12 bytes out of 128 KB, plus the stack which grows downward from 0x20020000.