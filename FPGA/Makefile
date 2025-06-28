# Clavier | Makefile
# Copyright (c) 2025 L. Sartory
# SPDX-License-Identifier: MIT

PACKAGE = CABGA256
SIZE    = 25k
SPEED   = 6

BUILDDIR = build
TOPLEVEL = Clavier

LPFFILE  = Clavier.lpf
PREPACK  = Clavier.py
SOURCES  = Clavier.vhd
SOURCES += ClockScaler.vhd
SOURCES += PLL.vhd
SOURCES += VectorCDC.vhd
SOURCES += usb/USB_Debug_UART.vhd
SOURCES += usb/USB_Descriptors.vhd
SOURCES += usb/USB_Device.vhd
SOURCES += usb/USB_EndPoint0.vhd
SOURCES += usb/USB_PHY.vhd
SOURCES += usb/USB_Types.vhd
SOURCES += usb/class/USB_Class_Descriptors.vhd
SOURCES += usb/class/USB_HID.vhd


.PHONY: all
all: $(BUILDDIR)/$(TOPLEVEL).bit

$(BUILDDIR)/work-obj93.cf: $(SOURCES)
	mkdir -p $(BUILDDIR)
	ghdl import --workdir=$(BUILDDIR) $^
	ghdl make   --workdir=$(BUILDDIR) -P$(BUILDDIR) -f -Wall -Wno-default-binding -Wno-binding -Werror -O2 -o $(BUILDDIR)/$(TOPLEVEL) $(TOPLEVEL)

$(BUILDDIR)/$(TOPLEVEL).json: $(BUILDDIR)/work-obj93.cf
	yosys -t -m ghdl -p 'ghdl -Wall --workdir=$(BUILDDIR) -P$(BUILDDIR) $(TOPLEVEL); stat; synth_ecp5 -iopad -json $@' -l $(BUILDDIR)/yosys.rpt

$(BUILDDIR)/$(TOPLEVEL).config: $(BUILDDIR)/$(TOPLEVEL).json
	nextpnr-ecp5 --package $(PACKAGE) --$(SIZE) --speed $(SPEED) --pre-pack $(PREPACK) --lpf $(LPFFILE) --json $< --textcfg $@ -l $(BUILDDIR)/nextpnr.rpt

$(BUILDDIR)/$(TOPLEVEL).bit: $(BUILDDIR)/$(TOPLEVEL).config
	ecppack $< $@

.PHONY: prog-sram
prog-sram: $(BUILDDIR)/$(TOPLEVEL).bit
	openFPGALoader $<

.PHONY: prog-flash
prog-flash: $(BUILDDIR)/$(TOPLEVEL).bit
	openFPGALoader -f $<

.PHONY: clean
clean:
	rm -rf $(BUILDDIR)
