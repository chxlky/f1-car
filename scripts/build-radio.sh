#!/bin/bash

BUILD_MODE=""
for a in "$@"; do
  if [ "$a" = "--release" ]; then
    BUILD_MODE="--release"
    break
  fi
done

export PKG_CONFIG_SYSROOT_DIR="/usr/aarch64-linux-gnu/lib/musl"
export PKG_CONFIG_PATH="/usr/aarch64-linux-gnu/lib/musl/lib/pkgconfig"

cargo build $BUILD_MODE -p radio --target aarch64-unknown-linux-musl
