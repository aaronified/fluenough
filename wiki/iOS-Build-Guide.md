# iOS build guide

Fluenough is released for Android. There is no iPhone build to download, and none in the App Store. You can build one yourself on a Mac and put it on your own iPhone. Nothing here is a promise that every feature works the same on iOS: the app is built and tested on Android first.

This guide uses two official sources and cites nothing else outside GitHub:

- Flutter's install guide for iOS: [docs.flutter.dev/get-started/install/macos/mobile-ios](https://docs.flutter.dev/get-started/install/macos/mobile-ios)
- Apple's comparison of memberships: [developer.apple.com/support/compare-memberships](https://developer.apple.com/support/compare-memberships/)

Versions of Xcode and Flutter change often. Check the Flutter page for what is current before you start.

## What you need

- A Mac. iOS apps can only be built with Xcode, which only runs on macOS.
- Xcode, from the Mac App Store, and its command-line tools.
- The iOS simulator runtime, installed in Xcode, if you want to use the simulator.
- CocoaPods, which Flutter uses for iOS packages.
- Flutter 3.47 or later ([Development setup](Development-Setup)).
- An Apple ID.
- To run on a real iPhone: a cable, and Developer Mode turned on in the phone.

`flutter doctor` reports what is missing. Follow its messages.

## 1. Get the code

```sh
git clone https://github.com/aaronified/fluenough.git
cd fluenough
```

The `ios/` folder is not committed. Create it:

```sh
flutter create . --org app --project-name fluenough --platforms=ios
flutter pub get
dart run build_runner build
```

The generated application id is `app.fluenough`. A free Apple ID needs another one: see step 5 in section 3. If you also build Android, include `android` in `--platforms` and see [Development setup](Development-Setup). The Android-only branding script is not for iOS.

## 2. Run on the simulator

Open the simulator from Xcode, or run:

```sh
open -a Simulator
flutter run
```

The simulator needs no Apple ID. It has few voices, and no real microphone, so test speaking and listening on a phone.

## 3. Run on your iPhone with a free Apple ID

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Choose the Runner target, then the Signing & Capabilities tab.
3. Sign in to Xcode with your Apple ID, under Xcode Settings, Accounts.
4. Under Signing, choose your name as the Team. Xcode lists it as a Personal Team. Tick "Automatically manage signing".
5. Change the Bundle Identifier to one only you use, for example `com.yourname.fluenough`. A free account cannot use an identifier someone else holds.
6. Connect the iPhone and unlock it. Tap Trust if it asks. In Settings, Privacy and Security, turn on Developer Mode, and restart the phone.
7. Run `flutter run`, or press Run in Xcode, with your iPhone chosen.
8. The first launch may say the developer is not trusted. In Settings, General, VPN & Device Management, trust your Apple ID.

### The seven-day limit

With a free Apple ID, Apple says the provisioning profile expires after 7 days. After that the app stops opening. You must connect the phone and build and install it again. Your progress is kept on the phone if you install over it without deleting the app. If you delete the app, progress is gone, so make a backup first ([Backup and restore](Backup-and-Restore)).

Apple also limits a free account: up to 3 apps on a device, 3 devices and 10 App IDs, all expiring after 7 days. A free account cannot use App Store Connect or TestFlight.

## 4. A paid Apple Developer Program account

The Apple Developer Program is a paid yearly membership. See Apple's page above for the current price and what it adds. In short, it lets you:

- sign builds that last a year instead of 7 days;
- distribute to testers with TestFlight;
- publish to the App Store.

To use it, enrol, then choose your paid team as the Team in Signing & Capabilities. The steps in section 3 are otherwise the same.

If you publish a build of Fluenough, the licence applies: see [Licence](Licence).

## What does not match Android

- The update check installs an APK on Android. iOS cannot do that. Update by building again.
- `tools/brand_android.py` is for Android only.
- Voices come from the iPhone's own speech engine ([ADR-0002](ADR-0002-System-Tts)), with its own list of languages. Check them in iOS Settings.
- **Platform channel.** The app has one channel of its own, `app.fluenough/system`. Only its Android side exists, and `tools/brand_android.py` writes it. On iOS, "Install voices in phone settings" on the Voices page opens nothing, and the page explains the way there instead. A report is not shared with its files attached ([ADR-0021](ADR-0021-In-App-Reports)): it goes without the log, and says so. Fix the iOS side only if you need it.
- **Speech recognition.** Speaking drills use the `speech_to_text` plugin, which asks the iPhone's own recogniser, as it asks Android's. The `record` plugin uses the microphone. Nothing in the repository tests either on iOS. Both need usage descriptions for the microphone and for speech recognition in `ios/Runner/Info.plist`. The repository does not add them, because `ios/` is generated, so add them yourself, or speaking will not work. See the plugins' own instructions.
- We have not tested every screen on iOS. If you find a problem, see [Reporting a problem](Reporting-a-Problem).

See also: [Development setup](Development-Setup), [Learner guide](Learner-Guide), [Home](Home).
