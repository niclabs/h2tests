#######################################################################
# Local build configuration
#######################################################################

# Set local variables to the value of RUNTIME variables (prefixed with R_)
# this is useful to define variables that must be passed to target build environment
$(foreach v, $(filter R_%,$(.VARIABLES)),$(eval $(subst R_,,$(v)=$($(v)))))

# Configure iot-lab experiment parameters
IOTLAB_SITE ?= grenoble
IOTLAB_ARCHI ?= a8:at86rf231
IOTLAB_DURATION ?= 720
IOTLAB_SERVER_NODE ?= 1
IOTLAB_CLIENT_NODES ?= 2
IOTLAB_RESOURCES ?= $(IOTLAB_SERVER_NODE)+$(IOTLAB_CLIENT_NODES)
IOTLAB_NAME ?= h2
IOTLAB_PROFILE ?= battery_a8

# Name for the server certificate and private key for nghttp
SERVER_CERT ?= $(BIN)/server.crt
SERVER_KEY	?= $(BIN)/server.key

# nghttp2 configuration
NGHTTP2_VERSION 	?= 1.34.0
NGHTTP2  			?= $(BUILD)/nghttp2-$(NGHTTP2_VERSION)

#http parameters
HTTP_PORT 					?= 80

# Build directories
BIN   	?= $(CURDIR)/bin
BUILD 	?= $(CURDIR)/build
TOOLS 	?= $(CURDIR)/tools
SCRIPTS ?= $(CURDIR)/scripts
WWW   	?= $(BUILD)/www/

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
COMMANDS += openssl wget git patch

TTY ?= $(if $(shell test $(BUILD_ENV) = iotlab-node && echo true),/dev/ttyA8_M3)
IPV6_ADDR  ?= 2001:dead:beef::1
IPV6_PREFIX = $(IPV6_ADDR)/64

#######################################################################
# Begin targets
#######################################################################

# Include remote targets
include $(CURDIR)/Makefile.include

# Create build directories
ALLDIRS := $(BUILD) $(BIN) $(WWW)

$(ALLDIRS):
	@echo "Creating $@"
	@mkdir -p $@

# Create server certificate
$(SERVER_KEY) $(SERVER_CERT): | openssl
	openssl req -new -newkey rsa:2048 -sha256 -days 365 -nodes -x509 -keyout $(SERVER_KEY) -out $(SERVER_CERT) -subj '/CN=$(IPV6_ADDR)'

.PHONY: generate-keys
generate-keys: $(SERVER_KEY) $(SERVER_CERT)

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

.PHONY: get-contiki
get-contiki: $(CONTIKI)

$(NGHTTP2)/configure: | $(BUILD)
$(NGHTTP2)/configure: | wget
$(NGHTTP2)/configure: | patch
	@echo "Get nghttp2 source"
	$(Q) cd $(BUILD) && \
	   	wget -qO - https://github.com/nghttp2/nghttp2/releases/download/v$(NGHTTP2_VERSION)/nghttp2-$(NGHTTP2_VERSION).tar.gz | gunzip -c - | tar xvf -
	@echo "Apply settings patch"
	$(Q) cd $(NGHTTP2) && patch -p1 < $(TOOLS)/nghttp2-settings.patch

$(NGHTTP2)/Makefile: $(NGHTTP2)/configure
	@echo "Configure nghttp2"
	$(Q)cd $(NGHTTP2) && \
		./configure --prefix=$(BIN) --bindir=$(BIN) --mandir=/tmp --docdir=/tmp --enable-app --disable-hpack-tools --disable-examples --disable-python-bindings --disable-threads

# Build nghttp2 tools
$(BIN)/nghttpd $(BIN)/h2load: $(NGHTTP2)/Makefile | $(BIN)
	@echo "Build nghttp2"
	$(Q) $(MAKE) -C $(NGHTTP2)
	@echo "Install nghttp2"
	$(Q) $(MAKE) -C $(NGHTTP2) install

.PHONY: build-nghttp2
build-nghttp2: $(BIN)/nghttpd $(BIN)/h2load

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

.PHONY: slip-router
slip-router: $(BIN)/slip-bridge.native
	$(Q) $< $(if $(VERBOSE),-v2 -L) -s $(TTY) -r $(IPV6_PREFIX) -B 500000

.PHONY: slip-bridge
slip-bridge: $(BIN)/slip-bridge.native
	$(Q) $< $(if $(VERBOSE),-v2 -L) -s $(TTY) -B 500000

.PHONY: help
help:
	@echo "Provided targets"
	@echo "- generate-keys: generate self-signed keys for running nghttp2"
	@echo "- get-contiki: download contiki operating system source files"
	@echo "- build-nghttp2: get and build nghttp2 1.34.0"
	@echo "- build-slip-radio: build slip radio for target node"
	@echo "- flash-slip-radio: flash slip radio firmware on target node"
	@echo "- build-slip-bridge: build slip bridge for native target"
	@echo "- slip-bridge: run slip bridge"
	@echo "- slip-router: run slip bridge as 6lowpan border router"

.PHONY: flash-slip-radio
flash-slip-radio: $(BIN)/slip-radio.$(TARGET)
ifeq ($(BUILD_ENV),iotlab-node)
	$(Q) flash_a8_m3 $<
endif
