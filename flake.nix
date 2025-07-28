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
        cmakeVersion = "3.22.1";
        ndkVersion = "27.0.12077973";
        androidEnv = pkgs.androidenv.override {licenseAccepted = true;};
        androidComposition = androidEnv.composeAndroidPackages {
          cmdLineToolsVersion = "9.0";
          toolsVersion = "26.1.1";
          platformToolsVersion = "35.0.2";
          buildToolsVersions = [buildToolsVersions];
          platformVersions = ["23" "29" "30" "31" "32" "33" "34" "35" "28"];
          abiVersions = ["armeabi-v7a" "arm64-v8a"];
          cmakeVersions = [cmakeVersion];
          ndkVersions = [ndkVersion];
          includeNDK = true;
          includeSources = false;
          includeSystemImages = false;
          includeEmulator = false;
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

        flutterBuildInputs = with pkgs; [
          xorg.libXcursor
          xorg.libXi
          xorg.libXrandr
          udev
          alsa-lib
          libxkbcommon
          zlib
          jdk17
          androidSdk
          flutter
          libayatana-appindicator
          gtk3
          wayland
          openssl
          openssl.dev
        ];

        flutterNativeBuildInputs = with pkgs; [
          libsigcxx
          stdenv.cc
          gnumake
          binutils
          ncurses5
          libGLU
          libGL
          pkg-config
          gcc-unwrapped
          clang
          ninja
          llvmPackages.libclang
          glibc_multi
          lld
        ];

        devPackages = with pkgs;
          [
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
            google-chrome
          ]
          ++ flutterBuildInputs ++ flutterNativeBuildInputs;
      in {
        devShells.default = pkgs.mkShell {
          packages =
            devPackages
            ++ [
              rpi4bCrossPkgs.stdenv.cc
              stm32CrossPkgs.stdenv.cc
            ];

          # Environment variables and shell hooks
          shellHook = ''
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
            export ANDROID_SDK_ROOT="${androidSdk}/libexec/android-sdk"
            export ANDROID_HOME="$ANDROID_SDK_ROOT"
            export ANDROID_NDK_ROOT="$ANDROID_SDK_ROOT/ndk-bundle"
            export FLUTTER_ROOT="${pkgs.flutter}"

            # Gradle options for Android builds
            export GRADLE_OPTS="-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidSdk}/libexec/android-sdk/build-tools/${buildToolsVersions}/aapt2 -Dandroid.cmake.dir=$ANDROID_SDK_ROOT/cmake/${cmakeVersion}"

            # Point Flutter to the Chrome executable
            export CHROME_EXECUTABLE="${pkgs.google-chrome}/bin/google-chrome-stable"

            # Ensure Flutter is in PATH
            export PATH="$FLUTTER_ROOT/bin:$PATH"
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
