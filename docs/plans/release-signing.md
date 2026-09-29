# Plan: sign and publish the first release

Tracked in #24. The release workflow (`.github/workflows/release.yml`) builds
a signed APK for a version tag, but it needs a keystore and four repository
secrets first. Without them, a tag fails at "Restore signing key" and
publishes nothing.

**The keystore is the least reversible thing in the project.** Losing it, or
its password, means no installed copy can ever be upgraded, and Android
offers no recovery.

## 1. Find `keytool`

It ships with Java. With Android Studio on Windows:

```
"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
```

Otherwise use the `bin` folder of any JDK 17 or later.

## 2. Generate the keystore

In PowerShell, from a folder **outside** the repository:

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkeypair -v `
  -keystore fluenough-release.jks -alias fluenough `
  -keyalg RSA -keysize 4096 -validity 10000
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

This copies it, base64-encoded, to the clipboard:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("fluenough-release.jks")) | Set-Clipboard
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
