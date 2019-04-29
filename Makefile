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

#######################################################################
# Make environment variables
#######################################################################

# Make all paths absolute.
override BIN	:= $(abspath $(BIN))
override BUILD	:= $(abspath $(BUILD))
override TOOLS  := $(abspath $(TOOLS))

SHELL=bash

# get host operating system
OS := $(shell uname -s)

# git command
GIT ?= git

# Command dependencies for running makefile
COMMANDS += openssl wget git

# Quiet option, to output compile and link commands
QUIET ?= 1
ifeq ($(QUIET),1)
  Q=@
  MAKEFLAGS += --no-print-directory
else
  Q=
endif


#######################################################################
# Begin targets
#######################################################################

# Include iot-lab targets
include $(CURDIR)/Makefile.iotlab

# Check command dependencies
.PHONY = $(COMMANDS)
$(COMMANDS):
	$(if $(shell which $@),,$(error "No $@ in PATH"))

IOTLAB_BASE_DIR  = A8
IOTLAB_BUILD_DIR = $(IOTLAB_BASE_DIR)/$(notdir $(CURDIR))

# Where is the build running
ifeq ($(shell hostname),$(IOTLAB_SITE))
	LOCAL_ENV = site
else
ifeq ($(shell hostname),node-a8-$(IOTLAB_SERVER_NODE))
	LOCAL_ENV = node
else
	LOCAL_ENV = local
endif
endif

# Where should the build run
ifeq ($(NATIVE),iotlab-a8)
	TARGET_ENV = site
else
	TARGET_ENV = local
endif

# If build should run on iotlab site, rsync and ssh
ifeq ($(LOCAL_ENV)-$(TARGET_ENV),local-site)
.DEFAULT:
	@echo "Syncing files with IoT-Lab site"
	$(Q)$(call IOTLAB_SITE_RSYNC,$(CURDIR),$(IOTLAB_BASE_DIR),--exclude='.git' --exclude-from='.gitignore')
	@echo "Calling make on IoT-Lab site"
	$(Q)$(call IOTLAB_SITE_SSH,$(IOTLAB_BUILD_DIR), make $@) # call same  make target in remote dir
else # local env == target env
include $(CURDIR)/Makefile.build
endif # TARGET


.DEFAULT_GOAL: all
