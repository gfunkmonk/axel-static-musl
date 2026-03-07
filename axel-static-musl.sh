#!/bin/bash
set -euo pipefail

ORANGE="\033[38;2;255;165;0m"
LEMON="\033[38;2;255;244;79m"
TAWNY="\033[38;2;204;78;0m"
HELIOTROPE="\033[38;2;223;115;255m"
VIOLET="\033[38;2;143;0;255m"
MINT="\033[38;2;152;255;152m"
AQUA="\033[38;2;18;254;202m"
TOMATO="\033[38;2;255;99;71m"
NC="\033[0m"

ARCH=${ARCH:-x86_64}
AXEL_VERSION="2.17.14"
ALPINE_VERSION="3.23.3"

## map arch to Alpine minirootfs URL and QEMU binary name
case "${ARCH}" in
  x86_64)
    ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-minirootfs-${ALPINE_VERSION}-x86_64.tar.gz"
    QEMU_ARCH=""
    ;;
  x86)
    ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86/alpine-minirootfs-${ALPINE_VERSION}-x86.tar.gz"
    QEMU_ARCH="i386"
    ;;
  aarch64)
    ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/aarch64/alpine-minirootfs-${ALPINE_VERSION}-aarch64.tar.gz"
    QEMU_ARCH="aarch64"
    ;;
  armhf)
    ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/armhf/alpine-minirootfs-${ALPINE_VERSION}-armhf.tar.gz"
    QEMU_ARCH="arm"
    ;;
  armv7)
    ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/armv7/alpine-minirootfs-${ALPINE_VERSION}-armv7.tar.gz"
    QEMU_ARCH="arm"
    ;;
  *)
    echo "Unknown architecture: ${ARCH}"
    exit 1
    ;;
esac

TARBALL="${ALPINE_URL##*/}"

## unmount filesystems on exit to avoid orphaned mounts
cleanup() {
  sudo umount -l ./pasta/proc/ 2>/dev/null || true
  sudo umount -l ./pasta/dev/  2>/dev/null || true
  sudo umount -l ./pasta/sys/  2>/dev/null || true
}
trap cleanup EXIT

## install all host dependencies in a single apt-get call
DEBIAN_DEPS="wget curl binutils"
if [ -n "${QEMU_ARCH}" ]; then
  DEBIAN_DEPS="${DEBIAN_DEPS} qemu-user-static"
fi
echo -e "${AQUA}= install dependencies${NC}"
sudo apt-get update -qy && sudo apt-get -y install ${DEBIAN_DEPS}

echo -e "${HELIOTROPE}= download alpine rootfs${NC}"
wget -c "${ALPINE_URL}"

echo -e "${MINT}= extract rootfs${NC}"
mkdir -p pasta
tar xf "${TARBALL}" -C pasta/

echo -e "${TOMATO}= copy resolv.conf into the folder${NC}"
cp /etc/resolv.conf ./pasta/etc/

echo -e "${TAWNY}= setup QEMU for cross-arch builds${NC}"
if [ -n "${QEMU_ARCH}" ]; then
  sudo mkdir -p ./pasta/usr/bin/
  sudo cp "/usr/bin/qemu-${QEMU_ARCH}-static" "./pasta/usr/bin/"
fi

echo -e "${VIOLET}= mount, bind and chroot into dir${NC}"
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
upx \
perl && curl -L -O 'https://github.com/axel-download-accelerator/axel/releases/download/v${AXEL_VERSION}/axel-${AXEL_VERSION}.tar.gz' && \
tar xf axel-${AXEL_VERSION}.tar.gz && \
cd axel-${AXEL_VERSION}/ && \
./configure CC=gcc LDFLAGS='-static' CFLAGS='-O3 -Wno-unterminated-string-initialization' && \
make -j\$(nproc) && \
strip axel && \
upx --ultra-brute axel"

if [ ! -f "./pasta/axel-${AXEL_VERSION}/axel" ]; then
  echo "Error: axel binary not found after build" >&2
  exit 1
fi

mkdir -p dist
cp "./pasta/axel-${AXEL_VERSION}/axel" "dist/axel-${ARCH}"
tar -C dist -cJf "dist/axel-${ARCH}.tar.xz" "axel-${ARCH}"
echo -e "${LEMON}= All done!${NC}"
