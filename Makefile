QEMU = /usr/bin/qemu-system-i386
CC = gcc
AS = gas
LD = ld
OBJCOPY = objcopy
OBJDUMP = objdump
CFLAGS = -fno-pic -static -fno-builtin -fno-strict-aliasing -O2 -Wall -MD -ggdb -m32 -Werror -fno-omit-frame-pointer
CFLAGS += $(shell $(CC) -fno-stack-protector -E -x c /dev/null >/dev/null 2>&1 && echo -fno-stack-protector)
ASFLAGS = -m32 -gdwarf-2 -Wa,-divide
LDFLAGS += -m $(shell $(LD) -V | grep elf_i386 2>/dev/null | head -n 1)


## xv6.img
BOOTBLOCK_DIR = bootloader/
MODULES_DIR = kernel_modules/
CORE_DIR = kernel_core/

## fs.img
ULIB_DIR = ulib/
UPROG_DIR = uprog/
MKFS_DIR = mkfs_/

## header files
INCLUDE_DIR = include/

## build
BUILD_DIR = build/
$(shell mkdir -p $(BUILD_DIR))

#### xv6.img ####################################
bootblock: $(BOOTBLOCK_DIR)bootasm.S $(BOOTBLOCK_DIR)bootmain.c
	$(CC) $(CFLAGS) -fno-pic -O -nostdinc -I. -c -o $(BUILD_DIR)bootmain.o $(BOOTBLOCK_DIR)bootmain.c
	$(CC) $(CFLAGS) -fno-pic -nostdinc -I. -c -o $(BUILD_DIR)bootasm.o $(BOOTBLOCK_DIR)bootasm.S
	$(LD) $(LDFLAGS) -N -e start -Ttext 0x7C00 -o $(BUILD_DIR)bootblock.o $(BUILD_DIR)bootasm.o $(BUILD_DIR)bootmain.o
	$(OBJDUMP) -S $(BUILD_DIR)bootblock.o > $(BUILD_DIR)bootblock.asm
	$(OBJCOPY) -S -O binary -j .text $(BUILD_DIR)bootblock.o $(BUILD_DIR)bootblock
	./$(BOOTBLOCK_DIR)sign.pl $(BUILD_DIR)bootblock

# modules/vectors.o
$(BUILD_DIR)vectors.S: $(MODULES_DIR)vectors.pl
	./$(MODULES_DIR)vectors.pl > $(BUILD_DIR)vectors.S

$(BUILD_DIR)_module_vectors.o: $(BUILD_DIR)vectors.S
	$(CC) -m32 -gdwarf-2 -Wa,-divide -c -o $(BUILD_DIR)_module_vectors.o $<

# modules/*.c
$(BUILD_DIR)_module_%.o: $(MODULES_DIR)%.c
	$(CC) $(CFLAGS) -fno-pie -no-pie -c -o $(BUILD_DIR)_module_$*.o $<

# modules/*.S
$(BUILD_DIR)_module_%.o: $(MODULES_DIR)%.S
	$(CC) -m32 -gdwarf-2 -Wa,-divide -c -o $(BUILD_DIR)_module_$*.o $<

OBJS = \
	$(BUILD_DIR)_module_bio.o\
	$(BUILD_DIR)_module_console.o\
	$(BUILD_DIR)_module_exec.o\
	$(BUILD_DIR)_module_file.o\
	$(BUILD_DIR)_module_fs.o\
	$(BUILD_DIR)_module_ide.o\
	$(BUILD_DIR)_module_ioapic.o\
	$(BUILD_DIR)_module_kalloc.o\
	$(BUILD_DIR)_module_kbd.o\
	$(BUILD_DIR)_module_lapic.o\
	$(BUILD_DIR)_module_log.o\
	$(BUILD_DIR)_module_main.o\
	$(BUILD_DIR)_module_mp.o\
	$(BUILD_DIR)_module_picirq.o\
	$(BUILD_DIR)_module_pipe.o\
	$(BUILD_DIR)_module_proc.o\
	$(BUILD_DIR)_module_sleeplock.o\
	$(BUILD_DIR)_module_spinlock.o\
	$(BUILD_DIR)_module_string.o\
	$(BUILD_DIR)_module_swtch.o\
	$(BUILD_DIR)_module_syscall.o\
	$(BUILD_DIR)_module_sysfile.o\
	$(BUILD_DIR)_module_sysproc.o\
	$(BUILD_DIR)_module_trapasm.o\
	$(BUILD_DIR)_module_trap.o\
	$(BUILD_DIR)_module_uart.o\
	$(BUILD_DIR)_module_vectors.o\
	$(BUILD_DIR)_module_vm.o\



entryother: $(CORE_DIR)entryother.S
	$(CC) $(CFLAGS) -fno-pie -no-pie -fno-pic -nostdinc -I. -c -o $(BUILD_DIR)entryother.o $(CORE_DIR)entryother.S
	$(LD) $(LDFLAGS) -N -e start -Ttext 0x7000 -o $(BUILD_DIR)bootblockother.o $(BUILD_DIR)entryother.o
	$(OBJCOPY) -S -O binary -j .text $(BUILD_DIR)bootblockother.o $(BUILD_DIR)entryother
	$(OBJDUMP) -S $(BUILD_DIR)bootblockother.o > $(BUILD_DIR)entryother.asm

initcode: $(CORE_DIR)initcode.S
	$(CC) $(CFLAGS)  -fno-pie -no-pie -nostdinc -I. -c -o $(BUILD_DIR)initcode.o $(CORE_DIR)initcode.S
	$(LD) $(LDFLAGS) -N -e start -Ttext 0 -o $(BUILD_DIR)initcode.out $(BUILD_DIR)initcode.o
	$(OBJCOPY) -S -O binary $(BUILD_DIR)initcode.out $(BUILD_DIR)initcode
	$(OBJDUMP) -S $(BUILD_DIR)initcode.o > $(BUILD_DIR)initcode.asm

kernel: $(OBJS) $(BUILD_DIR)_module_entry.o entryother initcode $(CORE_DIR)kernel.ld
	$(LD) $(LDFLAGS) -T $(CORE_DIR)kernel.ld -o $(BUILD_DIR)kernel $(BUILD_DIR)_module_entry.o $(OBJS) -b binary $(BUILD_DIR)entryother $(BUILD_DIR)initcode
	$(OBJDUMP) -S $(BUILD_DIR)kernel > $(BUILD_DIR)kernel.asm 
	$(OBJDUMP) -t $(BUILD_DIR)kernel | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $(BUILD_DIR)kernel.sym

xv6.img: bootblock kernel
	dd if=/dev/zero of=$(BUILD_DIR)xv6.img count=10000
	dd if=$(BUILD_DIR)bootblock of=$(BUILD_DIR)xv6.img conv=notrunc
	dd if=$(BUILD_DIR)kernel of=$(BUILD_DIR)xv6.img seek=1 conv=notrunc
################################################



#### fs.img ####################################
mkfs: $(MKFS_DIR)mkfs.c $(INCLUDE_DIR)fs.h
	gcc -Werror -Wall -o $(BUILD_DIR)mkfs $(MKFS_DIR)mkfs.c

# ulib/*.c
$(BUILD_DIR)%.o: $(ULIB_DIR)%.c
	$(CC) $(CFLAGS) -fno-pie -no-pie -c -o $@ $<

# ulib/*.S
$(BUILD_DIR)%.o: $(ULIB_DIR)%.S
	$(CC) -m32 -gdwarf-2 -Wa,-divide -c -o $@ $<

ULIB = $(BUILD_DIR)ulib.o $(BUILD_DIR)usys.o $(BUILD_DIR)printf.o $(BUILD_DIR)umalloc.o

# uprog/*.c
$(BUILD_DIR)%.o: $(UPROG_DIR)%.c
	$(CC) $(CFLAGS) -fno-pie -no-pie -c -o $@ $<

$(BUILD_DIR)_%: $(BUILD_DIR)%.o $(ULIB)
	$(LD) $(LDFLAGS) -N -e main -Ttext 0 -o $@ $^
	$(OBJDUMP) -S $@ > $(BUILD_DIR)$*.asm
	$(OBJDUMP) -t $@ | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $(BUILD_DIR)$*.sym

UPROGS=\
	$(BUILD_DIR)_cat\
	$(BUILD_DIR)_echo\
	$(BUILD_DIR)_grep\
	$(BUILD_DIR)_init\
	$(BUILD_DIR)_kill\
	$(BUILD_DIR)_ln\
	$(BUILD_DIR)_ls\
	$(BUILD_DIR)_mkdir\
	$(BUILD_DIR)_rm\
	$(BUILD_DIR)_sh\

fs.img: mkfs README $(UPROGS)
	./$(BUILD_DIR)mkfs $(BUILD_DIR)fs.img README $(UPROGS)
################################################

qemu-nox: fs.img xv6.img
	$(QEMU) -nographic -drive file=fs.img,index=1,media=disk,format=raw -drive file=xv6.img,index=0,media=disk,format=raw -smp 2 -m 512

# -include *.d

clean: 
	find ./ -name "*.o" -exec rm -f {} +
	find ./ -name "*.d" -exec rm -f {} +
	find ./ -name "*.asm" -exec rm -f {} +
	find ./ -name "*.sym" -exec rm -f {} +
	find ./ -name "_*" -exec rm -f {} +
	rm -rf $(BUILD_DIR)
	rm -f vectors.S bootblock entryother initcode initcode.out kernel xv6.img fs.img 