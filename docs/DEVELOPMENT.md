# Development setup

## Requirements

- Flutter 3.47+ (ships Dart 3.13+)
- JDK 21 and the Android SDK, for Android builds
- Python 3.11+ and PyYAML, for the deck tools only

## First checkout

The `android/` and `ios/` folders are generated, not committed. Recreate them:

```sh
flutter create . --org app --project-name fluenough --platforms=android,ios
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

The application id is **`app.fluenough`**. Changing it later means touching the
Gradle config, the iOS bundle id and every signing setup, so do not.

## Immutable Linux distributions

On Fedora Silverblue, Kinoite, Bazzite and similar, do not layer the JDK and
Android SDK onto the base image. Use a container:

```sh
distrobox create --name fluenough-dev --image fedora:latest
distrobox enter fluenough-dev
# inside: dnf install java-21-openjdk-devel, then Flutter and Android cmdline-tools
```

`adb` reaches a USB device from inside the container when `/dev/bus/usb` is
available; wireless debugging sidesteps the question entirely.

## Testing on a device

Three options, in descending order of usefulness:

**A physical phone.** The only environment with real TTS voices and a real IME.
Production drills for Japanese, Chinese and Korean cannot be meaningfully
tested anywhere else.

**An Android emulator (AVD) with a Google APIs system image.** Hardware
accelerated where `/dev/kvm` exists. Has real Google TTS voices. Budget 2–3 GB
of RAM.

**Waydroid.** Fine for UI iteration and fast to start. But Waydroid images are
LineageOS-based and ship **without Google Play Services**, which is what
provides the TTS voices — so **listening drills will be silent** unless you add
GApps or install a standalone TTS engine APK. Never conclude that audio is
broken from a Waydroid run alone.

## Before opening a pull request

```sh
python3 tools/validate_decks.py decks/   # if you touched decks
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

CI runs all four.
