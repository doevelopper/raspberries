################################################################################
#
# rpi-eeprom
#
################################################################################

RPI_EEPROM_VERSION = b57586ead2576f1b36e69bb5625e531d14767eb2
RPI_EEPROM_SITE = $(call github,raspberrypi,rpi-eeprom,$(RPI_EEPROM_VERSION))
RPI_EEPROM_LICENSE = BSD-3-Clause
RPI_EEPROM_LICENSE_FILES = LICENCE
RPI_EEPROM_INSTALL_STAGING = YES

define RPI_EEPROM_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0544 $(@D)/rpi-eeprom-update-default $(TARGET_DIR)/etc/default/rpi-eeprom-update
	$(INSTALL) -D -m 0755 $(@D)/rpi-eeprom-config $(TARGET_DIR)/usr/bin
	$(INSTALL) -D -m 0755 $(@D)/rpi-eeprom-digest $(TARGET_DIR)/usr/bin
	$(INSTALL) -D -m 0755 $(@D)/rpi-eeprom-update $(TARGET_DIR)/usr/bin
endef

ifeq ($(BR2_PACKAGE_RECALBOX_TARGET_RPI5_64),y)
RPI_EEPROM_INSTALL_TARGET_CMDS += && $(INSTALL) -d $(TARGET_DIR)/lib/firmware/raspberrypi/bootloader/ && cp -r $(@D)/firmware-2712/* $(TARGET_DIR)/lib/firmware/raspberrypi/bootloader/
endif

ifeq ($(BR2_PACKAGE_RECALBOX_TARGET_RPI4_64),y)
RPI_EEPROM_INSTALL_TARGET_CMDS += && $(INSTALL) -d $(TARGET_DIR)/lib/firmware/raspberrypi/bootloader/ && cp -r $(@D)/firmware-2711/* $(TARGET_DIR)/lib/firmware/raspberrypi/bootloader/
endif

$(eval $(generic-package))
