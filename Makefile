#######################################################################
# Local build configuration
#######################################################################

# Configure iot-lab experiment parameters
IOTLAB_ARCHI ?= a8:at86rf231
IOTLAB_DURATION ?= 180
IOTLAB_SERVER_NODE ?= 1
IOTLAB_CLIENT_NODES ?= 2
IOTLAB_RESOURCES = $(IOTLAB_SERVER_NODE)+$(IOTLAB_CLIENT_NODES)
IOTLAB_NAME ?= h2

# Name for the server certificate and private key for nghttp
SERVER_CERT ?= server.crt
SERVER_KEY	?= server.key

# Build directories
BIN   ?= $(CURDIR)/bin
BUILD ?= $(CURDIR)/build
TOOLS ?= $(CURDIR)/tools

# Build targets
CONTIKI  ?= $(BUILD)/contiki
OPENLAB  ?= $(BUILD)/openlab
SLIP_RADIO 	?= $(TOOLS)/slip-radio/slip-radio.$(TARGET)
SLIP_BRIDGE ?= $(TOOLS)/slip-bridge/slip-bridge.$(TARGET)

# Target board where slip-radio will be run
TARGET	?= iotlab-a8-m3

# Change to show build commands
QUIET ?= 1

# Command dependencies for running makefile
COMMANDS += openssl wget git

TTY ?= $(if $(shell test $(BUILD_ENV) = iotlab-a8 && echo true),/dev/ttyA8_M3)
IPV6_ADDR 	= 2001:dead:beef::1
IPV6_PREFIX = $(IPV6_ADDR)/64


#######################################################################
# Begin targets
#######################################################################

# Create build directories
ALLDIRS := $(BUILD) $(BIN)

$(ALLDIRS):
	@echo "Creating $@"
	@mkdir -p $@

# Create server certificate
server.crt: | openssl
	openssl req -new -newkey rsa:2048 -sha256 -days 365 -nodes -x509 -keyout $(SERVER_KEY) -out $(SERVER_CERT)

$(CONTIKI): $(OPENLAB)
	@echo "Get contiki for iot-lab"
	$(Q) $(GIT) clone https://github.com/iot-lab/contiki.git $@
	@echo "Get and merge with main contiki branch"
	$(Q) cd $@ && \
	   	$(GIT) remote add contiki https://github.com/contiki-os/contiki.git && \
		$(GIT) fetch contiki && \
		$(GIT) merge --no-edit contiki/master

$(OPENLAB): | $(BUILD)
$(OPENLAB): | git
	@echo "Get openlab repository"
	$(Q) $(GIT) clone https://github.com/iot-lab/openlab.git $@

.PHONY: contiki
contiki: $(CONTIKI)

.PHONY: clean
clean:
	@echo "Clean tools"
	$(Q) TARGET=iotlab-a8-m3 $(MAKE) -C $(dir $(SLIP_RADIO)) distclean
	$(Q) TARGET=native $(MAKE) -C $(dir $(SLIP_BRIDGE)) distclean

.PHONY: clean-build
clean-build: clean
	@echo "Clean build files"
	$(Q) rm -rf $(BUILD)

.PHONY: clean-all
clean-all: clean-build
	@echo "Clean files in bin directory"
	$(Q) rm -rf $(BIN)


$(SLIP_RADIO): $(CONTIKI) $(TOOLS)/slip-radio/*.c $(TOOLS)/slip-radio/*.h $(TOOLS)/slip-radio/Makefile
	$(Q) $(MAKE) -C $(dir $@)

$(BIN)/slip-radio.$(TARGET): $(BIN) $(SLIP_RADIO)
	$(Q) cp $(SLIP_RADIO) $(BIN)

.PHONY: build-slip-radio
build-slip-radio: export TARGET=iotlab-a8-m3
build-slip-radio: $(BIN)/slip-radio.$(TARGET)

$(SLIP_BRIDGE): $(CONTIKI) $(TOOLS)/slip-bridge/*.c $(TOOLS)/slip-bridge/*.h $(TOOLS)/slip-bridge/Makefile
	$(Q) $(MAKE) -C $(dir $@)

$(BIN)/slip-bridge.$(TARGET): $(BIN) $(SLIP_BRIDGE)
	$(Q) cp $(SLIP_BRIDGE) $(BIN)

.PHONY: build-slip-bridge
build-slip-bridge: export TARGET=native
build-slip-bridge: $(BIN)/slip-bridge.$(TARGET)

.PHONY: run-slip-router
run-slip-router: $(BIN)/slip-bridge.native
	$(Q) $< -v2 -L -s $(TTY) -r $(IPV6_PREFIX) -B 500000

.PHONY: run-slip-bridge
run-slip-bridge: $(BIN)/slip-bridge.native
	$(Q) $< -v2 -L -s $(TTY) -B 500000

.PHONY: help
help:
	@echo "Provided targets"
	@echo "- contiki: get contiki operating system source files"
	@echo "- build-slip-radio: build slip radio for target node"
	@echo "- flash-slip-radio: flash slip radio firmware on target node"
	@echo "- build-slip-bridge: build slip bridge for native target"
	@echo "- run-slip-bridge: run slip bridge"
	@echo "- run-slip-router: run slip bridge as 6lowpan border router"


# TODO: Get and build nghttp for A8

# Include remote targets
include $(CURDIR)/Makefile.include

#######################################################################
# Build environment dependent targets
#######################################################################

.PHONY: flash-slip-radio
flash-slip-radio: $(BIN)/slip-radio.$(TARGET)
ifeq ($(BUILD_ENV),iotlab-node)
	$(Q) flash_a8_m3 $<
endif
