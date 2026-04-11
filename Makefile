# Cross-compilation tools - we use the arm-none-eabi toolchain
# since we're building for an ARM chip with no OS underneath
CC = arm-none-eabi-gcc
OBJCOPY = arm-none-eabi-objcopy
SIZE = arm-none-eabi-size
GDB = arm-none-eabi-gdb

# Output name and input source files
TARGET = firmware
C_SRCS = src/main.c
S_SRCS = startup/startup_stm32f4.s
LD_SCRIPT = ld/linker.ld

# Turn source file names into .o names (main.c -> main.o etc.)
OBJS = $(C_SRCS:.c=.o) $(S_SRCS:.s=.o)

# Compiler flags:
#   -mcpu=cortex-m4 and -mthumb: target our specific CPU
#   -O0 -g: no optimization + debug symbols so GDB works nicely
#   -Wall: turn on warnings
#   -ffreestanding -nostdlib: we have no OS or standard library
#   -mfpu and -mfloat-abi: set up the hardware floating point unit
CFLAGS = -mcpu=cortex-m4 -mthumb -O0 -g \
         -Wall -ffreestanding -nostdlib \
         -mfpu=fpv4-sp-d16 -mfloat-abi=hard

# Same flags work for assembling .s files too
ASFLAGS = $(CFLAGS)

# Linker flags: use our custom linker script and generate a map file
# -nostdlib again because we dont want any default startup code
LDFLAGS = -T $(LD_SCRIPT) -nostdlib -Wl,-Map=$(TARGET).map

# Default target - just build the binary
all: $(TARGET).bin

# Compile C files into object files
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

# Assemble .s files into object files
%.o: %.s
	$(CC) $(ASFLAGS) -c $< -o $@

# Link all object files into an ELF using our linker script
# also print the size breakdown (text/data/bss) so we can see memory usage
$(TARGET).elf: $(OBJS)
	$(CC) $(OBJS) $(LDFLAGS) -o $@
	$(SIZE) $@

# Strip the ELF down to a raw binary that QEMU can load directly
$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

# Remove all build artifacts so we can start fresh
clean:
	rm -f $(OBJS) $(TARGET).elf $(TARGET).bin $(TARGET).map

# Run the firmware in QEMU with semihosting enabled
# Ctrl+A then X to quit
run: $(TARGET).bin
	qemu-system-arm -M olimex-stm32-h405 -kernel $(TARGET).bin \
		-semihosting-config enable=on,target=native -nographic

# Start QEMU paused with a GDB server and connect to it
# Useful for stepping through the boot sequence
debug: $(TARGET).elf
	qemu-system-arm -M olimex-stm32-h405 -kernel $(TARGET).bin \
		-S -gdb tcp::3333 -nographic &
	gdb-multiarch $(TARGET).elf -ex "target remote :3333"

# These targets dont correspond to actual files
.PHONY: all clean run debug