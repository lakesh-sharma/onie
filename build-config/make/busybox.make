#-------------------------------------------------------------------------------
#
#
#-------------------------------------------------------------------------------
#
# This is a makefile fragment that defines the build of busybox
#

BUSYBOX_VERSION		= 1.20.2
BUSYBOX_TARBALL		= busybox-$(BUSYBOX_VERSION).tar.bz2
BUSYBOX_TARBALL_URLS	+= $(ONIE_MIRROR) http://www.busybox.net/downloads
BUSYBOX_BUILD_DIR	= $(MBUILDDIR)/busybox
BUSYBOX_DIR		= $(BUSYBOX_BUILD_DIR)/busybox-$(BUSYBOX_VERSION)
BUSYBOX_CONFIG		= conf/busybox.config

BUSYBOX_SRCPATCHDIR	= $(PATCHDIR)/busybox
BUSYBOX_PATCHDIR	= $(BUSYBOX_BUILD_DIR)/patch
MACHINE_BUSYBOX_CONFDIR ?= $(MACHINEDIR)/busybox/conf
BUSYBOX_DOWNLOAD_STAMP	= $(DOWNLOADDIR)/busybox-download
BUSYBOX_SOURCE_STAMP	= $(STAMPDIR)/busybox-source
BUSYBOX_PATCH_STAMP	= $(STAMPDIR)/busybox-patch
BUSYBOX_BUILD_STAMP	= $(STAMPDIR)/busybox-build
BUSYBOX_INSTALL_STAMP	= $(STAMPDIR)/busybox-install
BUSYBOX_STAMP		= $(BUSYBOX_SOURCE_STAMP) \
			  $(BUSYBOX_PATCH_STAMP) \
			  $(BUSYBOX_BUILD_STAMP) \
			  $(BUSYBOX_INSTALL_STAMP)

PHONY += busybox busybox-download busybox-source busybox-config busybox-patch \
	busybox-build busybox-install busybox-clean busybox-download-clean

BUSYBOX_MACHINEPATCHDIR = $(shell \
			   test -d $(MACHINEDIR)/busybox && \
			   echo "$(MACHINEDIR)/busybox")

ifneq ($(BUSYBOX_MACHINEPATCHDIR),)
  BUSYBOX_MACHINEPATCHDIR_FILES = $(BUSYBOX_MACHINEPATCHDIR)/*
endif

busybox: $(BUSYBOX_STAMP)

DOWNLOAD += $(BUSYBOX_DOWNLOAD_STAMP)
busybox-download: $(BUSYBOX_DOWNLOAD_STAMP)
$(BUSYBOX_DOWNLOAD_STAMP): $(PROJECT_STAMP)
	$(Q) rm -f $@ && eval $(PROFILE_STAMP)
	$(Q) echo "==== Getting upstream BusyBox ===="
	$(Q) $(SCRIPTDIR)/fetch-package $(DOWNLOADDIR) $(UPSTREAMDIR) \
		$(BUSYBOX_TARBALL) $(BUSYBOX_TARBALL_URLS)
	$(Q) touch $@

SOURCE += $(BUSYBOX_SOURCE_STAMP)
busybox-source: $(BUSYBOX_SOURCE_STAMP)
$(BUSYBOX_SOURCE_STAMP): $(TREE_STAMP) | $(BUSYBOX_DOWNLOAD_STAMP)
	$(Q) rm -f $@ && eval $(PROFILE_STAMP)
	$(Q) echo "==== Extracting upstream BusyBox ===="
	$(Q) $(SCRIPTDIR)/extract-package $(BUSYBOX_BUILD_DIR) $(DOWNLOADDIR)/$(BUSYBOX_TARBALL)
	$(Q) touch $@

busybox-patch: $(BUSYBOX_PATCH_STAMP)
$(BUSYBOX_PATCH_STAMP): $(BUSYBOX_SRCPATCHDIR)/* $(BUSYBOX_MACHINEPATCHDIR_FILES) $(BUSYBOX_SOURCE_STAMP)
	$(Q) rm -f $@ && eval $(PROFILE_STAMP)
	$(Q) echo "==== Patching Busybox ===="
	$(Q) mkdir -p $(BUSYBOX_PATCHDIR)
	$(Q) cp $(BUSYBOX_SRCPATCHDIR)/* $(BUSYBOX_PATCHDIR)
ifneq ($(BUSYBOX_MACHINEPATCHDIR),)
	$(Q) if [ -r $(BUSYBOX_MACHINEPATCHDIR)/series ] ; then \
		cat $(BUSYBOX_MACHINEPATCHDIR)/series >> $(BUSYBOX_PATCHDIR)/series ; \
		cp $(BUSYBOX_MACHINEPATCHDIR)/*.patch $(BUSYBOX_PATCHDIR) ; \
		else \
		echo "Unable to find machine dependent busybox patch series: $(BUSYBOX_MACHINEPATCHDIR)/series" ; \
		exit 1 ; \
		fi
endif
	$(Q) $(SCRIPTDIR)/apply-patch-series $(BUSYBOX_PATCHDIR)/series $(BUSYBOX_DIR)
	$(Q) touch $@

$(BUSYBOX_DIR)/.config: $(BUSYBOX_CONFIG) $(BUSYBOX_PATCH_STAMP)
	$(Q) echo "==== Copying $(BUSYBOX_CONFIG) to $(BUSYBOX_DIR)/.config ===="
	$(Q) cp -v $< $@
	$(Q) $(SCRIPTDIR)/apply-config-patch $@ $(MACHINE_BUSYBOX_CONFDIR)/config

busybox-config: $(BUSYBOX_DIR)/.config
	PATH='$(CROSSBIN):$(PATH)' \
		$(MAKE) -C $(BUSYBOX_DIR) CROSS_COMPILE=$(CROSSPREFIX) menuconfig

ifndef MAKE_CLEAN
BUSYBOX_NEW_FILES = $(shell test -d $(BUSYBOX_DIR) && test -f $(BUSYBOX_BUILD_STAMP) && \
	              find -L $(BUSYBOX_DIR) -newer $(BUSYBOX_BUILD_STAMP) \! -name .kernelrelease  \
			\! -name busybox.links -type f -print -quit )
endif

busybox-build: $(BUSYBOX_BUILD_STAMP)
$(BUSYBOX_BUILD_STAMP): $(BUSYBOX_DIR)/.config $(BUSYBOX_NEW_FILES) $(UCLIBC_INSTALL_STAMP) | $(DEV_SYSROOT_INIT_STAMP)
	$(Q) rm -f $@ && eval $(PROFILE_STAMP)
	$(Q) echo "====  Building busybox-$(BUSYBOX_VERSION) ===="
	$(Q) PATH='$(CROSSBIN):$(PATH)'				\
	    $(MAKE) -C $(BUSYBOX_DIR)				\
		CONFIG_SYSROOT=$(DEV_SYSROOT)			\
		CONFIG_EXTRA_CFLAGS="$(ONIE_CFLAGS)"		\
		CONFIG_EXTRA_LDFLAGS="$(ONIE_LDFLAGS)"		\
		CONFIG_PREFIX=$(SYSROOTDIR)			\
		CROSS_COMPILE=$(CROSSPREFIX) V=$(V)
	$(Q) touch $@

busybox-install: $(BUSYBOX_INSTALL_STAMP)
$(BUSYBOX_INSTALL_STAMP): $(SYSROOT_INIT_STAMP) $(BUSYBOX_BUILD_STAMP)
	$(Q) rm -f $@ && eval $(PROFILE_STAMP)
	$(Q) echo "==== Installing busybox in $(SYSROOTDIR) ===="
	$(Q) PATH='$(CROSSBIN):$(PATH)'			\
		$(MAKE) -C $(BUSYBOX_DIR)			\
		CONFIG_SYSROOT=$(DEV_SYSROOT)			\
		CONFIG_EXTRA_CFLAGS="$(ONIE_CFLAGS)"		\
		CONFIG_EXTRA_LDFLAGS="$(ONIE_LDFLAGS)"		\
		CONFIG_PREFIX=$(SYSROOTDIR)			\
		CROSS_COMPILE=$(CROSSPREFIX)			\
		install
	$(Q) chmod 4755 $(SYSROOTDIR)/bin/busybox
	$(Q) touch $@

USERSPACE_CLEAN += busybox-clean
busybox-clean:
	$(Q) rm -rf $(BUSYBOX_BUILD_DIR)
	$(Q) rm -f $(BUSYBOX_STAMP)
	$(Q) echo "=== Finished making $@ for $(PLATFORM)"

DOWNLOAD_CLEAN += busybox-download-clean
busybox-download-clean:
	$(Q) rm -f $(BUSYBOX_DOWNLOAD_STAMP) $(DOWNLOADDIR)/$(BUSYBOX_TARBALL)

#-------------------------------------------------------------------------------
#
# Local Variables:
# mode: makefile-gmake
# End:
