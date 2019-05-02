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
ifeq ($(TARGET),iotlab-a8-m3)
	NATIVE = iotlab-a8
else
	NATIVE = localhost
endif

# Command dependencies for running makefile
COMMANDS += openssl wget git


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
	$(Q) TARGET=iotlab-a8-m3 $(MAKE) -C $(dir $(SLIP_RADIO)) clean
	$(Q) TARGET=native $(MAKE) -C $(dir $(SLIP_BRIDGE)) clean

.PHONY: distclean
distclean:
	@echo "Clean tools"
	$(Q) TARGET=iotlab-a8-m3 $(MAKE) -C $(dir $(SLIP_RADIO)) distclean
	$(Q) TARGET=native $(MAKE) -C $(dir $(SLIP_BRIDGE)) distclean
	@echo "Clean files in bin directory"
	$(Q) rm $(BIN)/*

$(SLIP_RADIO): $(CONTIKI)
	$(Q) $(MAKE) -C $(dir $@)

$(BIN)/slip-radio.$(TARGET): $(BIN) $(SLIP_RADIO)
	$(Q) cp $(SLIP_RADIO) $(BIN)

.PHONY: slip-radio
slip-radio: export TARGET=iotlab-a8-m3
slip-radio: $(BIN)/slip-radio.$(TARGET)

$(SLIP_BRIDGE): $(CONTIKI)
	$(Q) $(MAKE) -C $(dir $@)

$(BIN)/slip-bridge.$(TARGET): $(BIN) $(SLIP_BRIDGE)
	$(Q) cp $(SLIP_BRIDGE) $(BIN)

.PHONY: slip-bridge
slip-bridge: export TARGET=native
slip-bridge: $(BIN)/slip-bridge.$(TARGET)

.PHONY: help
help:
	@echo "Provided targets"
	@echo "- contiki: get contiki operating system source files"
	@echo "- slip-radio: build slip radio for iotlab-a8-m3"
	@echo "- slip-bridge: build slip bridge for native target"


# TODO: Get and build nghttp for A8


include $(CURDIR)/Makefile.include
