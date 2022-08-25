#!/bin/bash

if [[ ! -d .git ]]
then
    # Assume this is a package build
    # .build_vars and config.mk should already be generated
    . .build_vars
    if [[ ! -d kernel ]]
    then
        echo "Kernel directory is missing! Build will fail."
        exit 1
    fi
    if [[ ! -f config.mk ]]
    then
        echo "config.mk is missing! Build will fail."
        exit 1
    fi
    exit 0
fi


echo "${UBUNTU_KERNEL_VERSION}"
DISTRO=$(echo "${UBUNTU_KERNEL_VERSION}" | cut -d'/' -f 1)
echo "DISTRO: ${DISTRO}"
DISTRO_RELEASE=$(echo "${UBUNTU_KERNEL_VERSION}" | cut -d'/' -f 2)
echo "DISTRO_RELEASE: ${DISTRO_RELEASE}"
KERNEL_VERSION_RAW=$(echo "${UBUNTU_KERNEL_VERSION}" | cut -d'/' -f 3)
echo "KERNEL_VERSION_RAW: ${KERNEL_VERSION_RAW}"

HWE_TAG=$(echo "${UBUNTU_KERNEL_VERSION}"|grep -Po "Ubuntu-hwe-[^-]+")
if [ -z "$HWE_TAG" ]
then
    KERNEL_TAG=$(echo "${UBUNTU_KERNEL_VERSION}"|grep -Po "(?<=$DISTRO_RELEASE/)[_a-zA-Z0-9-\.]+(?=$)")
    HWE_VERSION=""
else
    KERNEL_TAG=$(echo "${UBUNTU_KERNEL_VERSION}"|grep -Po "(?<=$DISTRO_RELEASE/)$HWE_TAG-[_a-zA-Z0-9-\.]+(?=$)")
    HWE_VERSION=$(echo $HWE_TAG|grep -Po "[0-9\.]+")
fi
KERNEL_FLAVOR="-generic"
KERNEL_VERSION=$(echo "${UBUNTU_KERNEL_VERSION}"|grep -Po "(?<=$HWE_VERSION\-)[0-9\.-]+(?=\.[0-9]+)")
echo "KERNEL_VERSION: ${KERNEL_VERSION}"
KERNEL_VERSION_MAJOR=$(echo "${KERNEL_VERSION}"|grep -Po "^([0-9]+\.[0-9]+)")
echo "KERNEL_VERSION_MAJOR: ${KERNEL_VERSION_MAJOR}"
KERNEL_VERSION_FULL=$(echo "${UBUNTU_KERNEL_VERSION}"|grep -Po "(?<=$HWE_VERSION\-)[0-9\.-]+\.[0-9]+")
echo "KERNEL_VERSION_FULL: ${KERNEL_VERSION_FULL}"
PATCH_VERSION=$(head -n1 debian/changelog |grep -Po "(?<=$KERNEL_VERSION_FULL-).*(?=~)")
echo "PATCH_VERSION: ${PATCH_VERSION}"

apt-get install -y kmod linux-headers-${KERNEL_VERSION}${KERNEL_FLAVOR} linux-modules-${KERNEL_VERSION}${KERNEL_FLAVOR}

#TODO: We're assuming Ubuntu right now

if [[ ! -d kernel ]]
then
    # Clone the kernel into a working directory
    git clone --branch $KERNEL_TAG --depth 1 git://kernel.ubuntu.com/ubuntu/ubuntu-$DISTRO_RELEASE.git kernel

    export QUILT_PATCHES=patches/${DISTRO}/${DISTRO_RELEASE}/${KERNEL_VERSION_MAJOR}/${KERNEL_VERSION_FULL}
    # Apply patches
    quilt push -a
fi

truncate -s0 .build_vars
echo "DISTRO=$DISTRO" >> .build_vars
echo "DISTRO_RELEASE=$DISTRO_RELEASE" >> .build_vars
echo "HWE_TAG=$HWE_TAG" >> .build_vars
echo "HWE_VERSION=$HWE_VERSION" >> .build_vars
echo "KERNEL_TAG=$KERNEL_TAG" >> .build_vars
echo "KERNEL_FLAVOR=$KERNEL_FLAVOR" >> .build_vars
echo "KERNEL_VERSION=$KERNEL_VERSION" >> .build_vars
echo "KERNEL_VERSION_FULL=$KERNEL_VERSION_FULL" >> .build_vars
echo "PATCH_VERSION=$PATCH_VERSION" >> .build_vars

truncate -s0 config.mk
echo "KERNEL_LIB_PATH = /lib/modules/$KERNEL_VERSION$KERNEL_FLAVOR" >> config.mk
echo "KERNEL_CONFIG_FILE = /boot/config-$KERNEL_VERSION$KERNEL_FLAVOR" >> config.mk
echo "KERNEL_SYMVERS_FILE = /usr/src/linux-headers-$KERNEL_VERSION$KERNEL_FLAVOR/Module.symvers" >> config.mk
echo 'INSTALL_DIR = $(DESTDIR)$(KERNEL_LIB_PATH)/updates/introvirt/' >> config.mk
echo "PATCH_VERSION = $PATCH_VERSION" >> config.mk
echo "KERNEL_VERSION_FULLER = $KERNEL_VERSION$KERNEL_FLAVOR" >> config.mk

rm -f debian/*.install debian/*.postinst

cp -f debian/kvm-introvirt.install.tpl "debian/kvm-introvirt-$KERNEL_VERSION-generic.install"
cp -f debian/kvm-introvirt.postinst.tpl "debian/kvm-introvirt-$KERNEL_VERSION-generic.postinst"

sed -i "s/[0-9]\+\.[0-9]\+\.[0-9]\+-[0-9]\+\.[0-9]\+/$KERNEL_VERSION_FULL/g" debian/changelog
sed -i "s/focal/${DISTRO_RELEASE}/g" debian/changelog
sed -i "s/[0-9]\+\.[0-9]\+\.[0-9]\+-[0-9]\+$KERNEL_FLAVOR/$KERNEL_VERSION$KERNEL_FLAVOR/g" debian/control
sed -i "s/[0-9]\+\.[0-9]\+\.[0-9]\+-[0-9]\+$KERNEL_FLAVOR/$KERNEL_VERSION$KERNEL_FLAVOR/g" debian/*.postinst

make

exit 0
