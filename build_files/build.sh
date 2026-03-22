#!/bin/bash

set -ouex pipefail

## DNF5 Speedup
sed -i '/^\[main\]/a max_parallel_downloads=10' /etc/dnf/dnf.conf

#### Install Cachy kernel and utilities ####
# create a shims to bypass kernel install triggering dracut/rpm-ostree
# seems to be minimal impact, but allows progress on build
cd /usr/lib/kernel/install.d \
&& mv 05-rpmostree.install 05-rpmostree.install.bak \
&& mv 50-dracut.install 50-dracut.install.bak \
&& printf '%s\n' '#!/bin/sh' 'exit 0' > 05-rpmostree.install \
&& printf '%s\n' '#!/bin/sh' 'exit 0' > 50-dracut.install \
&& chmod +x  05-rpmostree.install 50-dracut.install

## Install CachyOS kernel
dnf5 -y copr enable bieszczaders/kernel-cachyos
dnf5 -y remove kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra --setopt=protected_packages= --setopt=protect_running_kernel=False
rm -rf /lib/modules/* # Remove kernel files that remain
dnf5 -y install kernel-cachyos kernel-cachyos-devel-matched --allowerasing

dnf5 -y copr enable bieszczaders/kernel-cachyos-addons
rm -rf /usr/lib/systemd/coredump.conf
dnf5 -y install cachyos-settings scx-scheds scx-tools-git scx-manager ananicy-cpp --allowerasing

## Experimental: use ADIOS IO scheduler by default on nvme disks
echo > /etc/udev/rules.d/60-ioschedulers.rules << EOF
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/rotational}=="0", \
    ATTR{queue/scheduler}="adios"
EOF


# restore kernel install
mv -f 05-rpmostree.install.bak 05-rpmostree.install \
&& mv -f 50-dracut.install.bak 50-dracut.install
cd -

# Regen initramfs
releasever=$(/usr/bin/rpm -E %fedora)
basearch=$(/usr/bin/arch)
KERNEL_VERSION=$(dnf list kernel-cachyos -q | awk '/kernel-cachyos/ {print $2}' | head -n 1 | cut -d'-' -f1)-cachyos1.fc${releasever}.${basearch}
# Ensure Initramfs is generated
depmod -a ${KERNEL_VERSION}
mkdir -p /var/roothome
export DRACUT_NO_XATTR=1
/usr/bin/dracut --no-hostonly --kver "${KERNEL_VERSION}" --reproducible -v --add ostree -f "/lib/modules/${KERNEL_VERSION}/initramfs.img"
chmod 0600 "/lib/modules/${KERNEL_VERSION}/initramfs.img"


#### Install COSMIC DESKTOP ####
dnf5 -y copr enable ryanabx/cosmic-epoch
dnf5 -y install cosmic-desktop

#### Enable podman

systemctl enable podman.socket

## CLEAN UP
# Clean up dnf cache to reduce image size
dnf5 -y clean all
rm -rf /run/dnf /run/selinux-policy
rm -rf /var/lib/dnf
