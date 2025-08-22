{
  description = "Development environment for my F1 Car project (Flutter & Rust)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
    android-nixpkgs.url = "github:tadfisher/android-nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    rust-overlay,
    android-nixpkgs,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        overlays = [(import rust-overlay)];
        pkgs = import nixpkgs {
          inherit system overlays;
          config = {
            allowUnsupportedSystem = true;
            allowUnfree = true;
          };
        };

        androidSdk = android-nixpkgs.sdk.${system} (sdkPkgs:
          with sdkPkgs; [
            cmdline-tools-latest
            build-tools-36-0-0
            platform-tools
            platforms-android-28
            platforms-android-29
            platforms-android-30
            platforms-android-31
            platforms-android-32
            platforms-android-33
            platforms-android-34
            platforms-android-35
            platforms-android-36
            ndk-27-0-12077973
            emulator
            cmake-3-22-1
          ]);

        rpi4bCrossPkgs = pkgs.pkgsCross.aarch64-multiplatform-musl;
        stm32CrossPkgs = pkgs.pkgsCross.arm-embedded;

        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = ["rust-src" "rust-analyzer"];
          targets = [
            "aarch64-unknown-linux-musl" # Raspberry Pi 4B
            "thumbv7em-none-eabihf" # STM32F4
            "aarch64-linux-android"
            "x86_64-linux-android"
          ];
        };

        rustPlatform = pkgs.makeRustPlatform {
          cargo = rustToolchain;
          rustc = rustToolchain;
        };
      in {
        devShells.default = pkgs.mkShell {
          name = "f1-car-shell";
          packages = with pkgs; [
            rustToolchain
            pkg-config
            openssl
            nodejs
            bun
            jdk17

            # Development tools
            probe-rs-tools
            cargo-binutils
            cargo-tauri
            llvm
            gdb
            elfutils
            usbutils
            gcc-arm-embedded
            flip-link
            nixpkgs-fmt
            just
            ffmpeg_6

            # Tauri build inputs
            gobject-introspection
            at-spi2-atk
            atkmm
            cairo
            gdk-pixbuf
            glib
            glib-networking
            gtk3
            harfbuzz
            librsvg
            libsoup_3
            pango
            webkitgtk_4_1
            libayatana-appindicator
            pipewire
            libjack2
            libusb1
            stdenv.cc.cc.lib

            # Android SDK from android-nixpkgs
            androidSdk

            # Cross-compilers and libs
            zlib
            glibc
            rpi4bCrossPkgs.stdenv.cc
            stm32CrossPkgs.stdenv.cc
          ];

          shellHook = ''
            echo "Dev environment for f1-car ready! 🚀"

            # Set linker environment variables for cross-compilation
            export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_LINKER=${rpi4bCrossPkgs.stdenv.cc}/bin/aarch64-unknown-linux-musl-gcc
            export CARGO_TARGET_THUMBV7EM_NONE_EABIHF_LINKER=${stm32CrossPkgs.stdenv.cc}/bin/arm-none-eabi-gcc

            # Allow cross-compilation for tools like pkg-config
            export PKG_CONFIG_ALLOW_CROSS=1
            export NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1

            # Set Android environment variables from android-nixpkgs
            export ANDROID_SDK_ROOT=${androidSdk}
            export ANDROID_HOME=${androidSdk}

            # Try to set NDK paths if present under $ANDROID_SDK_ROOT/share/android-sdk/ndk
            ndk_version_dir=$(find "''${ANDROID_SDK_ROOT}/share/android-sdk/ndk" -mindepth 1 -maxdepth 1 -type d -regex ".*/[0-9.]+" | head -n1)
            if [ -n "$ndk_version_dir" ]; then
              export NDK_HOME="$ndk_version_dir"
              export ANDROID_NDK_ROOT="$ndk_version_dir"
              echo "Set NDK_HOME and ANDROID_NDK_ROOT to $ndk_version_dir"
            else
              echo "No NDK version directory found in $ANDROID_SDK_ROOT/share/android-sdk/ndk"
            fi
          '';
        };

        packages = {
          radio = rustPlatform.buildRustPackage {
            pname = "f1-radio";
            version = "0.1.0";
            src = ./.;
            cargoLock.lockFile = ./Cargo.lock;
            cargoBuildFlags = ["--bin" "radio"];
            CARGO_BUILD_TARGET = "aarch64-unknown-linux-musl";
            CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_LINKER = "${rpi4bCrossPkgs.stdenv.cc}/bin/aarch64-unknown-linux-musl-gcc";
            nativeBuildInputs = with pkgs; [
              pkg-config
              rpi4bCrossPkgs.stdenv.cc
            ];
            buildPhase = ''
              runHook preBuild
              echo "Cross-compiling radio for ARM..."
              export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_LINKER=${rpi4bCrossPkgs.stdenv.cc}/bin/aarch64-unknown-linux-musl-gcc
              cargo build --target aarch64-unknown-linux-musl --release --bin radio
              runHook postBuild
            '';
            installPhase = ''
              runHook preInstall
              mkdir -p $out/bin
              cp target/aarch64-unknown-linux-musl/release/radio $out/bin/
              runHook postInstall
            '';
            PKG_CONFIG_ALLOW_CROSS = "1";
            NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM = "1";
          };
        };
      }
    );
}
