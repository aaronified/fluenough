# Plan: sign and publish the first release

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
