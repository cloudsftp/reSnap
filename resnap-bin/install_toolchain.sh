#!/bin/bash

host_arch="x86_64"
toolchain_name="arm-gnu-toolchain-12.3.rel1-$host_arch-arm-none-linux-gnueabihf"
toolchain_archive="$toolchain_name.tar.xz"

wget https://developer.arm.com/-/media/Files/downloads/gnu/12.3.rel1/binrel/$toolchain_archive
tar xfJ $toolchain_archive
mv $toolchain_name arm-gnu-toolchain
