#!/bin/bash

set -ouex pipefail

## DNF5 Speedup
sed -i '/^\[main\]/a max_parallel_downloads=10' /etc/dnf/dnf.conf

## System apps
dnf -y install libvirt virt-manager qemu-kvm flatpak-builder wlr-randr

# User apps
dnf -y install nautilus kitty mpv obs-studio gnome-terminal

#### Enable podman

systemctl enable podman.socket

## CLEAN UP
# Clean up dnf cache to reduce image size
dnf5 -y clean all
rm -rf /run/dnf /run/selinux-policy
rm -rf /var/lib/dnf
