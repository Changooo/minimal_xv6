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
BOOTBLOCK_DIR = ../bootloader/
MODULES_DIR = ../kernel_modules/
CORE_DIR = ../kernel_core/

## fs.img
ULIB_DIR = ../ulib/
UPROG_DIR = ../uprog/
MKFS_DIR = ../mkfs_/

## header files
INCLUDE_DIR = ../include/

all: qemu-nox

#### xv6.img ####################################
bootblock: $(BOOTBLOCK_DIR)bootasm.S $(BOOTBLOCK_DIR)bootmain.c
	$(CC) $(CFLAGS) -fno-pic -O -nostdinc -I. -c -o bootmain.o $(BOOTBLOCK_DIR)bootmain.c
	$(CC) $(CFLAGS) -fno-pic -nostdinc -I. -c -o bootasm.o $(BOOTBLOCK_DIR)bootasm.S
	$(LD) $(LDFLAGS) -N -e start -Ttext 0x7C00 -o bootblock.o bootasm.o bootmain.o
	$(OBJDUMP) -S bootblock.o > bootblock.asm
	$(OBJCOPY) -S -O binary -j .text bootblock.o bootblock
	./$(BOOTBLOCK_DIR)sign.pl bootblock

vectors.S: $(MODULES_DIR)vectors.pl
	./$(MODULES_DIR)vectors.pl > vectors.S

%.o: $(MODULES_DIR)%.c
	$(CC) $(CFLAGS) -fno-pie -no-pie -c -o $*.o $<
	
%.o: $(MODULES_DIR)%.S
	$(CC) -m32 -gdwarf-2 -Wa,-divide -c -o $*.o $<


OBJS = \
	bio.o\
	console.o\
	exec.o\
	file.o\
	fs.o\
	ide.o\
	ioapic.o\
	kalloc.o\
	kbd.o\
	lapic.o\
	log.o\
	main.o\
	mp.o\
	picirq.o\
	pipe.o\
	proc.o\
	sleeplock.o\
	spinlock.o\
	string.o\
	swtch.o\
	syscall.o\
	sysfile.o\
	sysproc.o\
	trapasm.o\
	trap.o\
	uart.o\
	vectors.o\
	vm.o\

entryother: $(CORE_DIR)entryother.S
	$(CC) $(CFLAGS) -fno-pie -no-pie -fno-pic -nostdinc -I. -c -o entryother.o $(CORE_DIR)entryother.S
	$(LD) $(LDFLAGS) -N -e start -Ttext 0x7000 -o bootblockother.o entryother.o
	$(OBJCOPY) -S -O binary -j .text bootblockother.o entryother
	$(OBJDUMP) -S bootblockother.o > entryother.asm

initcode: $(CORE_DIR)initcode.S
	$(CC) $(CFLAGS)  -fno-pie -no-pie -nostdinc -I. -c -o initcode.o $(CORE_DIR)initcode.S
	$(LD) $(LDFLAGS) -N -e start -Ttext 0 -o initcode.out initcode.o
	$(OBJCOPY) -S -O binary initcode.out initcode
	$(OBJDUMP) -S initcode.o > initcode.asm

kernel: $(OBJS) entry.o entryother initcode $(CORE_DIR)kernel.ld
	$(LD) $(LDFLAGS) -T $(CORE_DIR)kernel.ld -o kernel entry.o $(OBJS) -b binary entryother initcode
	$(OBJDUMP) -S kernel > kernel.asm 
	$(OBJDUMP) -t kernel | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > kernel.sym

xv6.img: bootblock kernel
	dd if=/dev/zero of=xv6.img count=10000
	dd if=bootblock of=xv6.img conv=notrunc
	dd if=kernel of=xv6.img seek=1 conv=notrunc
################################################


#### fs.img ####################################
mkfs: $(MKFS_DIR)mkfs.c $(INCLUDE_DIR)fs.h
	gcc -Werror -Wall -o mkfs $(MKFS_DIR)mkfs.c

ulib.o: $(ULIB_DIR)ulib.c
	$(CC) $(CFLAGS) -fno-pie -no-pie -c -o ulib.o $(ULIB_DIR)ulib.c
umalloc.o: $(ULIB_DIR)umalloc.c
	$(CC) $(CFLAGS) -fno-pie -no-pie -c -o umalloc.o $(ULIB_DIR)umalloc.c
printf.o: $(ULIB_DIR)printf.c
	$(CC) $(CFLAGS) -fno-pie -no-pie -c -o printf.o $(ULIB_DIR)printf.c
usys.o: $(ULIB_DIR)usys.S
	$(CC) -m32 -gdwarf-2 -Wa,-divide -c -o usys.o $(ULIB_DIR)usys.S

ULIB = ulib.o usys.o printf.o umalloc.o

%.o: $(UPROG_DIR)%.c 
	$(CC) $(CFLAGS) -fno-pie -no-pie -c -o $*.o $<

_%: %.o $(ULIB)
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



