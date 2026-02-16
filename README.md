# CDK Kotlin

Kotlin/Android bindings for the Cashu Development Kit (CDK).

## Requirements

- Android SDK with Build-Tools for API level 24 or higher
- Android NDK (for building from source)
- Rust toolchain with `cargo` (for building from source)

## Environment Setup

Before building, set up the following environment variables:

```bash
export ANDROID_SDK_ROOT=~/Library/Android/sdk
export ANDROID_NDK_ROOT=$ANDROID_SDK_ROOT/ndk/<your-ndk-version>
```

Replace `<your-ndk-version>` with your installed NDK version.

## Installation

### From Maven Repository

Add the dependency to your app's `build.gradle.kts`:

```kotlin
dependencies {
    implementation("org.cashudevkit:cdk-kotlin:0.15.0-rc.3")
}
```

### Building from Source

1. Set up environment variables (see Environment Setup section above)
2. Set up and build:
   ```bash
   just setup
   just install-deps
   just build-android
   just publish-local
   ```

## Usage

```kotlin
import org.cashudevkit.*
import kotlinx.coroutines.runBlocking

// Create an in-memory database
val database = runBlocking { WalletSqliteDatabase.newInMemory() }

// Configure the wallet
val config = WalletConfig(targetProofCount = 10u)
val mnemonic = generateMnemonic()

// Create wallet instance
val wallet = Wallet(
    mintUrl = "https://testmint.cashu.space",
    unit = CurrencyUnit.Sat,
    mnemonic = mnemonic,
    db = database,
    config = config
)

// Create a mint quote for 1000 sats
val amount = Amount(value = 1000UL)
val mintQuote = wallet.mintQuote(
    amount = amount,
    description = "Test mint quote"
)

// Check wallet balance
val balance = wallet.totalBalance()
println("Wallet balance: ${balance.value} sats")

// Clean up resources
wallet.close()
database.close()
```

## Architecture Support

The library includes native binaries for the following Android architectures:
- arm64-v8a (64-bit ARM)
- armeabi-v7a (32-bit ARM)
- x86 (32-bit Intel/AMD)
- x86_64 (64-bit Intel/AMD)


## Development

### Generating Bindings

To regenerate Kotlin bindings from the CDK FFI:

```bash
just generate
```

This updates the auto-generated `cdk_ffi.kt` file with the latest bindings.

### Running Tests

```bash
just test
```

### Publishing Setup

For maintainers publishing to Maven Central, see [`CENTRAL_PORTAL_SETUP.md`](./CENTRAL_PORTAL_SETUP.md) for detailed instructions on setting up Central Portal credentials.

## License

This project is licensed under the MIT License.