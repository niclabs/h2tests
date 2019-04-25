CONTIKI_PROJECT=slip-bridge
all: $(CONTIKI_PROJECT)
APPS = slip-cmd

CONTIKI ?= $(CURDIR)/../../deps/contiki

#linker optimizations
SMALL=1

CFLAGS += -DPROJECT_CONF_H=\"project-conf.h\"
PROJECT_SOURCEFILES += slip-bridge-cmds.c tun-bridge.c slip-bridge-rdc.c \
slip-config.c slip-dev.c

WITH_WEBSERVER=1
ifeq ($(WITH_WEBSERVER),1)
CFLAGS += -DWEBSERVER=1
PROJECT_SOURCEFILES += httpd-simple.c
else ifneq ($(WITH_WEBSERVER), 0)
APPS += $(WITH_WEBSERVER)
CFLAGS += -DWEBSERVER=2
endif

CONTIKI_WITH_IPV6 = 1
include $(CONTIKI)/Makefile.include

connect-router:	slip-bridge.native
	sudo ./slip-bridge.native fd00::1/64
