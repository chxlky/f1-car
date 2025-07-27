{
  description = "Development environment for my F1 Car project (Flutter & Rust)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    rust-overlay,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        overlays = [(import rust-overlay)];
        pkgs = import nixpkgs {
          inherit system overlays;
          config = {
            allowUnsupportedSystem = true;
            android_sdk.accept_license = true;
            allowUnfree = true;
          };
        };

        buildToolsVersions = "34.0.0";
        androidComposition = pkgs.androidenv.composeAndroidPackages {
          buildToolsVersions = [buildToolsVersions];
          platformVersions = ["23" "29" "30" "31" "32" "33" "34" "35" "28"];
          abiVersions = ["armeabi-v7a" "arm64-v8a"];
          includeNDK = true;
          ndkVersions = ["27.0.12077973" "26.3.11579264"];
          cmakeVersions = ["3.22.1"];
        };
        androidSdk = androidComposition.androidsdk;

        rpi4bCrossPkgs = pkgs.pkgsCross.aarch64-multiplatform-musl;
        stm32CrossPkgs = pkgs.pkgsCross.arm-embedded;

        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = ["rust-src" "rust-analyzer"];
          targets = [
            "aarch64-unknown-linux-musl" # Raspberry Pi 4B
            "thumbv7em-none-eabihf" # STM32F4
          ];
        };

        rustPlatform = pkgs.makeRustPlatform {
          cargo = rustToolchain;
          rustc = rustToolchain;
        };

        # Consolidated list of all development packages
        devPackages = with pkgs; [
          # Rust Development Tools
          rustToolchain
          pkg-config
          openssl
          probe-rs-tools
          cargo-binutils
          cargo-expand
          llvm
          gdb
          elfutils
          usbutils
          gcc-arm-embedded
          flip-link
          nixpkgs-fmt
          cmake
          protoc-gen-prost
          just

          # Android Development Tools (for Flutter Android)
          jdk17 # Java Development Kit
          androidSdk # Android SDK, including build-tools, platforms, NDK

          # Flutter and its native dependencies
          flutter # The Flutter SDK
          xorg.libXcursor
          xorg.libXi
          xorg.libXrandr
          udev
          alsa-lib
          libxkbcommon
          zlib
          libayatana-appindicator
          gtk3
          wayland
          openssl
          openssl.dev
          libsigcxx
          stdenv.cc # C/C++ compiler for native compilation
          gnumake
          binutils
          ncurses5
          libGLU
          libGL
          gcc-unwrapped # GCC compiler
          clang # Clang compiler
          ninja # Build system for C/C++
          llvmPackages.libclang # Clang library for tooling
          glibc_multi # GNU C Library (multi-arch)
          lld # LLVM linker
          mold # Modern linker

          # Cross-compilation toolchains
          rpi4bCrossPkgs.stdenv.cc # GCC for aarch64-unknown-linux-musl
          stm32CrossPkgs.stdenv.cc # GCC for arm-none-eabi
        ];

      in {
        devShells.default = pkgs.mkShell {
          packages = devPackages;

          # Environment variables and shell hooks
          enterShell = ''
            echo "Dev shell for f1-car ready with Flutter & Rust cross-compilation!"
            echo "Available Rust targets:"
            echo "  - aarch64-unknown-linux-musl (Raspberry Pi 4B)"
            echo "  - thumbv7em-none-eabihf (STM32F4)"

            # Set linker environment variables for manual `cargo build --target`
            export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_LINKER=${rpi4bCrossPkgs.stdenv.cc}/bin/aarch64-unknown-linux-musl-gcc
            export CARGO_TARGET_THUMBV7EM_NONE_EABIHF_LINKER=${stm32CrossPkgs.stdenv.cc}/bin/arm-none-eabi-gcc

            # Allow cross-compilation for pkg-config and unsupported systems
            export PKG_CONFIG_ALLOW_CROSS=1
            export NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1

            # Android and Flutter configuration
            export ANDROID_HOME="${androidSdk}/libexec/android-sdk"
            export ANDROID_SDK_ROOT="${androidSdk}/libexec/android-sdk"
            # Dynamically find the NDK root (assumes one NDK version per ls -1)
            export ANDROID_NDK_ROOT="$ANDROID_SDK_ROOT/ndk/$(ls -1 $ANDROID_SDK_ROOT/ndk | head -n 1)"
            export NDK_HOME="$ANDROID_NDK_ROOT" # For compatibility with tools that might use NDK_HOME
            export FLUTTER_ROOT="${pkgs.flutter}" # Set FLUTTER_ROOT to the Nix-provided Flutter SDK

            # Gradle options for Android builds
            export GRADLE_OPTS="-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidSdk}/libexec/android-sdk/build-tools/${buildToolsVersions}/aapt2"

            # Ensure Flutter is in PATH (devenv usually handles this, but explicit is safer)
            export PATH="$FLUTTER_ROOT/bin:$PATH"

            # Run flutter doctor to verify setup (optional, but good for first time)
            flutter doctor --android-licenses # Accept licenses if prompted
            flutter doctor
          '';
        };

        packages = {
          radio = rustPlatform.buildRustPackage {
            pname = "f1-radio";
            version = "0.1.0";
            src = ./.; # Assuming 'radio' is built from the root or this is a placeholder
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