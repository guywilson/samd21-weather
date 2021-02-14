###############################################################################
#                                                                             #
# MAKEFILE for SAMD21 based weather station, uses the real-time scheduler     #
# from https:/github.com/guywilson/RTScheduler.git.                           #
# Runs on an Arduino MKR-WAN1310                                              #
#                                                                             #
# Guy Wilson (c) 2021                                                         #
#                                                                             #
###############################################################################

PROJNAME = weather

# Target device
DEVICE = cortex-m0plus

# What is our target
ELF = $(PROJNAME).elf
HEX = $(PROJNAME).hex
TARGET = $(PROJNAME).bin

# Build output directory
BUILD = build

# Source directory
SRC = src

# Dependency directory
DEP = dep

# Arduino base directory
ARDUINOBASE = /Users/guy/Library/Arduino15/packages/arduino
CMSISBASE = $(ARDUINOBASE)/tools/CMSIS
SAMDBASE = $(ARDUINOBASE)/hardware/samd/1.8.11

# Port we use to upload the target to the device
UPLOADPORT = /dev/cu.usbmodem101

# Tools
CC=arm-none-eabi-gcc
LINKER=arm-none-eabi-g++
OBJCOPY=arm-none-eabi-objcopy
OBJDUMP=arm-none-eabi-objdump
SIZETOOL=arm-none-eabi-size
UPLOADTOOL=$(ARDUINOBASE)/tools/bossac/1.7.0-arduino3/bossac

# Pre/Post compile steps
PRECOMPILE = @ mkdir -p $(BUILD) $(DEP)
POSTCOMPILE = @ mv -f $(DEP)/$*.Td $(DEP)/$*.d

# Upload flags
UPLOADFLAGS=-i -d -e -w -v -R -p

# Include dir flags
INCLUDEFLAGS=-I/Users/guy/development/RTScheduler/sched/samd21/src -I$(CMSISBASE)/4.5.0/CMSIS/Include/ -I$(ARDUINOBASE)/tools/CMSIS-Atmel/1.2.0/CMSIS/Device/ATMEL/ -I$(ARDUINOBASE)/tools/CMSIS-Atmel/1.2.0/CMSIS/Device/ATMEL/samd21/include/ -I$(SAMDBASE)/cores/arduino/api/deprecated -I$(SAMDBASE)/cores/arduino/api/deprecated-avr-comp -I$(SAMDBASE)/cores/arduino -I$(SAMDBASE)/variants/mkrwan1300

# Library paths
LIBDIRS=-L$(CMSISBASE)/4.5.0/CMSIS/Lib/GCC -L/Users/guy/development/arduino-core/samd21/lib -L/Users/guy/development/RTScheduler/sched/samd21/lib

# External Libraries
EXTLIBS=-larm_cortexM0l_math -lcore-samd21 -lsched

# Flags
CFLAGS=-c -mcpu=$(DEVICE) -mthumb -Wall -std=c99 -ffunction-sections -fdata-sections -nostdlib --param max-inline-insns-single=500 -DF_CPU=48000000L -DARDUINO=10813 -DARDUINO_SAMD_MKRWAN1310 -DARDUINO_ARCH_SAMD -DUSE_ARDUINO_MKR_PIN_LAYOUT -D__SAMD21G18A__ -DUSE_BQ24195L_PMIC -DVERY_LOW_POWER
DEPFLAGS = -MT $@ -MMD -MP -MF $(DEP)/$*.Td
LFLAGS=-Wl,--gc-sections -T$(SAMDBASE)/variants/mkrwan1300/linker_scripts/gcc/flash_with_bootloader.ld --specs=nano.specs --specs=nosys.specs -mcpu=cortex-m0plus -mthumb $(LIBDIRS) -Wl,--check-sections -Wl,--gc-sections -Wl,--warn-common -Wl,--warn-section-align
OBJCOPYFLAGS=-O ihex -R .eeprom
OBJDUMPFLAGS=-I $(SRC) -f -s -l -S
SFLAGS=-A

CSRCFILES = $(wildcard $(SRC)/*.c)
DEPFILES = $(patsubst $(SRC)/%.c, $(DEP)/%.d, $(CSRCFILES))
OBJFILES := $(patsubst $(SRC)/%.c, $(BUILD)/%.o, $(CSRCFILES))

COMPILE.c = $(CC) $(CFLAGS) $(INCLUDEFLAGS) $(DEPFLAGS) -o $@
LINK.o = $(LINKER) $(LFLAGS) -o $@

# Target
all: $(TARGET)

###############################################################################
#
# Project files
#
###############################################################################
$(TARGET): $(BUILD)/$(ELF)
	$(OBJCOPY) $(OBJCOPYFLAGS) $(BUILD)/$(ELF) $(HEX)
	$(OBJCOPY) -O binary $(BUILD)/$(ELF) $(TARGET)
	$(SIZETOOL) $(SFLAGS) $(BUILD)/$(ELF)

$(BUILD)/$(ELF): $(OBJFILES)
	$(LINK.o) $^ -Wl,--start-group -lm $(EXTLIBS) -Wl,--end-group
	$(OBJDUMP) $(OBJDUMPFLAGS) $(BUILD)/$(ELF) > $(PROJNAME).s

$(BUILD)/%.o: $(SRC)/%.c
$(BUILD)/%.o: $(SRC)/%.c $(DEP)/%.d
	$(PRECOMPILE)
	$(COMPILE.c) $<
	$(POSTCOMPILE)

.PRECIOUS = $(DEP)/%.d
$(DEP)/%.d: ;

-include $(DEPFILES)

###############################################################################
#
# Upload to the device, use 'make install' to envoke
#
###############################################################################
install: $(TARGET)
	stty 1200 < $(UPLOADPORT)
	sleep 1
	$(UPLOADTOOL) $(UPLOADFLAGS) $(UPLOADPORT) $(TARGET)
	
clean: 
	rm $(BUILD)/*
	rm $(PROJNAME).s
	rm $(HEX)
	rm $(TARGET)
