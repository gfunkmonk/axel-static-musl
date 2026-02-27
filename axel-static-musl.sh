#!/bin/bash
set -euo pipefail

##install some dependencies
sudo apt -y install wget curl binutils

##download alpine rootfs
wget -c "https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/alpine-minirootfs-3.22.2-x86_64.tar.gz"

##extract rootfs
mkdir pasta
tar xf alpine-minirootfs-3.22.2-x86_64.tar.gz -C pasta/

##copy resolv.conf into the folder
cp /etc/resolv.conf ./pasta/etc/

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
make -j\$(nproc)"
mkdir -p dist
cp ./pasta/axel-2.17.14/axel dist/
strip dist/axel
tar -C dist -cJf dist/axel.tar.xz axel
