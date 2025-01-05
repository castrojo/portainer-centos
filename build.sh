#!/bin/bash

set -ouex pipefail

# See https://github.com/centos-workstation/achillobator/issues/3
mkdir -m 0700 -p /var/roothome
# Fast track https://gitlab.com/fedora/bootc/base-images/-/merge_requests/71
ln -sf /run /var/run
# Required for Logically Bound images, see https://gitlab.com/fedora/bootc/examples/-/tree/main/logically-bound-images/usr/share/containers/systemd
ln -sr /etc/containers/systemd/*.container /usr/lib/bootc/bound-images.d/

# Packages

# ZFS Kernel Module
# Documentation on https://openzfs.github.io/openzfs-docs/Getting%20Started/RHEL-based%20distro/index.html
# Prefer DKMS installation since it has support for kernels that arent the current EL ones
# This also needs to be sequential, else DKMS wont be able to build the kernel module
dnf -y install https://zfsonlinux.org/epel/zfs-release-2-3$(rpm --eval "%{dist}").noarch.rpm
dnf -y install epel-release
dnf -y install kernel-devel
dnf -y install zfs
echo "zfs" | tee /etc/modules-load.d/zfs.conf

dnf install -y cockpit{,-{machines,podman,files}} libvirt tmux vim firewalld

# Cockpit ZFS Manager
ZFS_MANAGER_TEMP=$(mktemp -d)
git clone https://github.com/45drives/cockpit-zfs-manager.git $ZFS_MANAGER_TEMP 
cp -r $ZFS_MANAGER_TEMP/zfs /usr/share/cockpit
rm -rf $ZFS_MANAGER_TEMP

# Fixes missing fonts on Cockpit ZFS manager
COCKPIT_FONT_DIRECTORY="/usr/share/cockpit/base1/fonts"
mkdir -p $COCKPIT_FONT_DIRECTORY
curl -o $COCKPIT_FONT_DIRECTORY/fontawesome.woff -sSL https://scripts.45drives.com/cockpit_font_fix/fonts/fontawesome.woff
curl -o $COCKPIT_FONT_DIRECTORY/glyphicons.woff -sSL https://scripts.45drives.com/cockpit_font_fix/fonts/glyphicons.woff
curl -o $COCKPIT_FONT_DIRECTORY/patternfly.woff -sSL https://scripts.45drives.com/cockpit_font_fix/fonts/patternfly.woff
mkdir -p /usr/share/cockpit/static/fonts
curl -sSL https://scripts.45drives.com/cockpit_font_fix/fonts/OpenSans-Semibold-webfont.woff -o /usr/share/cockpit/static/fonts/OpenSans-Semibold-webfont.woffi

# Docker install: https://docs.docker.com/engine/install/centos/#install-using-the-repository
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf config-manager --set-disabled docker-ce-stable
dnf -y --enablerepo docker-ce-stable install \
  docker-ce docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Tailscale
dnf config-manager --add-repo https://pkgs.tailscale.com/stable/centos/9/tailscale.repo
dnf config-manager --set-disabled tailscale-stable
dnf -y --enablerepo tailscale-stable install \
  tailscale

# Services

systemctl enable podman.socket
systemctl enable cockpit.socket
systemctl enable rpm-ostreed-automatic.timer 
systemctl enable tailscaled.service
systemctl disable auditd.service
systemctl enable docker.service
