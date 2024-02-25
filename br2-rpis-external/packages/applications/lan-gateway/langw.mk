################################################################################
#
# hmlangw - http://homematic-forum.de/forum/viewtopic.php?f=18&t=27705
#
################################################################################

LANGW_VERSION = 0.0.1
LANGW_SITE = $(BR2_EXTERNAL_CFSOS_PATH)/package/applications/lan-gateway
LANGW_SITE_METHOD = local
LANGW_LICENSE = MIT
LANGW_LICENSE_FILES = LICENSE

define LANGW_BUILD_CMDS
	$(MAKE) CXX="$(TARGET_CXX)" LD="$(TARGET_LD)" CXXFLAGS="$(TARGET_CXXFLAGS)" -C $(@D) all
endef

define LANGW_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/hmlangw $(TARGET_DIR)/bin
endef

define LANGW_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 0755 $(LANGW_PKGDIR)/S61hmlangw \
		$(TARGET_DIR)/etc/init.d/S61hmlangw
endef

$(eval $(generic-package))