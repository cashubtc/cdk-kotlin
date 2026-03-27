#!/bin/bash
set -e

echo "Building CDK Kotlin bindings for Android..."

# Check required environment variables
if [ -z "$ANDROID_SDK_ROOT" ]; then
    echo "Error: ANDROID_SDK_ROOT environment variable is not set"
    echo "Please set it to your Android SDK installation directory"
    echo "Example: export ANDROID_SDK_ROOT=~/Library/Android/sdk"
    exit 1
fi

if [ -z "$ANDROID_NDK_ROOT" ]; then
    echo "Error: ANDROID_NDK_ROOT environment variable is not set"
    echo "Please set it to your Android NDK installation directory"
    echo "Example: export ANDROID_NDK_ROOT=\$ANDROID_SDK_ROOT/ndk/27.2.12479018"
    exit 1
fi

# Verify NDK directory exists
if [ ! -d "$ANDROID_NDK_ROOT" ]; then
    echo "Error: Android NDK directory not found at: $ANDROID_NDK_ROOT"
    echo "Please verify your ANDROID_NDK_ROOT environment variable"
    exit 1
fi

echo "Using Android SDK: $ANDROID_SDK_ROOT"
echo "Using Android NDK: $ANDROID_NDK_ROOT"

# Detect host architecture
HOST_OS=$(uname -s | tr '[:upper:]' '[:lower:]')
HOST_ARCH=$(uname -m)

case "$HOST_OS" in
    darwin*)
        if [ "$HOST_ARCH" = "arm64" ]; then
            NDK_HOST="darwin-x86_64"  # NDK still uses x86_64 binaries on Apple Silicon
        else
            NDK_HOST="darwin-x86_64"
        fi
        ;;
    linux*)
        if [ "$HOST_ARCH" = "x86_64" ]; then
            NDK_HOST="linux-x86_64"
        else
            echo "Error: Unsupported Linux architecture: $HOST_ARCH"
            exit 1
        fi
        ;;
    *)
        echo "Error: Unsupported host OS: $HOST_OS"
        exit 1
        ;;
esac

NDK_TOOLCHAIN_ROOT="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${NDK_HOST}"

# Verify toolchain exists
if [ ! -d "$NDK_TOOLCHAIN_ROOT" ]; then
    echo "Error: NDK toolchain not found at: $NDK_TOOLCHAIN_ROOT"
    echo "Available toolchains:"
    ls -la "${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/" 2>/dev/null || echo "  None found"
    exit 1
fi

echo "Using NDK toolchain: $NDK_TOOLCHAIN_ROOT"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Find CDK FFI directory - check multiple possible locations
if [ -d "${SCRIPT_DIR}/../cdk/crates/cdk-ffi" ]; then
    # GitHub Actions or local cdk directory
    CDK_FFI_DIR="${SCRIPT_DIR}/../cdk/crates/cdk-ffi"
elif [ -d "${SCRIPT_DIR}/../../cdk/crates/cdk-ffi" ]; then
    # Local development setup (cdk at same level as cdk-kotlin)
    CDK_FFI_DIR="${SCRIPT_DIR}/../../cdk/crates/cdk-ffi"
elif [ -d "${SCRIPT_DIR}/../../cdk.git/crates/cdk-ffi" ]; then
    # Local development with .git in repo name
    CDK_FFI_DIR="${SCRIPT_DIR}/../../cdk.git/crates/cdk-ffi"
else
    echo "Error: CDK FFI directory not found"
    echo "Checked locations:"
    echo "  ${SCRIPT_DIR}/../cdk/crates/cdk-ffi"
    echo "  ${SCRIPT_DIR}/../../cdk/crates/cdk-ffi"
    echo "  ${SCRIPT_DIR}/../../cdk.git/crates/cdk-ffi"
    echo "Please ensure the CDK repository is cloned in one of these locations"
    exit 1
fi

ANDROID_MAIN="${SCRIPT_DIR}/../lib/src/main"
JNI_LIBS="${ANDROID_MAIN}/jniLibs"

echo "Using CDK FFI directory: $CDK_FFI_DIR"

# Create directories if they don't exist
mkdir -p "${JNI_LIBS}/arm64-v8a"
mkdir -p "${JNI_LIBS}/armeabi-v7a"
mkdir -p "${JNI_LIBS}/x86_64"
mkdir -p "${ANDROID_MAIN}/kotlin"

cd "$CDK_FFI_DIR"

# Build for ARM64 (without postgres/npubcash, but with bip353)
echo "Building for ARM64..."
CC_aarch64_linux_android="${NDK_TOOLCHAIN_ROOT}/bin/aarch64-linux-android24-clang" \
CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="${NDK_TOOLCHAIN_ROOT}/bin/aarch64-linux-android24-clang" \
CARGO_TARGET_AARCH64_LINUX_ANDROID_AR="${NDK_TOOLCHAIN_ROOT}/bin/llvm-ar" \
AR_aarch64_linux_android="${NDK_TOOLCHAIN_ROOT}/bin/llvm-ar" \
cargo build --target aarch64-linux-android --profile release-smaller --no-default-features --features bip353

# Build for x86_64 (without postgres/npubcash, but with bip353)
echo "Building for x86_64..."
CC_x86_64_linux_android="${NDK_TOOLCHAIN_ROOT}/bin/x86_64-linux-android24-clang" \
CARGO_TARGET_X86_64_LINUX_ANDROID_LINKER="${NDK_TOOLCHAIN_ROOT}/bin/x86_64-linux-android24-clang" \
CARGO_TARGET_X86_64_LINUX_ANDROID_AR="${NDK_TOOLCHAIN_ROOT}/bin/llvm-ar" \
AR_x86_64_linux_android="${NDK_TOOLCHAIN_ROOT}/bin/llvm-ar" \
cargo build --target x86_64-linux-android --profile release-smaller --no-default-features --features bip353

# Build for ARMv7 (without postgres/npubcash, but with bip353)
echo "Building for ARMv7..."
CC_armv7_linux_androideabi="${NDK_TOOLCHAIN_ROOT}/bin/armv7a-linux-androideabi24-clang" \
CARGO_TARGET_ARMV7_LINUX_ANDROIDEABI_LINKER="${NDK_TOOLCHAIN_ROOT}/bin/armv7a-linux-androideabi24-clang" \
CARGO_TARGET_ARMV7_LINUX_ANDROIDEABI_AR="${NDK_TOOLCHAIN_ROOT}/bin/llvm-ar" \
AR_armv7_linux_androideabi="${NDK_TOOLCHAIN_ROOT}/bin/llvm-ar" \
cargo build --target armv7-linux-androideabi --profile release-smaller --no-default-features --features bip353

# Determine target directory based on CDK FFI location
CDK_TARGET_DIR="${CDK_FFI_DIR}/../../target"

# Copy libraries to JNI directories
echo "Copying libraries..."
cp "${CDK_TARGET_DIR}/aarch64-linux-android/release-smaller/libcdk_ffi.so" "${JNI_LIBS}/arm64-v8a/"
cp "${CDK_TARGET_DIR}/x86_64-linux-android/release-smaller/libcdk_ffi.so" "${JNI_LIBS}/x86_64/"
cp "${CDK_TARGET_DIR}/armv7-linux-androideabi/release-smaller/libcdk_ffi.so" "${JNI_LIBS}/armeabi-v7a/"

# Generate Kotlin bindings
echo "Generating Kotlin bindings..."
cargo run --bin uniffi-bindgen generate \
    --language kotlin \
    --out-dir "${ANDROID_MAIN}/kotlin" \
    --library "${CDK_TARGET_DIR}/aarch64-linux-android/release-smaller/libcdk_ffi.so" \
    --no-format

echo "Build complete!"
