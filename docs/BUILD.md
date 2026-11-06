# Building Warpgate

How to set up, run, test and ship Warpgate on every platform. Each command can be pasted as is. Unless a step says otherwise, run commands from the repository root.

Commands marked **Verified** were run on macOS (Apple Silicon, Xcode 27.2, Flutter 3.47.7) while this guide was written. Commands marked **Not verified here** need a platform, device or account that machine did not have. They follow the official Flutter and vendor steps.

## 1. Requirements

### All platforms

| Tool | Version | Where it comes from |
|---|---|---|
| Flutter | 3.47 or later, **stable** channel | `pubspec.yaml` asks for Dart `^3.13.5`, which ships with Flutter 3.47.x. CI pins 3.47.7. |
| Dart | 3.13.5 or later | Bundled with Flutter. Do not install it separately. |
| Git | any recent | |
| Rust | stable, 1.85 or later, through **rustup** | <https://rustup.rs>. Builds the SSH and SFTP engine in `rust/`. Every platform build compiles it automatically. |

Install Flutter from <https://docs.flutter.dev/get-started/install>, then:

```sh
flutter channel stable
flutter upgrade
flutter --version        # Flutter 3.47.x • channel stable … Dart 3.13.x
```

### macOS and iOS (build on a Mac only)

- Xcode 16 or later from the App Store, then:

  ```sh
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  sudo xcodebuild -runFirstLaunch
  ```

- CocoaPods 1.16 or later: `brew install cocoapods`.
- Minimum OS versions in the project: macOS 12, iOS 15.

### Android

- Android Studio (latest stable), with these in **Settings → Languages & Frameworks → Android SDK**:
  - SDK Platforms: the latest Android API.
  - SDK Tools: Android SDK Build-Tools, Android SDK Command-line Tools, Android SDK Platform-Tools, NDK (Side by side), CMake.
- JDK **17 or 21**. The app compiles to Java 17 bytecode (`android/app/build.gradle.kts`), and the project uses Gradle 9.3.1 with Android Gradle Plugin 9.1. Android Studio's bundled JDK works. Point Flutter at it:

  ```sh
  flutter config --jdk-dir "/Applications/Android Studio.app/Contents/jbr/Contents/Home"   # macOS
  flutter config --jdk-dir "C:\Program Files\Android\Android Studio\jbr"                     # Windows
  ```

- Accept the licenses: `flutter doctor --android-licenses`.

### Windows

- Windows 10 or 11, 64-bit.
- Visual Studio 2022 (Community is fine) with the **Desktop development with C++** workload. It includes MSVC, the Windows SDK and CMake.
- Developer Mode on (Settings → System → For developers). Flutter plugins need symlinks.
- Long paths on (see [Troubleshooting](#7-troubleshooting)).

### Linux (Ubuntu or Debian)

```sh
sudo apt-get update
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev \
  liblzma-dev libstdc++-12-dev libsecret-1-dev gnome-keyring curl git unzip xz-utils zip
```

`libsecret-1-dev` is needed by `flutter_secure_storage` (passwords and keys). `gnome-keyring` (or KWallet with its Secret Service bridge) must be running when the app starts. GTK 3, CMake, Ninja and Clang build the runner.

### Check the setup

```sh
flutter doctor -v
```

Every platform you want to build needs a green check. Web is optional (see [Web](#web)). **Verified**.

## 2. First run

```sh
git clone <repository-url> warpgate
cd warpgate
flutter pub get
```

There is no code generation step. The project does not use `build_runner`: drift is used with document tables, so nothing is generated. The first build downloads a prebuilt SQLite library through the `sqlite3` package's build hook, so that build needs network access.

List devices, then run:

```sh
flutter devices
flutter run -d macos
flutter run -d windows
flutter run -d linux
flutter run -d <android-device-id>
flutter run -d <ios-device-id>
```

Find the device id in the second column of `flutter devices`. For Android, enable **Developer options → USB debugging** on the phone and connect it with a cable. For iOS, see [iOS](#ios). `flutter pub get`, `flutter devices` and `flutter run -d macos` are **Verified**.

## 3. Development

- **Hot reload**: press `r` in the terminal running `flutter run`. Press `R` for hot restart and `q` to quit. Hot reload keeps the app state, but changes to `main()`, provider overrides and native code (Swift, C++, Kotlin, Gradle, CMake) need a full restart or a rebuild.
- **Analyzer** (must report zero issues): `flutter analyze`. **Verified**.
- **Tests** (unit, widget, golden, accessibility): `flutter test`. **Verified**.
- **One file**: `flutter test test/widgets/title_bar_test.dart`.
- **Golden tests**: they live in `test/goldens` and use the bundled fonts. `screens_golden_test.dart` renders the session view (terminal + files), files, hosts, transfers, snippets (empty and filled), keys and settings at 900×600, 1280×800 and 1920×1080 in both themes, as macOS, into `test/goldens/screens`. After an intended visual change, update them and review the PNG diff before committing:

  ```sh
  flutter test --update-goldens test/goldens
  ```

- **Review screenshots** of every screen and of the desktop title bar variants, written to `test/screens/out`:

  ```sh
  WARPGATE_RENDER_SCREENS=1 flutter test test/screens --update-goldens
  ```

  **Verified** (title bar variants).

- **SSH integration tests** need a real `sshd`. The README shows a throwaway setup.
- **Format**: `dart format lib test`.

## 4. Release builds

### Android

Output: `build/app/outputs/flutter-apk/app-release.apk` and `build/app/outputs/bundle/release/app-release.aab`. **Not verified here** (no Android SDK on the machine used).

1. Create an upload keystore once and keep it outside the repository:

   ```sh
   keytool -genkey -v -keystore ~/warpgate-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. Create `android/key.properties`. Git already ignores it, along with `*.jks`.

   ```properties
   storePassword=<store password>
   keyPassword=<key password>
   keyAlias=upload
   storeFile=/Users/<you>/warpgate-upload.jks
   ```

   On Windows, write the path with forward slashes: `storeFile=C:/Users/<you>/warpgate-upload.jks`.

3. The signing config is already in `android/app/build.gradle.kts`. When `android/key.properties` exists, release builds are signed with it. Without it they fall back to the debug key, which is fine for testing but not accepted by Google Play.

4. Build:

   ```sh
   flutter build apk --release          # one APK for all ABIs
   flutter build apk --split-per-abi    # smaller APKs, one per ABI
   flutter build appbundle              # .aab for Google Play
   ```

5. Install on a phone with USB debugging on:

   ```sh
   flutter install -d <android-device-id>
   adb install -r build/app/outputs/flutter-apk/app-release.apk
   ```

### iOS

Output: `build/ios/ipa/*.ipa`. The unsigned build (`flutter build ios --release --no-codesign`) is **Verified**. Signing, device runs and upload are **Not verified here** (no Apple developer team on the machine used).

1. Open `ios/Runner.xcworkspace` in Xcode (the workspace, not the project).
2. Select **Runner → Signing & Capabilities**, tick **Automatically manage signing** and choose your **Team**. The bundle id is `eu.kwilex.warpgate`.
3. Run on a physical device: connect the iPhone, turn on **Settings → Privacy & Security → Developer Mode**, trust the computer, then:

   ```sh
   flutter run -d <ios-device-id> --release
   ```

   The first time, iOS asks you to trust the developer certificate in **Settings → General → VPN & Device Management**.

4. Build the archive and IPA:

   ```sh
   flutter build ipa --release
   ```

5. Upload to TestFlight, using either of these:
   - Open `build/ios/archive/Runner.xcarchive` in Xcode → **Distribute App → App Store Connect → Upload**.
   - Use the command line with an App Store Connect API key:

     ```sh
     xcrun altool --upload-app --type ios -f build/ios/ipa/*.ipa --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>
     ```

   Then add testers in App Store Connect → TestFlight once processing finishes.

### macOS

Output: `build/macos/Build/Products/Release/Warpgate.app`. The build, the ad-hoc signature check and the `.dmg` step are **Verified**. Developer ID signing and notarization are **Not verified here** (no Developer ID certificate).

```sh
flutter build macos --release
```

**Entitlements** (`macos/Runner/Release.entitlements`, already set):

| Key | Value | Why |
|---|---|---|
| `com.apple.security.app-sandbox` | `false` | The local terminal starts your login shell, and `~/.ssh/config` import reads your home folder |
| `com.apple.security.network.client` | `true` | SSH and SFTP connections |
| `com.apple.security.network.server` | `true` | The optional MCP server on `127.0.0.1` |
| `com.apple.security.files.user-selected.read-write` | `true` | Open and save panels |

Keychain: see [macOS keychain](#macos-keychain). Release builds need `macos/Runner/Configs/Signing.xcconfig` with your team, otherwise they are ad-hoc signed.

**Sign with Developer ID** (needs a "Developer ID Application" certificate in your keychain). Notarization requires the hardened runtime, so pass `--options runtime`:

```sh
APP=build/macos/Build/Products/Release/Warpgate.app
IDENTITY="Developer ID Application: <Your Name> (<TEAMID>)"
codesign --force --deep --options runtime --timestamp \
  --entitlements macos/Runner/Release.entitlements \
  --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
```

**Package as .dmg** with the built-in `hdiutil`:

```sh
mkdir -p dist/dmg && cp -R "$APP" dist/dmg/ && ln -sf /Applications dist/dmg/Applications
hdiutil create -volname Warpgate -srcfolder dist/dmg -ov -format UDZO dist/Warpgate.dmg
codesign --sign "$IDENTITY" --timestamp dist/Warpgate.dmg
```

**Notarize** with `notarytool`. Store the credentials once, using an app-specific password from appleid.apple.com:

```sh
xcrun notarytool store-credentials warpgate-notary --apple-id <you@example.com> --team-id <TEAMID> --password <app-specific-password>
xcrun notarytool submit dist/Warpgate.dmg --keychain-profile warpgate-notary --wait
xcrun stapler staple dist/Warpgate.dmg
spctl --assess --type open --context context:primary-signature -v dist/Warpgate.dmg
```

If `submit` reports `Invalid`, read the log with `xcrun notarytool log <submission-id> --keychain-profile warpgate-notary`.

### Windows

Output: `build\windows\x64\runner\Release\`. **Not verified here** (build on Windows).

```powershell
flutter build windows --release
```

Ship the **whole `Release` folder**: `warpgate.exe`, `flutter_windows.dll`, the plugin DLLs and the `data` folder. The exe does not run on its own.

**Installer with Inno Setup** (free, no extra Dart packages):

1. Install Inno Setup 6: `winget install JRSoftware.InnoSetup`.
2. Save this as `windows\installer.iss`:

   ```ini
   #define AppVersion "1.0.0"

   [Setup]
   AppId={{6C2E3B1A-7E3F-4F4B-9C61-1D7B2B0F5A11}
   AppName=Warpgate
   AppVersion={#AppVersion}
   AppPublisher=Warpgate
   DefaultDirName={autopf}\Warpgate
   DefaultGroupName=Warpgate
   OutputDir=..\dist
   OutputBaseFilename=Warpgate-{#AppVersion}-setup
   Compression=lzma2
   SolidCompression=yes
   ArchitecturesAllowed=x64compatible
   ArchitecturesInstallIn64BitMode=x64compatible
   SetupIconFile=runner\resources\app_icon.ico
   UninstallDisplayIcon={app}\warpgate.exe

   [Files]
   Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

   [Icons]
   Name: "{group}\Warpgate"; Filename: "{app}\warpgate.exe"
   Name: "{autodesktop}\Warpgate"; Filename: "{app}\warpgate.exe"; Tasks: desktopicon

   [Tasks]
   Name: desktopicon; Description: "Create a desktop shortcut"; Flags: unchecked

   [Run]
   Filename: "{app}\warpgate.exe"; Description: "Start Warpgate"; Flags: nowait postinstall skipifsilent
   ```

3. Build the installer: `& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" windows\installer.iss`. The result is `dist\Warpgate-1.0.0-setup.exe`.

**Code signing**: unsigned installers trigger SmartScreen warnings. Sign `warpgate.exe` before packaging and the setup exe after, with a code signing certificate (or Azure Trusted Signing):

```powershell
signtool sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 /a build\windows\x64\runner\Release\warpgate.exe
signtool sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 /a dist\Warpgate-1.0.0-setup.exe
```

`signtool` comes with the Windows SDK that Visual Studio installs.

### Linux

Output: `build/linux/x64/release/bundle/`. **Not verified here** (build on Linux).

```sh
flutter build linux --release
```

The `bundle` folder holds the `warpgate` binary, `lib/`, `data/` and `share/` (the `eu.kwilex.warpgate.desktop` entry and the 256 and 512 px icons from `linux/packaging`). Ship the whole folder. The window uses the bundled icon even when the app is not installed. On `arm64` machines the path is `build/linux/arm64/release/bundle/`.

**Package as .deb** with `dpkg-deb`, which is part of every Debian and Ubuntu system:

```sh
VERSION=1.0.0
PKG=dist/warpgate_${VERSION}_amd64
mkdir -p $PKG/DEBIAN $PKG/opt/warpgate $PKG/usr/bin $PKG/usr/share/applications $PKG/usr/share/icons/hicolor
cp -r build/linux/x64/release/bundle/* $PKG/opt/warpgate/
ln -sf /opt/warpgate/warpgate-cli $PKG/usr/bin/warpgate
cp -r build/linux/x64/release/bundle/share/icons/hicolor/. $PKG/usr/share/icons/hicolor/
cp linux/packaging/eu.kwilex.warpgate.desktop $PKG/usr/share/applications/
cat > $PKG/DEBIAN/control <<CONTROL
Package: warpgate
Version: ${VERSION}
Section: net
Priority: optional
Architecture: amd64
Depends: libgtk-3-0, libsecret-1-0, libsqlite3-0
Maintainer: kwilex
Description: SSH and SFTP workbench for many servers at once
CONTROL
dpkg-deb --build --root-owner-group $PKG
sudo apt install ./dist/warpgate_${VERSION}_amd64.deb
```

### Web

Not supported as an app. Browsers cannot open raw TCP sockets, so SSH would need a WebSocket proxy that sees every key and password. `lib/main_web.dart` builds a single page that explains this:

```sh
flutter build web -t lib/main_web.dart
```

Output: `build/web`. **Verified**.

### macOS keychain

**Why the prompt appears.** A keychain item remembers which app may read it through the app's *designated requirement*, a rule derived from its code signature. `flutter run` and unsigned builds are signed ad hoc, so the requirement is the hash of the binary, and it changes on every build. The next build is a different app as far as the keychain knows, so macOS asks "Warpgate wants to use your confidential information" again, once per item.

**What the app does about it.**

- Warpgate keeps one item in the keychain: a random 256-bit master key, `warpgate.master-key`. It is read once per launch, the first time a secret is needed, and kept in memory.
- Host passwords, private keys, key passphrases, the app PIN and the MCP token are encrypted with that key (AES-GCM, the secret name as associated data) and stored in the app database. So there is at most one keychain read per launch, and none at all if no secret is needed.
- On the first launch after this change, secrets from the old storage (one keychain item per secret) are copied into the encrypted store and the old items are deleted. That launch may ask once more on an unsigned build.

**Stop the prompts: sign every build with your team.** The signing settings live in a file that git ignores, so no team id or certificate name is committed.

```sh
cp macos/Runner/Configs/Signing.xcconfig.example macos/Runner/Configs/Signing.xcconfig
# edit DEVELOPMENT_TEAM: find it with
security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject   # OU=<TEAMID>
```

`Signing.xcconfig` signs Debug and Profile with **Apple Development** and Release with **Developer ID Application** (hardened runtime, timestamp). It is included from `AppInfo.xcconfig`, so `flutter run -d macos` and `flutter build macos` both use it. With a stable identity the designated requirement no longer changes, so after the first **Always Allow** (or none, for an item the app created itself) there are no more prompts. Check it with `codesign -d -r- build/macos/Build/Products/Debug/Warpgate.app`: the requirement must name `eu.kwilex.warpgate` and your certificate, not a `cdhash`. **Verified** with an Apple Development certificate.

**Optional: data protection keychain with an access group.** This ties the master key to the app id instead of the signature:

```sh
cp macos/Runner/Configs/KeychainGroup.xcconfig.example macos/Runner/Configs/KeychainGroup.xcconfig
```

It switches to `DebugProfile.Signed.entitlements` / `Release.Signed.entitlements`, which add `keychain-access-groups = $(AppIdentifierPrefix)eu.kwilex.warpgate`, and writes that group into `Info.plist` (`KeychainAccessGroup`). The app then stores the master key with `MacOsOptions(usesDataProtectionKeychain: true, groupId: <group>)`. The entitlement needs a provisioning profile, so build once from Xcode or pass `-allowProvisioningUpdates` to let Xcode register the App ID `eu.kwilex.warpgate` in your team. For Developer ID releases, create a Developer ID provisioning profile with the same group. If the group is missing at runtime (`errSecMissingEntitlement -34018`), the app falls back to the login keychain instead of failing. **Not verified here**: registering the App ID changes the developer account, so it was not done on the machine used.

Unsigned builds (CI, contributors without a team) keep the plain entitlement files and the login keychain. They work, but ask on every rebuild.

## The Rust engine

SSH, SFTP and port forwarding run in a Rust library, `rust/` (crate `warpgate_engine`, on [russh](https://crates.io/crates/russh) 0.65 and [russh-sftp](https://crates.io/crates/russh-sftp) 2.4, with the `ring` crypto backend). It replaced the pure Dart `dartssh2` engine for speed: on the same machine, a 1 GB SFTP download went from 1.6 MB/s to about 560 MB/s, and SSH encryption no longer runs on the window thread. `docs/PERFORMANCE.md` has the measurements. `dartssh2` stays in the app as a fallback engine (Settings, Diagnostics, SSH engine, or `WARPGATE_ENGINE=dart`).

**How the build is wired.**

| Piece | What it does |
|---|---|
| `rust/` | The crate. Its public API is in `rust/src/api/` (`ssh.rs`, `sftp.rs`, `util.rs`). |
| `rust/flutter_rust_bridge.yaml` | [flutter_rust_bridge](https://cjycode.com/flutter_rust_bridge/) 2.12 settings. The Dart bindings go to `packages/warpgate_core/lib/src/engine/`. |
| `packages/warpgate_engine/` | A Flutter FFI plugin built on [cargokit](https://github.com/irondash/cargokit). Every `flutter build` and `flutter run` compiles the crate for the target and bundles it: a static library linked into `warpgate_engine.framework` on macOS and iOS (arm64 and x86_64 on macOS), `libwarpgate_engine.so` for every Android ABI and on Linux, `warpgate_engine.dll` on Windows. |
| `packages/warpgate_core/lib/features/connection/engine/native_ssh.dart` | Classes that implement the `dartssh2` interfaces (`SSHClient`, `SSHSession`, `SftpClient`, `SftpFile`, `SSHForwardChannel`) on top of the engine, so the app, the CLI and the MCP server use either engine through the same calls. |

**Install the targets once.** cargokit adds missing targets through rustup by itself, but installing them up front makes the first build faster:

```sh
rustup target add aarch64-apple-darwin x86_64-apple-darwin          # macOS
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios   # iOS
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android i686-linux-android   # Android, needs the NDK
rustup target add x86_64-pc-windows-msvc                              # Windows, on Windows
rustup target add x86_64-unknown-linux-gnu                            # Linux, on Linux
```

**Change the engine API.** After editing `rust/src/api/`, regenerate the bindings. The script also removes the comments the generator writes, since the project keeps no comments in its sources:

```sh
cargo install flutter_rust_bridge_codegen --version 2.12.0 --locked
tool/engine_codegen.sh
```

**Check it.**

```sh
cd rust
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo build --release      # rust/target/release/libwarpgate_engine.{dylib,so} or warpgate_engine.dll
```

**The command line uses the same library.** The CLI looks for the engine next to its own binary: `../Frameworks/warpgate_engine.framework` inside `Warpgate.app` on macOS, `warpgate_engine.dll` next to `warpgate-cli.exe` on Windows, `lib/libwarpgate_engine.so` in the Linux bundle. For a CLI built by hand, point at the library with `WARPGATE_ENGINE_LIBRARY=/path/to/libwarpgate_engine.dylib`. When no library is found, the CLI uses `dartssh2`, which still works, only slower.

**Memory and ownership across the boundary.** Reads are pulled by Dart one batch at a time (at most 256 KB per call), so no queue between Rust and Dart can grow. When Dart stops reading, russh stops reading the connection, and the server stops sending once its window is used. SFTP keeps at most 32 reads or 16 writes of 255 KB in flight per file. Every handle (`SshClient`, `SshChannel`, `SftpSession`, `SftpFile`) is a Rust object owned by its Dart wrapper. Closing the wrapper closes it in Rust, and a Dart finalizer drops anything that was not closed. `connect` takes a `CancelToken`.

## Building the command line

The CLI is a Dart program in `packages/warpgate_cli`. It shares `packages/warpgate_core` with the app and has no Flutter in it.

```sh
cd packages/warpgate_cli
dart pub get
dart compile exe bin/warpgate.dart -o build/warpgate
build/warpgate --help
```

These packages are deliberately not a pub workspace. `dart compile exe` refuses any package graph with build hooks, and the app's `sqlite3` package has one. The CLI talks to the system SQLite through `dart:ffi` instead.

**Every desktop build includes it.**

| Platform | How | Where |
|---|---|---|
| macOS | Xcode build phase running `tool/build_cli_macos.sh` | `Warpgate.app/Contents/MacOS/warpgate-cli`, signed with the app's identity |
| Windows | `warpgate_cli` target in `windows/CMakeLists.txt` | `warpgate-cli.exe` next to `warpgate.exe` |
| Linux | `warpgate_cli` target in `linux/CMakeLists.txt` | `warpgate-cli` in the bundle |

**macOS signing.** A `dart compile exe` binary under the hardened runtime needs `com.apple.security.cs.allow-unsigned-executable-memory`, or macOS kills it at launch with exit code 137. `macos/Runner/WarpgateCli.entitlements` holds it. `allow-jit` is not enough.

The keychain group is applied only when `WARPGATE_KEYCHAIN_GROUP` is set and the bundle has an `embedded.provisionprofile`, because a binary with `keychain-access-groups` and no profile is killed at launch too. Without the group the CLI gets secrets from the running app, then from the login keychain, where macOS may ask once.

**Putting it on PATH.**

- Settings → Command line, or `warpgate-cli --install`. On macOS and Linux this makes a link in `/usr/local/bin` when that folder is writable, otherwise in `~/.local/bin`. On Windows it writes `%LOCALAPPDATA%\Warpgate\bin\warpgate.cmd` and adds that folder to the user PATH.
- `.deb`: the steps under Linux above link `/usr/bin/warpgate` to it.
- AppImage: an AppImage cannot add to PATH. Tell users to run `warpgate-cli --install` from an extracted copy, or link it by hand.
- Windows installer: the Inno Setup script picks it up with the rest of the Release folder. Installing it on PATH stays a user choice in Settings. For MSIX, add an `appExecutionAlias` named `warpgate.exe` pointing at `warpgate-cli.exe`.
- Mobile has no CLI, and the settings section is hidden.

**Tests.**

```sh
cd packages/warpgate_core && dart test
cd packages/warpgate_cli && dart test --exclude-tags integration
UPDATE_GOLDENS=1 dart test test/help_golden_test.dart
dart run tool/gen_docs.dart
```

The second-to-last line accepts help text changes after review, and the last one regenerates `docs/CLI.md`. A test fails if either is out of date.

Integration tests need a real SSH server. They run against the Rust engine when the library can be found (`WARPGATE_ENGINE_LIBRARY`) and against `dartssh2` with `WARPGATE_ENGINE=dart`. CI runs both. `tool/cli_test_server.sh` starts `linuxserver/openssh-server` in Docker and prints the variables to set:

```sh
env $(tool/cli_test_server.sh) dart test --tags integration --concurrency=1
```

Any server that accepts your key works too: set `WARPGATE_TEST_SSH_HOST`, `_PORT`, `_USER` and `_KEY`.

## 5. Which OS builds what

| Target | Build on | Why |
|---|---|---|
| iOS | macOS | Needs Xcode |
| macOS | macOS | Needs Xcode |
| Windows | Windows | Needs MSVC. Flutter does not cross-compile desktop targets |
| Linux | Linux | Needs GTK and the native toolchain |
| Android | macOS, Windows or Linux | Gradle and the Android SDK run everywhere |
| Web notice | any | |

To build everything without three machines, use CI. `.github/workflows/build.yml` runs the analyzer and tests on macOS (the golden images are rendered there, and text rasterizes differently on other systems), then builds Android (APK and AAB), iOS (unsigned), macOS, Windows, Linux and the web notice, each on a matching GitHub-hosted runner. It uploads every result as a workflow artifact. It runs on pushes to `main`, on pull requests, and by hand from the Actions tab.

Android release signing in CI is optional. Add these repository secrets and the workflow writes `android/key.properties` before building:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -i ~/warpgate-upload.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | store password |
| `ANDROID_KEY_PASSWORD` | key password |
| `ANDROID_KEY_ALIAS` | `upload` |

Without them the Android artifacts are signed with the debug key. iOS and macOS artifacts are unsigned. Sign them locally as shown above, or extend the workflow with your certificates.

## App icons

The source is `assets/logo.png` (512×512, so the 1024 outputs are upscaled; replace it with a 1024 or larger file for sharper store icons). The per-platform masters in `assets/icon/` were made from it:

| File | Use |
|---|---|
| `icon_macos.png` | macOS: the squircle at 824×824 on a 1024 canvas, soft shadow, per the Apple grid |
| `icon_full.png` | iOS: full bleed on the graphite background, no alpha |
| `icon_foreground.png`, `icon_monochrome.png` | Android adaptive foreground and themed-icon layer, mark inside the 66% safe zone, background `#0F0F10` |
| `icon_maskable.png` | Web maskable icons |
| `icon_rounded.png` | Android legacy, Windows, Linux, web favicon |

Regenerate everything after changing a master:

```sh
dart run flutter_launcher_icons            # config in flutter_launcher_icons.yaml
```

Then rebuild `windows/runner/resources/app_icon.ico` with all sizes (the tool writes only 256) and the Linux PNGs in `linux/packaging/icons/hicolor/{256x256,512x512}/apps/eu.kwilex.warpgate.png`. The in-app mark is `assets/brand/mark.png`, shown through `WgLogoMark`.

## Bundle id and data migration

The id is `eu.kwilex.warpgate` on every platform (Android `applicationId` and `namespace`, Kotlin package `eu.kwilex.warpgate`, iOS and macOS `PRODUCT_BUNDLE_IDENTIFIER`, Linux `APPLICATION_ID` and `.desktop` file, Windows `CompanyName` `eu.kwilex`). It used to be `dev.warpgate.app`. On desktop the app data folder follows the id, so on the first launch Warpgate copies the old folder (database with hosts, settings, workspaces, saved sessions, snippets, transfers) into the new one if the new one has no database yet. The old folder is left in place. Android and iOS treat a new id as a new app, so data there cannot move over; use **Settings → Backup** before switching.

## 6. MCP setup after install

Warpgate can expose an MCP server so Claude Code can use your hosts. It is off by default.

1. Open **Settings → Claude Code** and turn on **Let Claude Code use Warpgate**. The server listens on `127.0.0.1:7823` (the port can be changed there).
2. In each host's editor, set **Claude Code access** to Off, Read only or Full. Hosts are invisible to Claude Code until you do.
3. Copy the command shown in Settings and run it in a terminal where `claude` is installed:

   ```sh
   claude mcp add --transport http warpgate http://127.0.0.1:7823/mcp --header "Authorization: Bearer <token>"
   ```

4. Or connect over stdio with the companion binary:

   ```sh
   cd tool/mcp_stdio
   dart pub get
   dart compile exe bin/warpgate_mcp.dart -o build/warpgate-mcp
   claude mcp add warpgate -e WARPGATE_MCP_TOKEN=<token> -- "$PWD/build/warpgate-mcp" --port 7823
   ```

   Compiling the companion is **Verified**.

5. Check from Claude Code: `claude mcp list` shows `warpgate` as connected. Every call appears in **Settings → Claude Code → Activity log**.

Keep Warpgate running while Claude Code uses it. On iOS and Android the server only runs while the app is on screen.

## 7. Troubleshooting

**CocoaPods errors** (`CocoaPods not installed`, `pod install` fails, `Unable to find a specification`):

```sh
brew install cocoapods     # or: brew upgrade cocoapods
cd macos && pod repo update && pod install && cd ..
cd ios && pod install --repo-update && cd ..
flutter clean && flutter pub get
```

**Gradle and JDK mismatch** (`Unsupported class file major version`, `Could not determine java version`, `incompatible Java version`): Gradle is running on a JDK it does not support, often a very new system JDK. Use JDK 17 or 21:

```sh
flutter config --jdk-dir "<path to JDK 17 or 21>"
flutter doctor -v          # the Android toolchain section shows the Java version in use
cd android && ./gradlew --stop && cd ..
```

**Missing Linux libraries** (`Package 'libsecret-1' not found`, `gtk+-3.0 not found`, `CMAKE_CXX_COMPILER not set`): install the packages from [Linux](#linux-ubuntu-or-debian), then `flutter clean`. If the app starts but cannot save passwords, no Secret Service is running. Start `gnome-keyring-daemon` or enable the KWallet Secret Service bridge.

**Windows long paths and symlinks** (`Filename too long`, `ERROR_PATH_NOT_FOUND` deep in `.plugin_symlinks`, `Building with plugins requires symlink support`):

```powershell
reg add HKLM\SYSTEM\CurrentControlSet\Control\FileSystem /v LongPathsEnabled /t REG_DWORD /d 1 /f
git config --system core.longpaths true
start ms-settings:developers    # turn on Developer Mode
```

Restart the terminal, or keep the clone in a short path such as `C:\src\warpgate`.

**Visual Studio not found** (`Unable to find suitable Visual Studio toolchain`): install the **Desktop development with C++** workload in Visual Studio Installer, then run `flutter doctor -v`.

**Keychain prompts on macOS**: see [macOS keychain](#macos-keychain).

**Code signing on iOS** (`requires a development team`, `No profiles for 'eu.kwilex.warpgate' were found`): choose a Team in Xcode as in [iOS](#ios). If the bundle id belongs to someone else, change it to a unique id in Runner → General.

**Notarization rejected** (`The executable does not have the hardened runtime enabled`, `The signature does not include a secure timestamp`): sign again with `--options runtime --timestamp` as shown in [macOS](#macos), sign the `.app` before creating the `.dmg`, then submit again.

**First build fails while downloading SQLite** (`Failed to download` from the `sqlite3` hook): the first build needs network access. Build once online. Later builds use the cache.

**Noise from xcodebuild** about `CoreSimulator is out of date` or missing simulator runtimes during `flutter build macos`: these warnings do not affect macOS builds. Install the matching simulator runtime in Xcode → Settings → Components if you build for the iOS simulator.
