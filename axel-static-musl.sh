#!/bin/bash
set -euo pipefail

ARCH=${ARCH:-x86_64}

##map arch to Alpine minirootfs URL and QEMU binary name
case "${ARCH}" in
  x86_64)
    ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-minirootfs-3.23.3-x86_64.tar.gz"
    QEMU_ARCH=""
    ;;
  x86)
    ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86/alpine-minirootfs-3.23.3-x86.tar.gz"
    QEMU_ARCH="i386"
    ;;
  aarch64)
    ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/aarch64/alpine-minirootfs-3.23.3-aarch64.tar.gz"
    QEMU_ARCH="aarch64"
    ;;
  armhf)
    ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/armhf/alpine-minirootfs-3.23.3-armhf.tar.gz"
    QEMU_ARCH="arm"
    ;;
  armv7)
    ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/armv7/alpine-minirootfs-3.23.3-armv7.tar.gz"
    QEMU_ARCH="arm"
    ;;
  *)
    echo "Unknown architecture: ${ARCH}"
    exit 1
    ;;
esac

TARBALL="${ALPINE_URL##*/}"

##install some dependencies
sudo apt -y install wget curl binutils

##download alpine rootfs
wget -c "${ALPINE_URL}"

##extract rootfs
mkdir pasta
tar xf "${TARBALL}" -C pasta/

##copy resolv.conf into the folder
cp /etc/resolv.conf ./pasta/etc/

##setup QEMU for cross-arch builds
if [ -n "${QEMU_ARCH}" ]; then
  sudo apt -y install qemu-user-static
  sudo mkdir -p ./pasta/usr/bin/
  sudo cp "/usr/bin/qemu-${QEMU_ARCH}-static" "./pasta/usr/bin/"
fi

##if fails in cat command add inside chroot line this command "cat src/css_.c >> src/css.c"

##mount, bind and chroot into dir
sudo mount -t proc none ./pasta/proc/
sudo mount --rbind /dev ./pasta/dev/
sudo mount --rbind /sys ./pasta/sys/
sudo chroot ./pasta/ /bin/sh -c "apk update && apk add build-base \
musl-dev \
openssl-dev \
zlib-dev \
libidn2-dev \
libpsl-dev \
libuuid \
curl \
gawk \
libidn2-static \
openssl-libs-static \
zlib-static \
libpsl-static \
flex \
bison \
libunistring-dev \
libunistring-static \
perl && curl -L -O 'https://github.com/axel-download-accelerator/axel/releases/download/v2.17.14/axel-2.17.14.tar.gz' && \
tar xf axel-2.17.14.tar.gz && \
cd axel-2.17.14/ && \
./configure CC=gcc LDFLAGS='-static' CFLAGS='-O2' && \
make -j\$(nproc) && \
strip axel"
mkdir -p dist
cp "./pasta/axel-2.17.14/axel" "dist/axel-${ARCH}"
tar -C dist -cJf "dist/axel-${ARCH}.tar.xz" "axel-${ARCH}"
