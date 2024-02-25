################################################################################
#
# tlsdate
#
################################################################################

TLSDATE_VERSION = 0.0.13
TLSDATE_SITE = https://github.com/ioerror/tlsdate/tags
TLSDATE_SOURCE = tlsdate-$(TLSDATE_VERSION).tar.gz
TLSDATE_LICENSE = GPL-2.0+
TLSDATE_LICENSE_FILES = COPYING
TLSDATE_CPE_ID_VENDOR = tlsdate_project
TLSDATE_DEPENDENCIES = ncurses zlib

TLSDATE_CFLAGS = $(TARGET_CFLAGS)

ifeq ($(BR2_TOOLCHAIN_HAS_GCC_BUG_85180),y)
TLSDATE_CFLAGS += -O0
endif

define TLSDATE_BUILD_CMDS
	$(MAKE) $(TARGET_CONFIGURE_OPTS) CFLAGS="$(TLSDATE_CFLAGS)" \
		-C $(@D)
endef

define TLSDATE_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/tlsdate $(TARGET_DIR)/usr/bin/tlsdate
endef

$(eval $(generic-package))
