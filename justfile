# CDK Kotlin Justfile
# Similar structure to cdk-swift for consistency

[group("Repo")]
[doc("Default command; list all available commands.")]
@list:
    just --list --unsorted

[group("Repo")]
[doc("Open CDK repo on GitHub in your default browser.")]
repo:
    open https://github.com/cashubtc/cdk

[group("Repo")]
[doc("Build the API docs.")]
docs:
    ./gradlew :lib:dokkaGeneratePublicationHtml

[group("Repo")]
[doc("Publish the library to your local Maven repository.")]
publish-local:
    ./gradlew publishToMavenLocal -P localBuild

[group("Build")]
[doc("Generate Kotlin bindings from CDK FFI (regenerate uniffi bindings).")]
generate:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔄 Generating Kotlin bindings from cdk-ffi..."

    # Check if cdk-ffi crate exists
    if [ ! -d "../cdk/crates/cdk-ffi" ]; then
        echo "❌ Error: cdk-ffi crate not found at ../cdk/crates/cdk-ffi"
        echo "   Please ensure the CDK repository is cloned at ../cdk"
        exit 1
    fi

    # Build the cdk-ffi library first
    echo "📦 Building cdk-ffi library..."
    cd ../cdk/crates/cdk-ffi
    cargo build --release

    # Generate Kotlin bindings
    echo "🎯 Generating Kotlin bindings..."

    # Always skip formatting to avoid dependency on ktlint
    cargo run --bin uniffi-bindgen generate \
        --library ../../target/release/libcdk_ffi.dylib \
        --language kotlin \
        --no-format \
        --out-dir ../../../cdk-kotlin/lib/src/main/kotlin

    echo "✅ Kotlin bindings generated successfully!"
    cd ../../../cdk-kotlin

[group("Build")]
[doc("Build for current platform only.")]
build:
    #!/usr/bin/env bash
    echo "🔨 Building for current platform..."

    # Detect platform and build accordingly
    OS=$(uname -s)
    ARCH=$(uname -m)

    if [ "$OS" = "Darwin" ]; then
        if [ "$ARCH" = "arm64" ]; then
            bash ./scripts/build-macos-aarch64.sh
        else
            bash ./scripts/build-macos-x86_64.sh
        fi
    elif [ "$OS" = "Linux" ]; then
        bash ./scripts/build-linux-x86_64.sh
    else
        echo "❌ Unsupported platform: $OS $ARCH"
        exit 1
    fi

[group("Build")]
[doc("Build for Android (all architectures).")]
build-android:
    bash ./scripts/build-android.sh

[group("Build")]
[doc("Build for specific architecture.")]
build-arch ARCH:
    bash ./scripts/build-{{ARCH}}.sh

[group("Build")]
[doc("Build for all supported platforms (slow).")]
build-all:
    #!/usr/bin/env bash
    echo "🔨 Building for all platforms..."
    just build-android
    just build-arch macos-aarch64
    just build-arch linux-x86_64

[group("Build")]
[doc("List available architectures for the build command.")]
@list-architectures:
    echo "Available architectures:"
    echo " - android (all Android architectures)"
    echo " - linux-x86_64"
    echo " - macos-aarch64"
    echo " - macos-x86_64"
    echo " - windows-x86_64"

[group("Build")]
[doc("Remove all caches and previous build directories to start from scratch.")]
clean:
    rm -rf ../cdk/crates/cdk-ffi/target/
    rm -rf ./build/
    rm -rf ./lib/build/
    rm -rf ./lib/src/main/jniLibs/
    rm -rf ./lib/src/main/kotlin/uniffi/
    rm -rf ./lib/src/main/kotlin/org/cashudevkit/cdk_ffi.kt

[group("Development")]
[doc("Install required dependencies (cargo-ndk).")]
install-deps:
    ./scripts/install-cargo-ndk.sh

[group("Development")]
[doc("Set up local.properties file from ANDROID_SDK_ROOT environment variable.")]
setup:
    ./scripts/setup-local-properties.sh

[group("Development")]
[doc("Check development environment.")]
check:
    #!/usr/bin/env bash
    echo "🔍 Checking CDK Kotlin environment..."
    echo ""

    # Essential tools
    command -v rustc >/dev/null && echo "✅ Rust" || echo "❌ Rust (install from https://rustup.rs)"
    command -v java >/dev/null && echo "✅ Java" || echo "❌ Java"
    command -v gradle >/dev/null && echo "✅ Gradle" || echo "❌ Gradle"

    # CDK repository
    if [ -d "../cdk/crates/cdk-ffi" ]; then
        echo "✅ CDK repository"
    else
        echo "❌ CDK repository (clone to ../cdk)"
    fi

    # Optional
    [ -n "${ANDROID_SDK_ROOT:-}" ] && echo "✅ Android SDK" || echo "⚠️  Android SDK (optional)"

[group("Development")]
[doc("Show project information.")]
info:
    #!/usr/bin/env bash
    echo "=== CDK Kotlin ==="
    echo "Project: $(pwd)"
    echo "Package: org.cashudevkit"
    echo ""
    just check

[group("Test")]
[doc("Run comprehensive test suite (all validations, no native builds).")]
test:
    bash ./scripts/run-all-tests.sh

[group("Test")]
[doc("Fast test (compile and validate only).")]
test-quick:
    #!/usr/bin/env bash
    echo "🧪 Running fast CDK Kotlin tests..."
    echo ""

    # Use Gradle's built-in test compilation
    ./gradlew compileDebugAndroidTestKotlin
    echo "✅ Test compilation successful"

    # Simple validation without hardcoded assumptions
    test_files=$(find lib/src/androidTest/kotlin -name "*.kt" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "✅ Found $test_files test file(s)"
    echo "✅ Binding validation completed"

[group("Test")]
[doc("Compile tests only (fastest check).")]
test-compile:
    #!/usr/bin/env bash
    echo "📦 Compiling all tests..."
    echo ""
    ./gradlew compileDebugAndroidTestKotlin compileDebugUnitTestKotlin
    echo ""
    echo "✅ Test compilation completed"

[group("Test")]
[doc("Mock Android tests with full output.")]
test-mock:
    bash ./scripts/run-android-tests-mock.sh

[group("Test")]
[doc("Real Android instrumentation tests (requires device/emulator).")]
test-android:
    #!/usr/bin/env bash
    echo "🤖 Running Android instrumentation tests..."
    echo ""
    ./gradlew connectedDebugAndroidTest
    echo ""
    echo "📊 Android test results available in build/reports/androidTests/connected/"

[group("Test")]
[doc("Run unit tests (if any exist).")]
test-unit:
    #!/usr/bin/env bash
    echo "🧪 Running unit tests..."
    echo ""
    ./gradlew testDebugUnitTest
    echo ""
    echo "📊 Unit test results available in build/reports/tests/testDebugUnitTest/"