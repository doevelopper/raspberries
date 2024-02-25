################################################################################
#
# roughtime
#
################################################################################

ROUGHTIME_VERSION = 2.7.1
ROUGHTIME_SITE = https://roughtime.googlesource.com/roughtime
ROUGHTIME_SOURCE = roughtime-$(ROUGHTIME_VERSION).tar.gz
ROUGHTIME_LICENSE = GPL-2.0+
ROUGHTIME_LICENSE_FILES = COPYING
ROUGHTIME_CPE_ID_VENDOR = googlesource
ROUGHTIME_DEPENDENCIES = ncurses zlib

ROUGHTIME_CFLAGS = $(TARGET_CFLAGS)

ifeq ($(BR2_TOOLCHAIN_HAS_GCC_BUG_85180),y)
ROUGHTIME_CFLAGS += -O0
endif

define ROUGHTIME_BUILD_CMDS
	$(MAKE) $(TARGET_CONFIGURE_OPTS) CFLAGS="$(ROUGHTIME_CFLAGS)" \
		-C $(@D)
endef

define ROUGHTIME_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/roughtime $(TARGET_DIR)/usr/bin/roughtime
endef

$(eval $(generic-package))
