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

## header files
INCLUDE_DIR = include/

## build
BUILD_DIR = build/


#### xv6.img ####################################
bootblock: $(BOOTBLOCK_DIR)bootasm.S $(BOOTBLOCK_DIR)bootmain.c
	$(CC) $(CFLAGS) -fno-pic -O -nostdinc -I. -c $(BOOTBLOCK_DIR)bootmain.c
	$(CC) $(CFLAGS) -fno-pic -nostdinc -I. -c $(BOOTBLOCK_DIR)bootasm.S
	$(LD) $(LDFLAGS) -N -e start -Ttext 0x7C00 -o bootblock.o bootasm.o bootmain.o
	$(OBJDUMP) -S bootblock.o > bootblock.asm
	$(OBJCOPY) -S -O binary -j .text bootblock.o bootblock
	./$(BOOTBLOCK_DIR)sign.pl bootblock

$(MODULES_DIR)vectors.S: $(MODULES_DIR)vectors.pl
	./$(MODULES_DIR)vectors.pl > $(MODULES_DIR)vectors.S


OBJS = \
	$(MODULES_DIR)bio.o\
	$(MODULES_DIR)console.o\
	$(MODULES_DIR)exec.o\
	$(MODULES_DIR)file.o\
	$(MODULES_DIR)fs.o\
	$(MODULES_DIR)ide.o\
	$(MODULES_DIR)ioapic.o\
	$(MODULES_DIR)kalloc.o\
	$(MODULES_DIR)kbd.o\
	$(MODULES_DIR)lapic.o\
	$(MODULES_DIR)log.o\
	$(MODULES_DIR)main.o\
	$(MODULES_DIR)mp.o\
	$(MODULES_DIR)picirq.o\
	$(MODULES_DIR)pipe.o\
	$(MODULES_DIR)proc.o\
	$(MODULES_DIR)sleeplock.o\
	$(MODULES_DIR)spinlock.o\
	$(MODULES_DIR)string.o\
	$(MODULES_DIR)swtch.o\
	$(MODULES_DIR)syscall.o\
	$(MODULES_DIR)sysfile.o\
	$(MODULES_DIR)sysproc.o\
	$(MODULES_DIR)trapasm.o\
	$(MODULES_DIR)trap.o\
	$(MODULES_DIR)uart.o\
	$(MODULES_DIR)vectors.o\
	$(MODULES_DIR)vm.o\


entryother: $(CORE_DIR)entryother.S
	$(CC) $(CFLAGS) -fno-pic -nostdinc -I. -c $(CORE_DIR)entryother.S
	$(LD) $(LDFLAGS) -N -e start -Ttext 0x7000 -o bootblockother.o entryother.o
	$(OBJCOPY) -S -O binary -j .text bootblockother.o entryother
	$(OBJDUMP) -S bootblockother.o > entryother.asm

initcode: $(CORE_DIR)initcode.S
	$(CC) $(CFLAGS) -nostdinc -I. -c $(CORE_DIR)initcode.S
	$(LD) $(LDFLAGS) -N -e start -Ttext 0 -o initcode.out initcode.o
	$(OBJCOPY) -S -O binary initcode.out initcode
	$(OBJDUMP) -S initcode.o > initcode.asm

kernel: $(OBJS) $(MODULES_DIR)entry.o entryother initcode $(CORE_DIR)kernel.ld
	$(LD) $(LDFLAGS) -T $(CORE_DIR)kernel.ld -o kernel $(MODULES_DIR)entry.o $(OBJS) -b binary initcode entryother
	$(OBJDUMP) -S kernel > $(CORE_DIR)kernel.asm
	$(OBJDUMP) -t kernel | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > kernel.sym

xv6.img: bootblock kernel
	dd if=/dev/zero of=xv6.img count=10000
	dd if=bootblock of=xv6.img conv=notrunc
	dd if=kernel of=xv6.img seek=1 conv=notrunc
################################################



#### fs.img ####################################
mkfs: mkfs.c $(INCLUDE_DIR)fs.h
	gcc -Werror -Wall -o mkfs mkfs.c
	
ULIB = $(ULIB_DIR)ulib.o $(ULIB_DIR)usys.o $(ULIB_DIR)printf.o $(ULIB_DIR)umalloc.o

_%: $(UPROG_DIR)%.o $(ULIB)
	$(LD) $(LDFLAGS) -N -e main -Ttext 0 -o $@ $^
	$(OBJDUMP) -S $@ > $*.asm
	$(OBJDUMP) -t $@ | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $*.sym

UPROGS=\
	_cat\
	_echo\
	_grep\
	_init\
	_kill\
	_ln\
	_ls\
	_mkdir\
	_rm\
	_sh\

fs.img: mkfs README $(UPROGS)
	./mkfs fs.img README $(UPROGS)
################################################

qemu-nox: fs.img xv6.img
	$(QEMU) -nographic -drive file=fs.img,index=1,media=disk,format=raw -drive file=xv6.img,index=0,media=disk,format=raw -smp 2 -m 512

clean: 
	find ./ -name "*.o" -exec rm -f {} +
	find ./ -name "*.d" -exec rm -f {} +
	find ./ -name "*.asm" -exec rm -f {} +
	find ./ -name "*.sym" -exec rm -f {} +
	find ./ -name "_*" -exec rm -f {} +
	rm -f vectors.S bootblock entryother initcode initcode.out kernel xv6.img fs.img mkfs