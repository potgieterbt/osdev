include build/Config.mk
include build/Common.mk

VERSION := 0.0.0

# arch dependant
ARCH_PREFIX := x86_64-elf
ASM_COMPILER := nasm
QEMU_SYSTEM := qemu-system-x86_64

IS_WORKFLOW = 0

ifeq ($(TOOLCHAIN), gcc)
	X_CC = $(ARCH_PREFIX)-gcc
	X_LD = $(ARCH_PREFIX)-ld
else ifeq ($(TOOLCHAIN), clang)
	X_CC = clang
	X_LD = ld.lld
	LD_FLAGS += -z lrodata-after-bss
else
	$(error "Unknown compiler toolchain")
endif

C_DEBUG_FLAGS := -g \
		-DDEBUG=1

ASM_DEBUG_FLAGS := -g \
		-F dwarf
ASM_FLAGS := -f elf64
ASM_FLAGS += $(DEF_FLAGS)

DEBUG := 0

SRC_C_FILES := $(shell find $(PRJ_FOLDERS) -type f -name "*.c")
SRC_H_FILES := $(shell find $(PRJ_FOLDERS) -type f -name "*.h")
SRC_ASM_FILES := $(shell find $(PRJ_FOLDERS) -type f -name "*.s")
SRC_FONT_FILES := $(shell find $(FONT_FOLDER) -type f -name "*.psf")
OBJ_ASM_FILE := $(patsubst src/%.s, $(BUILD_FOLDER)/%.o, $(SRC_ASM_FILES))
OBJ_C_FILE := $(patsubst src/%.c, $(BUILD_FOLDER)/%.o, $(SRC_C_FILES))
OBJ_FONT_FILE := $(patsubst $(FONT_FOLDER)/%.psf, $(BUILD_FOLDER)/%.o, $(SRC_FONT_FILES))

ISO_IMAGE_FILENAME := $(IMAGE_BASE_NAME)-$(ARCH_PREFIX)-$(VERSION).iso

default: build

.PHONY: default build run clean debug tests gdb todolist


clean:
	-rm -rf $(BUILD_FOLDER)
	-find -name *.o -type f -delete

run: $(BUILD_FOLDER)/$(ISO_IMAGE_FILENAME)
	$(QEMU_SYSTEM) -cdrom $(BUILD_FOLDER)/$(ISO_IMAGE_FILENAME)

debug: DEBUG=1
debug: CFLAGS += $(C_DEBUG_FLAGS)
debug: ASM_FLAGS += $(ASM_DEBUG_FLAGS)
debug: $(BUILD_FOLDER)/$(ISO_IMAGE_FILENAME)
	# TODO could be useful to use  stdio as both log output and monitor input
	# qemu-system-x86_64 -monitor unix:qemu-monitor-socket,server,nowait -cpu qemu64,+x2apic  -cdrom $(BUILD_FOLDER)/$(ISO_IMAGE_FILENAME) -serial file:dreamos64.log -m 1G -d int -no-reboot -no-shutdown
	$(QEMU_SYSTEM) -monitor unix:qemu-monitor-socket,server,nowait -cpu qemu64,+x2apic  -cdrom $(BUILD_FOLDER)/$(ISO_IMAGE_FILENAME) -serial stdio -m 2G  -no-reboot -no-shutdown

$(BUILD_FOLDER)/$(ISO_IMAGE_FILENAME): $(BUILD_FOLDER)/kernel.bin grub.cfg
	mkdir -p $(BUILD_FOLDER)/isofiles/boot/grub
	cp grub.cfg $(BUILD_FOLDER)/isofiles/boot/grub
	cp $(BUILD_FOLDER)/kernel.bin $(BUILD_FOLDER)/isofiles/boot
	cp $(BUILD_FOLDER)/kernel.map $(BUILD_FOLDER)/isofiles/boot
	grub-mkrescue -o $(BUILD_FOLDER)/$(ISO_IMAGE_FILENAME) $(BUILD_FOLDER)/isofiles

$(BUILD_FOLDER)/%.o: src/%.s
	echo "$(<D)"
	mkdir -p "$(@D)"
	${ASM_COMPILER} ${ASM_FLAGS} "$<" -o "$@"

$(BUILD_FOLDER)/%.o: src/%.c
	echo "$(@D)"
	mkdir -p "$(@D)"
	$(X_CC) ${CFLAGS} -DIS_WORKFLOW=$(IS_WORKFLOW) -c "$<" -o "$@"

$(BUILD_FOLDER)/%.o: $(FONT_FOLDER)/%.psf
	echo "PSF: $(@D)"
	mkdir -p "$(@D)"
	objcopy -O elf64-x86-64 -B i386 -I binary "$<" "$@"

$(BUILD_FOLDER)/kernel.bin: $(OBJ_ASM_FILE) $(OBJ_C_FILE) $(OBJ_FONT_FILE) src/linker.ld
	echo $(OBJ_ASM_FILE)
	echo $(OBJ_FONT_FILE)
	echo $(IS_WORKFLOW)
	$(X_LD) $(LD_FLAGS)  -n -o $(BUILD_FOLDER)/kernel.bin -T src/linker.ld $(OBJ_ASM_FILE) $(OBJ_C_FILE) $(OBJ_FONT_FILE) -Map $(BUILD_FOLDER)/kernel.map

gdb: DEBUG=1
gdb: CFLAGS += $(C_DEBUG_FLAGS)
gdb: ASM_FLAGS += $(ASM_DEBUG_FLAGS)
gdb: $(BUILD_FOLDER)/$(ISO_IMAGE_FILENAME)
	$(QEMU_SYSTEM) -cdrom $(BUILD_FOLDER)/$(ISO_IMAGE_FILENAME) -monitor unix:qemu-monitor-socket,server,nowait -serial file:dreamos64.log -m 1G -d int -no-reboot -no-shutdown -s -S

