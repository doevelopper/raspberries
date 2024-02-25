#
# Copyright (c) 2022-2024, ACME AHL Limited and Contributors. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

qstrip                   =  $(strip $(subst ",,$(1)))
MESSAGE                  =  echo "$(shell date +%Y-%m-%dT%H:%M:%S) $(TERM_BOLD)\#\#\#\#\#\#  $(call qstrip,$(1)) \#\#\#\#\#\# $(TERM_RESET)"
TERM_BOLD                := $(shell tput smso 2>/dev/null)
TERM_RESET               := $(shell tput rmso 2>/dev/null)
TERM_RED                 := $(shell tput setb 2 2>/dev/null)
TERM_BLINK               := $(shell tput blink 2>/dev/null)
TERM_REV                 := $(shell tput rev 2>/dev/null)
TERM_UNDERLINE           := $(shell tput smul 2>/dev/null)
TERM_NOUNDERLINE         := $(shell tput rmul 2>/dev/null)
FULL_OUTPUT              ?= /dev/null

SHELL                    =  bash
AWK                      := awk
CP                       := cp
EGREP                    := egrep
HTML_VIEWER              := cygstart
KILL                     := /bin/kill
M4                       := m4
MV                       := mv
PDF_VIEWER               := cygstart
RM                       := rm -f
MKDIR                    := mkdir -p
LNDIR                    := lndir
SED                      := sed
SORT                     := sort
TOUCH                    := touch
XMLTO                    := xmlto
XMLTO_FLAGS              =  -o $(OUTPUT_DIR) $(XML_VERBOSE)
BISON                    := $(shell which bison || type -p bison)
UNZIP                    := $(shell which unzip || type -p unzip) -q

# Check if verbosity is ON for build process
CMD_PREFIX_DEFAULT       := @
NPD                      ?= --no-print-directory
ifeq ($(V), 1)
    Q                    :=
    S                    :=
else
    Q                    := $(CMD_PREFIX_DEFAULT)
    S                    ?= -s $(NPD)
endif

print-help-run           =  printf "      %-30s - %s\\n" "$1" "$2"
print-help               =  $(Q)$(call print-help-run,$1,$2)

BUILDROOT                := buildroot
BLRT_LATEST              := https://github.com/buildroot/buildroot.git
BLRT_VERSION             =  2023.11.1
BLRT_EXT                 =  br2-rpis-external
# BLRT_EXT                 +=  br2-cfsos-closed-sources
DEFCONFIG_DIR            =  $(BLRT_EXT)/configs
DEFCONFIG_DIR_FULL       =  $(PWD)/$(BLRT_EXT)/configs
CERTS_DIR                =  $(PWD)/$(BLRT_EXT)/board/common/certs
OPENSSL_CONF             = "$(CERTS_DIR)/openssl.cnf"
DATE                     := $(shell date +%Y.%m.%d-%H%M%S --utc)
HOSTNAME                 := "rambleros"
VERSION_DATE             := $(shell date --utc +'%Y%m%d')
VERSION_DEV              := dev$(VERSION_DATE)
TOP_DIR                  := $(shell readlink -f .)
USER                     := $(or $(UNIX_USER),ubuntu)
UID                      := $(or $(UNIX_UID),1000)
OS                       := $(shell sed -ne "/CODENAME/s/[^=]*=//gp" /etc/lsb-release)

ifeq ($(PARALLEL_JOBS),)
    PARALLEL_JOBS := $(shell echo $$((1 + `nproc 2>/dev/null || echo 0`)))
else ifeq ($(PARALLEL_JOBS),0)
    PARALLEL_JOBS := $(shell echo $$((1 + `nproc 2>/dev/null || echo 0`)))
endif

PARALLEL_OPTS = -j$(PARALLEL_JOBS) PARALLEL_JOBS=$(PARALLEL_JOBS)
ifneq ($(PARALLEL_JOBS),1)
    PARALLEL_OPTS += -Orecurse
endif


SUPPORTED_TARGETS        :=  $(sort $(notdir $(patsubst %_defconfig,%,$(wildcard $(DEFCONFIG_DIR)/*_defconfig))))

CFSOS_GOALD              :=                                                                                                   \
                            configure $(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-configure)                        \
                            compile $(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-compile)                            \
                            unit-test $(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-unit-test)                        \
                            certificate $(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-certificate)                    \
                            integration-test $(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-integration-test)          \
                            release $(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-release)                            \
                            menuconfig $(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-menuconfig)                      \
                            linux-menuconfig $(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-linux-menuconfig)          \
                            linux-rebuild $(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-linux-rebuild)                \
                            uboot-menuconfig $(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-uboot-menuconfig)          \
                            uboot-rebuild $(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-uboot-rebuild)                \
                            busybox-menuconfig $(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-busybox-menuconfig)      \
                            busybox-rebuild $(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-busybox-rebuild)            \
                            savedefconfig $(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-savedefconfig)                \
                            clean $(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-clean)                                \
                            distclean $(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-distclean)                        \
                            package-clean $(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-package-clean)                \
                            realclean $(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-realclean)                        \
                            upload $(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-upload)                              \
                            upgrade $(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-upgrade)                            \
                            checksum $(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-checksum)                          \
                            regenerate $(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-regenerate)                      \
                            # optee-os $(foreach defconfig,$(SUPPORTED_TARGETS),$(defconfig)-optee-os)                        \


## out of source build
BLRT_OOSB                =   $(PWD)/workspace
BLRT_ARTIFACTS_DIR       =   $(BLRT_OOSB)/artifacts
BLRT_PACKAGE_DIR         =   $(PWD)/dependencies
BLRT_DIR                 =   $(BLRT_PACKAGE_DIR)/buildroot-$(BLRT_VERSION)
BLRT_MAKE                :=  $(BLRT_DIR)/utils/brmake
BLRT_MAKEARGS            :=  -C $(BLRT_DIR)
BLRT_MAKEARGS            +=  BR2_EXTERNAL=$(PWD)/$(BLRT_EXT)
BLRT_MAKEARGS            +=  BR2_JLEVEL=`getconf _NPROCESSORS_ONLN`
# BLRT_MAKEARGS            +=  BR2_CCACHE_DIR=$(BLRT_PACKAGE_DIR)/cache/cc
# BLRT_MAKEARGS            +=  BR2_CCACHE_DIR=$(BLRT_PACKAGE_DIR)/cache/cc/$*
BLRT_MAKEARGS            +=  BR2_DL_DIR=$(BLRT_PACKAGE_DIR)/cache/dl 
BLRT_MAKEARGS            +=  BR2_TARGET_GENERIC_HOSTNAME=$(HOSTNAME)
BLRT_MAKEARGS            +=  BR2_TARGET_GENERIC_ISSUE="Core Real-Time Executive Multiprocessor Software System" 
BLRT_MAKEARGS            +=  VERSION=$(VERSION)
#BLRT_MAKEARGS           +=  O=$(BLRT_OOSB)/$(TARGET_BOARD)-build-artifacts
VERSION_GIT_EPOCH        :=  $(shell $(GIT) log -1 --format=%at 2> /dev/null)
# CPPFLAGS="-DVERSION='\"${VERSION_STRING}\"'" 
# Some utility macros for manipulating awkward (whitespace) characters.
blank			         :=
space			         :=${blank} ${blank}


# Default dummy firmware encryption key
ENC_KEY	                 := 1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef

