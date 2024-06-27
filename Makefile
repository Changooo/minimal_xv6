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
$(shell mkdir -p $(BUILD_DIR))

#### xv6.img ####################################
bootblock: $(BOOTBLOCK_DIR)bootasm.S $(BOOTBLOCK_DIR)bootmain.c
	$(CC) $(CFLAGS) -fno-pic -O -nostdinc -I. -c -o $(BUILD_DIR)bootmain.o $(BOOTBLOCK_DIR)bootmain.c
	$(CC) $(CFLAGS) -fno-pic -nostdinc -I. -c -o $(BUILD_DIR)bootasm.o $(BOOTBLOCK_DIR)bootasm.S
	$(LD) $(LDFLAGS) -N -e start -Ttext 0x7C00 -o $(BUILD_DIR)bootblock.o $(BUILD_DIR)bootasm.o $(BUILD_DIR)bootmain.o
	$(OBJDUMP) -S $(BUILD_DIR)bootblock.o > $(BUILD_DIR)bootblock.asm
	$(OBJCOPY) -S -O binary -j .text $(BUILD_DIR)bootblock.o $(BUILD_DIR)bootblock
	./$(BOOTBLOCK_DIR)sign.pl $(BUILD_DIR)bootblock

# entry.o: $(MODULES_DIR)entry.S
# 	$(CC) -m32 -gdwarf-2 -Wa,-divide -c -o $@ $<

$(BUILD_DIR)vectors.S: $(MODULES_DIR)vectors.pl
	./$(MODULES_DIR)vectors.pl > $(BUILD_DIR)vectors.S
# $(MODULES_DIR)vectors.S: $(MODULES_DIR)vectors.pl
# 	./$(MODULES_DIR)vectors.pl > $(MODULES_DIR)vectors.S
# vectors.S: vectors.pl
# 	./vectors.pl > vectors.S

$(BUILD_DIR)%.o: $(MODULES_DIR)%.c
	$(CC) $(CFLAGS) -fno-pie -no-pie -c -o $@ $<

$(BUILD_DIR)%.o: $(MODULES_DIR)%.S
	$(CC) -m32 -gdwarf-2 -Wa,-divide -c -o $@ $<

$(BUILD_DIR)%.o: $(BUILD_DIR)vectors.S
	$(CC) -m32 -gdwarf-2 -Wa,-divide -c -o $@ $<
# $(MODULES_DIR)vectors.o: $(MODULES_DIR)vectors.S
# 	$(CC) -m32 -gdwarf-2 -Wa,-divide -c -o $@ $<


OBJS = \
	$(BUILD_DIR)bio.o\
	$(BUILD_DIR)console.o\
	$(BUILD_DIR)exec.o\
	$(BUILD_DIR)file.o\
	$(BUILD_DIR)fs.o\
	$(BUILD_DIR)ide.o\
	$(BUILD_DIR)ioapic.o\
	$(BUILD_DIR)kalloc.o\
	$(BUILD_DIR)kbd.o\
	$(BUILD_DIR)lapic.o\
	$(BUILD_DIR)log.o\
	$(BUILD_DIR)main.o\
	$(BUILD_DIR)mp.o\
	$(BUILD_DIR)picirq.o\
	$(BUILD_DIR)pipe.o\
	$(BUILD_DIR)proc.o\
	$(BUILD_DIR)sleeplock.o\
	$(BUILD_DIR)spinlock.o\
	$(BUILD_DIR)string.o\
	$(BUILD_DIR)swtch.o\
	$(BUILD_DIR)syscall.o\
	$(BUILD_DIR)sysfile.o\
	$(BUILD_DIR)sysproc.o\
	$(BUILD_DIR)trapasm.o\
	$(BUILD_DIR)trap.o\
	$(BUILD_DIR)uart.o\
	$(BUILD_DIR)vectors.o\
	$(BUILD_DIR)vm.o\

entryother: $(CORE_DIR)entryother.S
	$(CC) $(CFLAGS) -fno-pie -no-pie -fno-pic -nostdinc -I. -c -o $(BUILD_DIR)entryother.o $(CORE_DIR)entryother.S
	$(LD) $(LDFLAGS) -N -e start -Ttext 0x7000 -o $(BUILD_DIR)bootblockother.o $(BUILD_DIR)entryother.o
	$(OBJCOPY) -S -O binary -j .text $(BUILD_DIR)bootblockother.o $(BUILD_DIR)entryother
	$(OBJDUMP) -S $(BUILD_DIR)bootblockother.o > $(BUILD_DIR)entryother.asm
#maybe objdump unnecessary

initcode: $(CORE_DIR)initcode.S
	$(CC) $(CFLAGS)  -fno-pie -no-pie -nostdinc -I. -c -o $(BUILD_DIR)initcode.o $(CORE_DIR)initcode.S
	$(LD) $(LDFLAGS) -N -e start -Ttext 0 -o $(BUILD_DIR)initcode.out $(BUILD_DIR)initcode.o
	$(OBJCOPY) -S -O binary $(BUILD_DIR)initcode.out $(BUILD_DIR)initcode
	$(OBJDUMP) -S $(BUILD_DIR)initcode.o > $(BUILD_DIR)initcode.asm
#maybe objdump unnecessary

kernel: $(OBJS) $(BUILD_DIR)entry.o entryother initcode $(CORE_DIR)kernel.ld
	$(LD) $(LDFLAGS) -T $(CORE_DIR)kernel.ld -o $(BUILD_DIR)kernel $(BUILD_DIR)entry.o $(OBJS) -b binary $(BUILD_DIR)initcode $(BUILD_DIR)entryother
#maybe objdump unnecessary
# kernel: $(OBJS) $(BUILD_DIR)entry.o $(BUILD_DIR)entryother $(BUILD_DIR)initcode $(CORE_DIR)kernel.ld
# 	$(LD) $(LDFLAGS) -T $(CORE_DIR)kernel.ld -o $(BUILD_DIR)kernel $(BUILD_DIR)entry.o $(OBJS) -b binary $(BUILD_DIR)initcode $(BUILD_DIR)entryother
# 	$(OBJDUMP) -S $(BUILD_DIR)kernel > $(BUILD_DIR)kernel.asm
# 	$(OBJDUMP) -t $(BUILD_DIR)kernel | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $(BUILD_DIR)kernel.sym

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

# -include *.d

clean: 
	find ./ -name "*.o" -exec rm -f {} +
	find ./ -name "*.d" -exec rm -f {} +
	find ./ -name "*.asm" -exec rm -f {} +
	find ./ -name "*.sym" -exec rm -f {} +
	find ./ -name "_*" -exec rm -f {} +
	rm -rf $(BUILD_DIR)
	rm -f vectors.S bootblock entryother initcode initcode.out kernel xv6.img fs.img 