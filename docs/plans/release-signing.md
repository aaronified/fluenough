# Plan: sign and publish the first release

Tracked in #24. The release workflow (`.github/workflows/release.yml`) builds
a signed APK for a version tag, but it needs a keystore and four repository
secrets first. Without them, a tag fails at "Restore signing key" and
publishes nothing.

**The keystore is the least reversible thing in the project.** Losing it, or
its password, means no installed copy can ever be upgraded, and Android
offers no recovery.

## 1. Get `keytool`

It ships with Java 17 or later.

**Windows.** Android Studio includes it:

```
"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
```

Otherwise use the `bin` folder of any JDK 17 or later.

**Ubuntu.**

```sh
sudo apt install openjdk-21-jre-headless
keytool -help   # checks it is on the PATH
```

**Bazzite** (and other immutable Fedoras). Do not layer Java onto the base
image. Use the same distrobox as DEVELOPMENT.md; if you already set it up,
`keytool` is in it:

```sh
distrobox create --name fluenough-dev --image fedora:latest   # once
distrobox enter fluenough-dev
sudo dnf install java-21-openjdk-headless
```

The container shares your home folder, so the keystore it writes is on the
host too.

## 2. Generate the keystore

From a folder **outside** the repository.

**Windows**, in PowerShell:

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkeypair -v `
  -keystore fluenough-release.jks -alias fluenough `
  -keyalg RSA -keysize 4096 -validity 10000
```

**Ubuntu and Bazzite** (on Bazzite, inside the distrobox):

```sh
mkdir -p ~/keys && cd ~/keys
keytool -genkeypair -v \
  -keystore fluenough-release.jks -alias fluenough \
  -keyalg RSA -keysize 4096 -validity 10000
chmod 600 fluenough-release.jks
```

`keytool` asks for a keystore password: you make one up. Use a long random
one from a password manager and save it there at once. Any characters work;
the workflow escapes them. Then it asks for a name and organisation, which
can be anything.

A modern `keytool` writes a PKCS12 keystore, where the key's password is the
keystore's password. Use the same password for both secrets below.

## 3. Back it up, before anything else

Keep `fluenough-release.jks` and its password somewhere offline, apart from
this repository: a password manager and a USB stick, for example. Never put
the file in the repository folder. `.gitignore` excludes `*.jks`, but
outside the folder it cannot be committed at all (AGENTS.md rule 4).

## 4. Turn the keystore into a secret

Copy it, base64-encoded on one line, to the clipboard.

**Windows**, in PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("fluenough-release.jks")) | Set-Clipboard
```

**Ubuntu and Bazzite.** Both desktops run Wayland by default, where
`wl-copy` reaches the clipboard (`sudo apt install wl-clipboard` on Ubuntu;
`sudo dnf install wl-clipboard` in the Bazzite distrobox):

```sh
base64 -w0 ~/keys/fluenough-release.jks | wl-copy
```

On an X11 session, use `xclip -selection clipboard` in place of `wl-copy`.
Without either, write it to a file, open it in a text editor, copy
everything, then delete the file:

```sh
base64 -w0 ~/keys/fluenough-release.jks > /tmp/keystore.b64
# copy its contents, then:
shred -u /tmp/keystore.b64
```

## 5. Add the four secrets

In the repository: **Settings → Secrets and variables → Actions → New
repository secret**.

| Name | Value |
|---|---|
| `KEYSTORE_BASE64` | the clipboard from step 4 |
| `KEYSTORE_PASSWORD` | the password from step 2 |
| `KEY_ALIAS` | `fluenough` |
| `KEY_PASSWORD` | the same password |

## 6. Try it on a phone first

Install the debug APK from `main`'s latest CI run (**Actions → CI → the
newest run on main → Artifacts → `fluenough-debug-apk`**) and use it for a
day. It has never run on a device.

A debug APK is signed with a different key from a release, so it cannot
upgrade to one. Before installing the release, export progress (Settings →
Export review log), uninstall the debug build, and import it again after.

## 7. Tag the release

The tag must look like `v0.1.0` (the workflow rejects anything else). It
should match `version:` in `pubspec.yaml`, which the Settings footer shows;
today that is 0.1.0.

```sh
git checkout main && git pull
git tag v0.1.0
git push origin v0.1.0
```

The workflow checks that the APK is signed with the release key, attaches
it to a GitHub Release, and deletes the keystore and passwords from the
runner.

## 8. Check the upgrade path

Install the released APK. At the next release, check that the new APK
installs **over** it, keeping progress. That, not the build alone, is what
#24 asks for.

## 9. Get past Play Protect

Play Protect is on by default and checks every APK installed from outside
Google Play. Checked on 30 September 2026:

| Check | What it stops | Fluenough |
|---|---|---|
| Minimum target SDK | On Android 15 and later, an app targeting below API 24 does not install | Flutter targets 36. Passes. |
| Unknown-app scan | "Play Protect hasn't seen this app before" asks to send the APK to Google for scanning | Expect it on each new release. It is a prompt, not a block: tap **Scan app**, then install. |
| Enhanced fraud protection (India since October 2024) | Blocks apps installed from a browser, messaging app or file manager that ask for `RECEIVE_SMS`, `READ_SMS`, a notification listener or Accessibility | Asks for none of them. Passes. |
| Developer verification | From 30 September 2026, apps from unregistered developers do not install in Brazil, Indonesia, Singapore and Thailand; the rest of the world follows from 2027 | India is not in the first wave. Register before it is. |

**Keep the fraud-protection row passing.** Speaking (#89) needs
`RECORD_AUDIO` and reminders (#90) need `POST_NOTIFICATIONS`. Neither is on
the list. Never add SMS permissions, a notification listener or an
Accessibility service.

**If Play Protect calls it harmful**, rather than only unknown, follow
Google's
[developer guidance for Play Protect warnings](https://developers.google.com/android/play-protect/warning-dev-guidance),
which has the appeal.

### Developer verification, before it reaches India

1. Create a **full distribution** account in the
   [Android Developer Console](https://android.google.com/developerconsole):
   - a one-time US$25 fee;
   - a government photo ID and a proof of address;
   - an email address and a phone number, each confirmed by a one-time code;
   - a Google Account with 2-Step Verification.

   A free **limited distribution** account needs no ID, but reaches only 20
   devices, each added by QR code or link. That suits testers, not a public
   release.
2. Register the package name `app.fluenough` with the release key's
   SHA-256 fingerprint. Read it from the keystore:

   ```sh
   keytool -list -v -keystore fluenough-release.jks -alias fluenough
   ```

   The `SHA256:` line is the fingerprint.
3. Prove you own the package: the console gives a snippet to put in the
   APK's `assets` folder, and you upload an APK signed with the release key.
   `android/` is never committed, so doing that needs a change to the
   release workflow. Ask for it when you register.

Installing with `adb` does not change. Since August 2026, Android also has
an "advanced flow" that lets a user install an app from an unverified
developer, with extra safeguards.

Sources:
[Android developer verification](https://developer.android.com/developer-verification),
[registration guide](https://developer.android.com/developer-verification/guides/android-developer-console),
[full distribution](https://developer.android.com/developer-verification/guides/full-distribution),
[limited distribution](https://developer.android.com/developer-verification/guides/limited-distribution),
[Android 15 behaviour changes](https://developer.android.com/about/versions/15/behavior-changes-all),
[enhanced fraud protection in India](https://blog.google/intl/en-in/products/launching-enhanced-fraud-protection-pilot-in-india/).
