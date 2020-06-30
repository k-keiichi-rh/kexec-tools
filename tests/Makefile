MAKE_ROOT := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
BUILD_ROOT := $(MAKE_ROOT)/build
TEST_ROOT := $(MAKE_ROOT)/output
REPO = $(shell realpath $(MAKE_ROOT)/../)
ARCH ?= $(shell arch)
SPEC = kexec-tools.spec

DIST ?= fedora
DIST_ABR ?= f
DIST_ABRL ?= fc
DIST_UNSET ?= rhel
RELEASE ?= 32

BASE_IMAGE_VER ?= 1.6
BASE_IMAGE ?= Fedora-Cloud-Base-$(RELEASE)-$(BASE_IMAGE_VER).x86_64.raw
BASE_IMAGE := $(BUILD_ROOT)/$(BASE_IMAGE)
BASE_IMAGE_XZ ?= $(BASE_IMAGE).xz
BASE_IMAGE_URL ?= https://dl.fedoraproject.org/pub/fedora/linux/releases/$(RELEASE)/Cloud/$(ARCH)/images/$(BASE_IMAGE_XZ)

BUILD_ROOT = $(MAKE_ROOT)/build
RPMDEFINE = --define '_sourcedir $(REPO)'\
	    --define '_specdir $(REPO)'\
	    --define '_builddir $(BUILD_ROOT)'\
	    --define '_srcrpmdir $(BUILD_ROOT)'\
	    --define '_rpmdir $(BUILD_ROOT)'\
	    --define 'dist %{?distprefix}.$(DIST_ABRL)$(RELEASE)'\
	    --define '$(DIST) $(RELEASE)'\
	    --eval '%undefine $(DIST_UNSET)'\
	    --define '$(DIST_ABRL)$(RELEASE) 1'\

KEXEC_TOOLS_SRC = $(filter-out $(REPO)/tests,$(wildcard $(REPO)/*))
KEXEC_TOOLS_DIST_SRC = $(wildcard $(REPO)/*)
KEXEC_TOOLS_NVR = $(shell rpm $(RPMDEFINE) -q --specfile $(REPO)/$(SPEC) 2>/dev/null | grep -m 1 .)
KEXEC_TOOLS_RPM = $(BUILD_ROOT)/$(ARCH)/$(KEXEC_TOOLS_NVR).rpm

# Use fedpkg --release $(DIST_ABR)$(RELEASE) --path ../../ local
# or rpmbuild $(RPMDEFINE) -ba $(REPO)/$(SPEC)
$(KEXEC_TOOLS_RPM): $(KEXEC_TOOLS_SRC)
	@echo Rebuilding RPM due to modification of sources: $?
	rpmbuild $(RPMDEFINE) -ba $(REPO)/$(SPEC)

$(BASE_IMAGE_XZ):
	wget $(BASE_IMAGE_URL)

$(BASE_IMAGE): $(BASE_IMAGE_XZ)
	xz -d -k $(BASE_IMAGE_XZ)

# boot-image: $(KEXEC_TOOLS_RPM) $(BASE_IMAGE)
boot-image: $(BASE_IMAGE) $(KEXEC_TOOLS_RPM)
	scripts/build-boot-image.sh $(BASE_IMAGE) $(MAKE_ROOT)/boot-image $(KEXEC_TOOLS_RPM)

test:
	# timeout --foreground 10m qemu-system-$(ARCH)
	mkdir -p $(TEST_ROOT)
	timeout --foreground 10m qemu-kvm \
		-nodefaults \
		-nographic \
		-smp 1 \
		-m 512M \
		-serial stdio \
		-serial file:$(TEST_ROOT)/result \
		-monitor none \
		-hda $(BASE_IMAGE)
	grep KEXEC-TOOLS-TEST $(TEST_ROOT)/result

all: boot-image
#	echo $(KEXEC_TOOLS_SRC)
#	echo wget $(VM_IMAGE_URL) -o base-image.raw.xz
#	echo xz -d baseimage.raw.xz

#kexec-tools-rpm:
#	echo fedpkg local
#	echo losetup -f $<
#
#boot.img: base-image.raw
#	echo losetup -f $<
#	echo losetup -f $<
#
#.PHONY: local_dump_test
#local_dump_test: bootimage.raw
#
#.PHONY: local_dump_test
#local_dump_test: bootimage.raw
