#
# Copyright (c) 2022-2024, ACME AHL Limited and Contributors. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

#             __|__
#      --@--@--(_)--@--@--

.DEFAULT_GOAL:=help
#
# Project Makefile
#
##################################################################################################################################
# Courtesy to 
#   https://github.com/fhunleth/bbb-buildroot-fwup/blob/master/Makefile
#   https://github.com/RosePointNav/nerves-sdk/blob/master/Makefile
#   https://github.com/jens-maus/RaspberryMatic/blob/master/Makefile
#   wget https://git.busybox.net/buildroot/plain/configs/raspberrypi3_64_defconfig
#   grep -inRsH "BR2_TARGET_UBOOT\|BR2_PACKAGE_HOST_UBOOT" /<path>/buildroot/configs/
##################################################################################################################################

MAKE_HELPERS_DIRECTORY := helpers/

ROOT			       := $(dir $(abspath $(firstword $(MAKEFILE_LIST))))

define receipe
	make -C "$(OUTPUT)/buildroot" BR2_EXTERNAL="$(ROOT)" O="$(OUTPUT)" $(1)
endef

# .PHONY: buildroot-menuconfig
# buildroot-menuconfig: prepare
# 	$(call buildroot,menuconfig)
# 	$(call buildroot,savedefconfig)


include ${MAKE_HELPERS_DIRECTORY}define.mk
include ${MAKE_HELPERS_DIRECTORY}macros.mk

.NOTPARALLEL: $(SUPPORTED_TARGETS) $(TARGETS_CONFIG) all

# # ####################################################################################################
# # #
# # #				Buildroot RT Infrastructure setup
# # #
# # ####################################################################################################


$(BLRT_PACKAGE_DIR)/buildroot-$(BLRT_VERSION).tar.gz.sign:
	$(Q)$(call MESSAGE,"BLRT [Downloading signature $@ ]")
	$(Q)mkdir -pv $(BLRT_PACKAGE_DIR)
	$(Q)mkdir -pv $(BLRT_ARTIFACTS_DIR)
	curl --output $@ https://buildroot.org/downloads/buildroot-$(BLRT_VERSION).tar.gz.sign

$(BLRT_PACKAGE_DIR)/buildroot-$(BLRT_VERSION).tar.gz: | $(BLRT_PACKAGE_DIR)/buildroot-$(BLRT_VERSION).tar.gz.sign
	$(Q)$(call MESSAGE,"BLRT [Downloading build tool $@ ]")
	$(Q)curl --output $@ https://buildroot.org/downloads/buildroot-$(BLRT_VERSION).tar.gz

$(BLRT_PACKAGE_DIR)/buildroot-$(BLRT_VERSION): | $(BLRT_PACKAGE_DIR)/buildroot-$(BLRT_VERSION).tar.gz
#	$(Q)$(CMD_PREFIX)$(call MESSAGE,"BLRT [Cloning latest buildroot as buildroot-$(BLRT_VERSION)] $@ ")
#	$(Q)git clone https://github.com/buildroot/buildroot.git $@
# if [ ! -d $@ ]; then
#   git clone -b $BUILDROOT_VERSION https://github.com/buildroot/buildroot.git $@ --depth 1
# fi
	$(Q)$(CMD_PREFIX)$(call MESSAGE,"BLRT [Extracting buildroot-$(BLRT_VERSION)] $@ ")
	$(Q)cd $(BLRT_PACKAGE_DIR) && if [ ! -d $@ ]; then tar xf $(BLRT_PACKAGE_DIR)/buildroot-$(BLRT_VERSION).tar.gz; fi

$(BLRT_PACKAGE_DIR)/.buildroot-downloaded: $(BLRT_PACKAGE_DIR)/buildroot-$(BLRT_VERSION)
	$(Q)$(call MESSAGE,"BLRT [Caching downloaded files in $(BLRT_DL_DIR).]")
	$(Q)touch $@

## useful to patch version of package to be downloaded...  this patch preceed <package>-patch ....
$(BLRT_PACKAGE_DIR)/.buildroot-patched: $(BLRT_PACKAGE_DIR)/.buildroot-downloaded
	$(Q)$(call MESSAGE,"BLRT [Patching buildroot-$(BLRT_VERSION)]")
	$(Q)for p in $(sort $(wildcard buildroot-patches/*.patch)); do \
		echo "Applying $${p}"; \
		patch -d $(BLRT_PACKAGE_DIR)/buildroot-$(BLRT_VERSION) --remove-empty-files -p1 < $${p} || exit 237; \
		[ ! -x $${p%.*}.sh ] || $${p%.*}.sh $(BLRT_PACKAGE_DIR)/buildroot-$(BLRT_VERSION); \
	done;
	$(Q)touch $@

$(BLRT_PACKAGE_DIR)/.others-patched: $(BLRT_PACKAGE_DIR)/.buildroot-patched
	$(Q)$(call MESSAGE,"BLRT [Apply our patches that either haven't been submitted or merged upstream in buildroot-$(BLRT_VERSION)] packages")
#	$(BLRT_DIR)/support/scripts/apply-patches.sh $(BLRT_OOSB)/buildroot-$(BLRT_VERSION) $(BLRT_EXT)/patches/buildroot || exit 1
	$(Q)touch $@

# # # ####################################################################################################
# # # #
# # # #								Goals declaration
# # # #
# # # ####################################################################################################

.PHONY: $(CFSOS_GOALD)

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-configure): %-configure: $(BLRT_PACKAGE_DIR)/.others-patched
	$(Q)$(call MESSAGE,"[  Generating configuration for $*]")
	$(Q)$(BLRT_MAKE) $(BLRT_MAKEARGS)  O=$(BLRT_OOSB)/$*-build-artifacts  $*_defconfig
#	$(Q)if [ ! -f $(BLRT_OOSB)/$*-build-artifacts/.config ] then; \
# 			$(MAKE) $(BLRT_MAKEARGS) O=$(BLRT_OOSB)/$*-build-artifacts  $*_defconfig \
# 		else \
# 			$(call MESSAGE,"BLRT [configuration for $* alredy done]") \
#		fi

# 2>&1 | tee $(BLRT_OOSB)/$*-build-artifacts/$(DATE)_buildroot_$@_output.log

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-compile): %-compile:
	$(Q)$(call MESSAGE,"[  Compiling artifacts for targets $*]")
	$(Q)$(BLRT_MAKE) $(BLRT_MAKEARGS)  O=$(BLRT_OOSB)/$*-build-artifacts
	$(Q)mkdir -pv $(BLRT_ARTIFACTS_DIR)
	$(Q)$(call MESSAGE,"[ Copying artifacts to $(BLRT_ARTIFACTS_DIR)/$*]")
	$(Q)if [ -d $(BLRT_ARTIFACTS_DIR)/$* ]; then rm -Rf $(BLRT_ARTIFACTS_DIR)/$* && mkdir -pv $(BLRT_ARTIFACTS_DIR)/$*; fi
	$(Q)cp -R $(BLRT_OOSB)/$*-build-artifacts/images $(BLRT_ARTIFACTS_DIR)/$*
	$(Q)$(call MESSAGE,"[  Copying binaries to tftp server]")
	$(Q)rm -f /srv/tftp/*
	$(Q)cp -nu $(BLRT_OOSB)/$*-build-artifacts/images/u-boot.bin /srv/tftp/ 2>/dev/null || :
	$(Q)cp -nu $(BLRT_OOSB)/$*-build-artifacts/images/*.dtb /srv/tftp/
	$(Q)cp -nu $(BLRT_OOSB)/$*-build-artifacts/images/*mage /srv/tftp/
	$(Q)$(call MESSAGE,"[  Artifacts :]")
	$(Q)du -sch --time $(BLRT_OOSB)/$*-build-artifacts/images/*

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-unit-test): %-unit-test: %-compile
	$(Q)$(call MESSAGE,"[  Running Unit test for targets $*]")

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-integration-test): %-integration-test: %-unit-test
	$(Q)$(call MESSAGE,"[  Running Integration test for targets $* board]")

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-menuconfig): %-menuconfig:
	$(Q)$(call MESSAGE,"BLRT [Change buildroot configuration for $*]")
	$(Q)$(MAKE) $(BLRT_MAKEARGS)  O=$(BLRT_OOSB)/$*-build-artifacts $(subst $*-,,$@)
	$(Q)echo
	$(Q)echo "!!! Important !!!"
	$(Q)echo "1. $(DEFCONFIG_DIR_FULL)/$*_defconfig has $(TERM_RED) NOT/NIET/NADA $(TERM_RESET) been updated."
	$(Q)echo "   Changes will be lost if you run 'make distclean'."
	$(Q)echo "   Run $(TERM_BOLD) 'make $*-savedefconfig' $(TERM_RESET) to update."
	$(Q)echo "2. \e[7mERROR: Buildroot normally requires you to run 'make clean' and 'make' after \e[0m"
	$(Q)echo "   changing the configuration. You don't technically have to do this,"
	$(Q)echo "   but if you're new to Buildroot, it's best to be safe."

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-linux-menuconfig): %-linux-menuconfig:
# #	@if grep -q 'BR2_LINUX_KERNEL=y'
	$(Q)$(call MESSAGE,"[ Change the Linux kernel configuration.] $*")
	$(Q)$(MAKE) $(BLRT_MAKEARGS)  O=$(BLRT_OOSB)/$*-build-artifacts $(subst $*-,,$@)
	$(Q)$(MAKE) $(BLRT_MAKEARGS)  O=$(BLRT_OOSB)/$*-build-artifacts linux-savedefconfig
	$(Q)echo
	$(Q)echo Going to update your $(BR2_EXTERNAL_CFSOS_PATH)/board/$*/configs/linux.config. If you do not have one,
	$(Q)echo you will get an error shortly. You will then have to make one and update,
	$(Q)echo your buildroot configuration to use it.
	$(Q)echo
	$(Q)$(MAKE) $(BLRT_MAKEARGS)  O=$(BLRT_OOSB)/$*-build-artifacts linux-update-defconfig	


$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-linux-rebuild): %-linux-rebuild:
	$(Q)$(call MESSAGE,"BLRT [Rebuilding after $(call UC, $(word 1,$(subst -, ,$(subst $*-,,$@)))) $* configuration change!]")
	$(Q)$(MAKE) $(BLRT_MAKEARGS)  O=$(BLRT_OOSB)/$*-build-artifacts $(subst $*-,,$@)

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-uboot-menuconfig): %-uboot-menuconfig:
	$(Q)$(call MESSAGE,"[ Change the Bootloader configuration.] $*")
#	@if grep -q 'BR2_TARGET_UBOOT=y' $(BLRT_OOSB)/$*-build-artifacts/.config; then
	$(Q)$(MAKE) $(BLRT_MAKEARGS)  O=$(BLRT_OOSB)/$*-build-artifacts $(subst $*-,,$@)
	$(Q)$(MAKE) $(BLRT_MAKEARGS)  O=$(BLRT_OOSB)/$*-build-artifacts uboot-savedefconfig
	$(Q)echo
	$(Q)echo Going to update your $(BR2_EXTERNAL_CFSOS_PATH)/board/$*/configs/uboot.config. If you do not have one,
	$(Q)echo you will get an error shortly. You will then have to make one and update,
	$(Q)echo your buildroot configuration to use it.
	$(Q)$(MAKE) $(BLRT_MAKEARGS)  O=$(BLRT_OOSB)/$*-build-artifacts uboot-update-defconfig

#	else 
#		echo "--- (UBOOT not activated SKIPPING $@ ---" ;
#	fi

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-uboot-rebuild): %-uboot-rebuild:
	$(Q)$(call MESSAGE,"BLRT [Rebuilding after $(call UC, $(word 1,$(subst -, ,$(subst $*-,,$@)))) $* configuration change!]")
	$(Q)$(MAKE) $(BLRT_MAKEARGS)  O=$(BLRT_OOSB)/$*-build-artifacts $(subst $*-,,$@)

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-busybox-menuconfig): %-busybox-menuconfig:
	$(Q)$(call MESSAGE,"BLRT [Generating $(subst $*-,,$@) configuration for $*]")
	$(Q)$(call MESSAGE,"[ Change the Busybox configuration.] $*")
	$(Q)$(MAKE) $(BLRT_MAKEARGS)  O=$(BLRT_OOSB)/$*-build-artifacts $(subst $*-,,$@)
	$(Q)echo
	$(Q)echo Going to update your $(BR2_EXTERNAL_CFSOS_PATH)/board/$*/configs/busybox.config. If you do not have one,
	$(Q)echo you will get an error shortly. You will then have to make one and update,
	$(Q)echo your buildroot configuration to use it.
	$(Q)echo
	$(Q)$(MAKE) $(BLRT_MAKEARGS)  O=$(BLRT_OOSB)/$*-build-artifacts busybox-update-config

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-busybox-rebuild): %-busybox-rebuild:
	$(Q)$(call MESSAGE,"BLRT [Rebuilding after $(call UC, $(word 1,$(subst -, ,$(subst $*-,,$@)))) $* configuration change!]")
	$(Q)$(MAKE) $(BLRT_MAKEARGS)  O=$(BLRT_OOSB)/$*-build-artifacts $(subst $*-,,$@)

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-savedefconfig): %-savedefconfig:
	$(Q)$(call MESSAGE,"BLRT [Saving $*] default config")
	$(Q)$(MAKE) $(BLRT_MAKEARGS)  O=$(BLRT_OOSB)/$*-build-artifacts savedefconfig BR2_DEFCONFIG=$(DEFCONFIG_DIR_FULL)/$*_defconfig

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-release): %-release: %-integration-test
	$(Q)$(call MESSAGE,"[  Packaging $* board's artefacts]")

# ##################################################################################################################################
# #
# #                                     BR2 Clean goals
# #
# ##################################################################################################################################

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-clean): %-clean:
	$(Q)$(call MESSAGE,"[ Delete all files created by $*'s build]")
	$(Q)$(MAKE) $(BLRT_MAKEARGS)  O=$(BLRT_OOSB)/$*-build-artifacts $(subst $*-,,$@)

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-distclean): %-distclean:
	$(Q)$(call MESSAGE,"[ Delete all non-source files (including .config) of $*'s build]")
# # $(Q)$(MAKE) $(BLRT_MAKEARGS)  O=$(BLRT_OOSB)/$*-build-artifacts $(subst $*-,,$@)
# # $(Q)$(call MESSAGE,"BLRT [Re-generating configuration for $*]")
# # $(Q)$(MAKE) $(BLRT_MAKEARGS)  O=$(BLRT_OOSB)/$*-build-artifacts  $*_defconfig
	$(call SHELL_REMOVE_DIR,${BUILD_BASE})

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-realclean): %-realclean:
	$(Q)$(call MESSAGE,"[ Wiping everything ]")
	$(Q)rm -fr $(BLRT_OOSB)/$*-build-artifacts
	$(Q)rm -f br.log

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-package-clean): %-package-clean:
	$(Q)$(call MESSAGE,"[ Package clean $(BLRT_OOSB)/$*-build-artifacts]")
	$(if $(V), @echo " RM        $($(BLRT_OOSB)/$*-build-artifacts)/*.o")
	$(Q)find $($(BLRT_OOSB)/$*-build-artifacts) -type f -name "*.o" -exec rm -rf {} +
	$(if $(V), @echo " RM        $($(BLRT_OOSB)/$*-build-artifacts)/*.a")
	$(Q)find $($(BLRT_OOSB)/$*-build-artifacts) -type f -name "*.a" -exec rm -rf {} +
	$(if $(V), @echo " RM        $($(BLRT_OOSB)/$*-build-artifacts)/*.elf")
	$(Q)find $($(BLRT_OOSB)/$*-build-artifacts) -type f -name "*.elf" -exec rm -rf {} +
	$(if $(V), @echo " RM        $(build_d$(BLRT_OOSB)/$*-build-artifactsir)/*.bin")
	$(Q)find $($(BLRT_OOSB)/$*-build-artifacts) -type f -name "*.bin" -exec rm -rf {} +
	$(if $(V), @echo " RM        $($(BLRT_OOSB)/$*-build-artifacts)/*.dtb")
	$(Q)find $($(BLRT_OOSB)/$*-build-artifacts) -type f -name "*.dtb" -exec rm -rf {} +


# # ##################################################################################################################################
# # #
# # #                                     Artifact upload to targets
# # #
# # ##################################################################################################################################

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-upload): %-upload:
	$(Q)$(call MESSAGE,"[ Uploading $* s artifacts")
# @if grep -q 'BR2_PACKAGE_SWUPDATE=y' $(BLRT_OOSB)/$*-build-artifacts/.config; then \
#     echo "--- (swupdate) $* ---" ; \
# else \
#     echo "--- (skip swupdate) $* ---" ; \
# fi

$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-upgrade): %-upgrade:
	$(Q)$(MAKE) $(BLRT_MAKEARGS)  O=$(BLRT_OOSB)/$*-build-artifacts $(subst $*-,,$@)



$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-checksum): %-checksum:
	$(Q)$(call MESSAGE,"[ Generating $* artifacts checksum]")


$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-regenerate): %-regenerate:
	$(Q)$(call MESSAGE,"[ Clean for regenerating $*  a new]")
	$(Q)rm -rf $(BLRT_OOSB)/$*-build-artifacts/target
	$(Q)find $(BLRT_OOSB)/$*-build-artifacts/ -name ".stamp_target_installed" -delete
#	$(Q)rm -f =$(BLRT_OOSB)/$*-build-artifacts/build/host-gcc-final-*/.stamp_host_installed


$(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-certificate): %-certificate:  # Generqte qrious certificates
	$(Q)$(call MESSAGE,"[ $*'s various certificates generation a new]")

# @if grep -q 'BR2_PACKAGE_LIBOPENSSL_BIN=y' $(BLRT_OOSB)/$*-build-artifacts/.config; 	\
# then 																					\
# 	echo "--- Certificates $* generation---" ;  										\
# 	mkdir -pv $(CERTS_DIR)/openssl-ca/{root,private,certs}           					\
# 	touch "$(CERTS_DIR)/openssl-ca/index.txt" 											\
# 	test -f $(CERTS_DIR)/openssl-ca/serial || echo 00 > $(CERTS_DIR)/openssl-ca/serial 	\
# else 																					\
# 	echo "--- (SKIP cert generatrion) $* ---" ; 										\
# fi \





# echo "--- Generation $* ca.key---" ;  \
# openssl genrsa -out $(CERTS_DIR)/openssl-ca/$(subst $*-,,$@)-ca.key 4096 \
# echo "--- Generation $* ca.csr---" ;  \
# openssl req -sha256 -key $(CERTS_DIR)/openssl-ca/$(subst $*-,,$@)-ca.key -days 365 -new -out $(CERTS_DIR)/openssl-ca/$(subst $*-,,$@)-ca.csr -config $(CERTS_DIR)/openssl-ca/demo-openssl.cnf -extensions v3_ca -subj "/C=US/ST=Maryland/O=ACME Systems Technologies/CN=Sample CA" \
# echo "--- Generation $* ca.crt---" ;  \
# openssl x509 -sha256 -req -in $(CERTS_DIR)/openssl-ca/$(subst $*-,,$@)-ca.csr -signkey $(CERTS_DIR)/openssl-ca/$(subst $*-,,$@)-ca.key -out $(CERTS_DIR)/openssl-ca/$(subst $*-,,$@)-ca.crt -extfile $(CERTS_DIR)/openssl-ca/demo-openssl.cnf -extensions v3_ca -days 365 \
# echo "--- Generation $* server.key---" ;  \
# openssl genrsa -out $(CERTS_DIR)/openssl-ca/$(subst $*-,,$@)-server.key 2048 \
# echo "--- Generation $* server.csr---" ;  \
# openssl req -sha256 -key $(CERTS_DIR)/openssl-ca/$(subst $*-,,$@)-server.key -days 365 -new -out $(CERTS_DIR)/openssl-ca/$(subst $*-,,$@)-server.csr -config $(CERTS_DIR)/openssl-ca/demo-openssl.cnf -subj "/C=US/ST=Maryland/O=ACME Systems Technologies/CN=test-server" \
# echo "--- Generation $* server.crt---" ;  \
# openssl ca -batch -config $(CERTS_DIR)/openssl-ca/demo-openssl.cnf -in $(CERTS_DIR)/openssl-ca/$(subst $*-,,$@)-server.csr -out $(CERTS_DIR)/openssl-ca/$(subst $*-,,$@)-server.crt -outdir . -keyfile $(CERTS_DIR)/openssl-ca/$(subst $*-,,$@)-ca.key -cert $(CERTS_DIR)/openssl-ca/$(subst $*-,,$@)-ca.crt -days 120 \

# 	@if grep -q 'BR2_TARGET_UBOOT=y' $(BLRT_OOSB)/$*-build-artifacts/.config; then
# 		$(Q)$(call MESSAGE,"[ Generating $* Rauc  certificate]")
# # This is a Test Ceritificate Authority, only to be used for testing.
# # $(Q)$(call MESSAGE,"[ Generating $* Swupdate certificate]")
# # $(Q)$(call MESSAGE,"[ Generating $* Webs certificate]")
# # $(Q)$(call MESSAGE,"[ Generating $* Tee certificate]")
# 	else 
# 		$(Q)$(call MESSAGE,"[ --- (UBOOT not activated SKIPPING $@ ---]")
# 	fi

# # # ####################################################################################################
# # # #
# # # #								Hidden goals declaration
# # # #
# # # ####################################################################################################

# init: .stamp_init
# 	$(Q)$(call MESSAGE,"[  === $@ ===" ]")

# .stamp_init: .stamp_os $(foreach defconfig,$(SUPPORTED_TARGETS),.stamp_init_$(defconfig))
# 	$(Q)$(call MESSAGE,"[  === $@ ===" ]")

# .stamp_os: .stamp_os_depends $(foreach defconfig,$(SUPPORTED_TARGETS),.stamp_os_$(defconfig))
# 	$(Q)$(call MESSAGE,"[  === $@ ===" ]")

# .stamp_os_depends: .stamp_toolchain $(foreach defconfig,$(SUPPORTED_TARGETS),.stamp_os_depends_$(defconfig))
# 	$(Q)$(call MESSAGE,"[  === $@ ===" ]")

# .stamp_toolchain: .stamp_source $(foreach defconfig,$(SUPPORTED_TARGETS),.stamp_toolchain_$(defconfig))
# 	$(Q)$(call MESSAGE,"[  === $@ ===" ]")

# .stamp_source: .stamp_config $(foreach defconfig,$(SUPPORTED_TARGETS),.stamp_source_$(defconfig))
# 	$(Q)$(call MESSAGE,"[  === $@ ===" ]")

# .stamp_config: .stamp_submodules $(foreach defconfig,$(SUPPORTED_TARGETS),.stamp_config_$(defconfig))
# 	$(Q)$(call MESSAGE,"[  === $@ ===" ]")

# .stamp_submodules:
# 	$(Q)$(call MESSAGE,"[  === $@ ===" ]")
# #	$(Q)git submodule init
# #	$(Q)git submodule update --recursive
# #	$(Q)touch $@

# OPTEE_BASE=$(pwd)
# export PATH=${OPTEE_BASE}/buildroot/output/host/bin:${OPTEE_BASE}/myrootfs/usr/include:${OPTEE_BASE}/myrootfs/usr/lib:$PATH
# export TA_DEV_KIT_DIR=${OPTEE_BASE}/optee_os/out/arm-plat-rpi4/export-ta_arm64
# export TEEC_EXPORT=${OPTEE_BASE}/buildroot/output/host/aarch64-buildroot-linux-gnu/sysroot/usr
# export CROSS_COMPILE=aarch64-buildroot-linux-gnu-
# export HOST_CROSS_COMPILE=aarch64-buildroot-linux-gnu-
# export TA_CROSS_COMPILE=aarch64-buildroot-linux-gnu-

.PHONY: help
help: ## Display this help and exits.
	$(Q)echo ""
	$(Q)echo "  Version $$(git describe --always), Copyright (C) 2023 AHL"
	$(Q)echo
	$(Q)echo "  Comes with ABSOLUTELY NO WARRANTY; for details see file LICENSE."
	$(Q)echo "  SPDX-License-Identifier: GPL-2.0-only"
	$(Q)echo
	$(Q)echo "$(TERM_UNDERLINE)Supported targets:$(TERM_NOUNDERLINE)"
	$(Q)echo
	$(Q)$(foreach b, $(sort $(notdir $(patsubst %_defconfig,%,$(wildcard $(DEFCONFIG_DIR)/*_defconfig)))), \
		printf "  	%-30s - Build configuration for %s\\n" $(b) $(b:_defconfig=); \
	)
	$(Q)echo
	$(Q)echo "$(TERM_BOLD)Build Environment$(TERM_RESET)"
	$(Q)echo
	$(Q)echo
	$(Q)echo "$(TERM_BOLD)Availables commands$(TERM_RESET)"
	$(Q)echo ""
	$(Q)echo "" 
	$(Q)echo ".-----------------.--------------------.------------------.--------------------. "
	$(Q)echo "|  Adrien L. H    | Real-Time Embedded | /\"\ ASCII RIBBON | ACME's conspiracy: |"
	$(Q)echo "| +xx 000 000 000 | Software Architect | \ / CAMPAIGN     |  ___                |"
	$(Q)echo "| +xx 000 000 000 \`------------.-------:  X  AGAINST      |  \e/  There is no  |"
	$(Q)echo "| https://memyselandi_ad_exem/ | _/*\_ | / \ HTML MAIL    |   v   conspiracy.   |"
	$(Q)echo "'------------------------------^-------^------------------^---------------------'"
	$(Q)echo ""
#	@grep '^[^.#]\+:\s\+.*#' Makefile | \
#	sed "s/\(.\+\):\s*\(.*\) #\s*\(.*\)/`printf "\033[93m"`\1`printf "\033[0m"`	\3 [\2]/" | \
#	expand -t20