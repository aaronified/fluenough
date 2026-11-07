#!/usr/bin/env python3
"""Put the brand into the generated android/ folder.

Usage:
    python3 tools/brand_android.py        # after flutter create; 0 ok, 1 error

flutter create writes android/ with Flutter's launcher icon, a plain launch
screen and the project name, "fluenough", as the launcher label. android/ is
never committed (AGENTS.md rule 4), so this runs after every flutter create:
in CI, in the release workflow and on a first checkout. It

- copies fluenough-brand/android/ over android/app/src/main/res/: the
  launcher icon, and a launch screen in the app's own background, light or
  dark, with the mark;
- sets the launcher label to the app's name, `appTitle` in
  lib/l10n/app_en.arb, so the name has one source;
- declares what the app asks Android for: the microphone, for the speaking
  drill (ADR-0014), and a query for the speech recogniser, which Android 11
  and later hide from an app that does not declare one. The speech_to_text
  plugin's own manifest declares neither. Likewise a query for the
  text-to-speech engine: without it, Android 11 and later let the app find
  no voice to speak with, and flutter_tts's manifest does not declare one;
- declares the internet, for the update check (ADR-0017): flutter create
  grants it to debug and profile builds only, so a release build could not
  reach GitHub without it. And a query for apps that open https links,
  which url_launcher needs on Android 11 and later to find the browser. And
  one for UPI apps (upi links), which Settings' Support page opens: without
  it Android 11 and later tell the app that no UPI app is installed;
- sets up ota_update, which installs updates (ADR-0017). Its own manifest
  asks to install packages but declares no FileProvider, which Android's
  installer needs to read the download, so this adds one, and the file
  naming the folder it shares. It asks for external storage too, which it
  no longer uses: the download goes to the app's own storage. So this
  removes both storage permissions from the merged manifest. And its build
  requires core library desugaring of the app, which this switches on in
  android/app/build.gradle.kts;
- gives MainActivity a platform channel, app.fluenough/system, whose
  openVoiceSettings opens Android's text-to-speech settings for Settings >
  Voices, or failing that the default engine's page for installing voice
  data, and says which opened. No plugin is needed for it, and a channel
  is no dependency (AGENTS.md rule 6). The manifest gets a query for each
  page, which Android 11 and later need before the app can see that one
  opens;
- gives the same channel shareFiles, which opens a mail with files
  attached, for a report with the app log (ADR-0021) and later the review
  files: Android's share (ACTION_SEND, or ACTION_SEND_MULTIPLE for several
  files) with the address, subject, text and the files, to the phone's
  mail apps first and then to any app that takes them. The files are lent
  through a FileProvider of the app's own, ShareFileProvider, which this
  writes beside MainActivity, and declares in the manifest with the file
  naming the folder it shares: shared/ in the app's cache. The manifest
  gets a query for mail apps (mailto), without which Android 11 and later
  hide them. A MainActivity written by an earlier version of this, with
  the channel but not shareFiles, is brought up to date;
- gives the same channel installApk, which reopens Android's installer on
  an update already downloaded into files/ota_update, through ota_update's
  FileProvider, so that Install after a cancelled install needs no second
  download (#487). A MainActivity without it is brought up to date;
- gives the same channel wallpaperColour, the system's primary accent colour
  on Android 12 and later, from which Settings' Wallpaper colours builds the
  app's colours. A MainActivity without it is brought up to date;
- gives the same channel listenWithAudio, Say's listen that captures the
  microphone itself and feeds the recogniser from the same stream
  (RecognizerIntent.EXTRA_AUDIO_SOURCE, Android 13 and later), so the
  learner's voice is kept at the moment it is recognised (ADR-0054, option 2).
  Below Android 13 it answers "unsupported" and the app listens the plain way.
  A MainActivity without it is brought up to date.

- sets up flutter_local_notifications, which shows the daily reminder (#90).
  The reminder is scheduled inexactly, so there is no exact-alarm
  permission. The plugin's own manifest declares POST_NOTIFICATIONS (asked
  when the learner switches the reminder on, never at launch) and VIBRATE
  but, since its version 16, not what scheduling needs, so this adds
  RECEIVE_BOOT_COMPLETED and the plugin's two receivers: one shows a
  scheduled notification, and one, ScheduledNotificationBootReceiver,
  puts them back after a reboot or an app update. Tapping a notification
  needs no receiver: it opens MainActivity;

Each is added only if it is not there already, so running this twice is
the same as running it once.

It fails rather than quietly doing nothing when the manifest does not have
the one android:label and one <application> it expects, the Gradle file
not the one compileOptions block, or MainActivity.kt not the one
`class MainActivity : FlutterActivity()`, or a configureFlutterEngine of
its own, or the channel without the lines shareFiles is added beside, as
it would after a flutter create that changed shape. Then it changes
nothing.

Requires only Python 3.11+, like the other tools.
"""

from __future__ import annotations

import json
import re
import shutil
import sys
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent.parent

BRAND = Path("fluenough-brand/android")
RES = Path("android/app/src/main/res")
MANIFEST = Path("android/app/src/main/AndroidManifest.xml")
GRADLE = Path("android/app/build.gradle.kts")
ACTIVITY = Path("android/app/src/main/kotlin/app/fluenough/MainActivity.kt")
ARB = Path("lib/l10n/app_en.arb")

LABEL = re.compile(r'android:label="[^"]*"')
MANIFEST_OPEN = re.compile(r"<manifest\b[^>]*>")
PERMISSION = re.compile(r'<uses-permission\s[^>]*?android:name="([^"]+)"[^>]*>')
QUERIES = re.compile(r"<queries>.*?</queries>", re.S)
INTENT = re.compile(r"<intent>.*?</intent>", re.S)
RECORD_AUDIO = "android.permission.RECORD_AUDIO"
INTERNET = "android.permission.INTERNET"
RECOGNITION_SERVICE = "android.speech.RecognitionService"
TTS_SERVICE = "android.intent.action.TTS_SERVICE"
VIEW = "android.intent.action.VIEW"
# What MainActivity's openVoiceSettings opens: Android's text-to-speech
# settings, or an engine's page for installing voice data
# (TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA).
TTS_SETTINGS = "com.android.settings.TTS_SETTINGS"
INSTALL_TTS_DATA = "android.speech.tts.engine.INSTALL_TTS_DATA"
# What MainActivity's shareFiles looks for first: the phone's mail apps.
SENDTO = "android.intent.action.SENDTO"
# ota_update asks to write external storage, and the merge then adds the
# read permission that implies. It has used neither since 7.0.1.
STORAGE = (
    "android.permission.WRITE_EXTERNAL_STORAGE",
    "android.permission.READ_EXTERNAL_STORAGE",
)
POST_NOTIFICATIONS = "android.permission.POST_NOTIFICATIONS"
RECEIVE_BOOT_COMPLETED = "android.permission.RECEIVE_BOOT_COMPLETED"
TOOLS = 'xmlns:tools="http://schemas.android.com/tools"'

# ota_update's FileProvider, under the authority it asks for by default, and
# the folder it shares: files/ota_update, where it downloads.
OTA_PROVIDER = "sk.fourq.otaupdate.OtaUpdateFileProvider"
OTA_PATHS = RES / "xml/ota_update_paths.xml"
PROVIDER = '''        <provider
            android:name="sk.fourq.otaupdate.OtaUpdateFileProvider"
            android:authorities="${applicationId}.ota_update_provider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/ota_update_paths"/>
        </provider>
'''
PATHS = '''<?xml version="1.0" encoding="utf-8"?>
<!-- Written by tools/brand_android.py: the folder ota_update downloads
     updates into, which Android's installer may read (ADR-0017). -->
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <files-path name="internal_apk_storage" path="ota_update/"/>
</paths>
'''

# flutter_local_notifications' receivers (its README, "AndroidManifest.xml
# setup"): the first shows a scheduled notification, the second reschedules
# what was scheduled after a reboot or an app update. No receiver for
# actions: the reminder has none.
NOTIFICATION_RECEIVER = (
    "com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"
)
NOTIFICATION_BOOT_RECEIVER = (
    "com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
)
NOTIFICATION_RECEIVER_XML = f'''        <receiver
            android:name="{NOTIFICATION_RECEIVER}"
            android:exported="false"/>
'''
NOTIFICATION_BOOT_RECEIVER_XML = f'''        <receiver
            android:name="{NOTIFICATION_BOOT_RECEIVER}"
            android:exported="false">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
'''

# The FileProvider that lends shareFiles' files to the app that takes them:
# a class of the app's own, so that it never clashes with a plugin's, and
# the folder it shares, shared/ in the app's cache, where
# lib/app/mail_share.dart writes them.
SHARE_PROVIDER_CLASS = "app.fluenough.ShareFileProvider"
SHARE_PROVIDER_FILE = Path(
    "android/app/src/main/kotlin/app/fluenough/ShareFileProvider.kt"
)
SHARE_PATHS = RES / "xml/share_paths.xml"
SHARE_PROVIDER = '''        <provider
            android:name="app.fluenough.ShareFileProvider"
            android:authorities="${applicationId}.share"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/share_paths"/>
        </provider>
'''
SHARE_PATHS_XML = '''<?xml version="1.0" encoding="utf-8"?>
<!-- Written by tools/brand_android.py: the folder whose files a mail shared
     from the app may carry, such as a report's app log (ADR-0021). -->
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <cache-path name="shared" path="shared/"/>
</paths>
'''
SHARE_PROVIDER_KOTLIN = '''package app.fluenough

import androidx.core.content.FileProvider

// Written by tools/brand_android.py: lends the files in the cache's shared/
// folder (res/xml/share_paths.xml) to the app a mail is shared with, such
// as a report's app log (ADR-0021). A class of the app's own, so that it
// never clashes with a plugin's FileProvider.
class ShareFileProvider : FileProvider()
'''

# MainActivity's platform channel, which lib/app/system_settings.dart and
# lib/app/mail_share.dart call.
CHANNEL = "app.fluenough/system"
ACTIVITY_CLASS = re.compile(r"class\s+MainActivity\s*:\s*FlutterActivity\(\)")
IMPORT = re.compile(r"^import\s+\S+[ \t]*$", re.M)
PACKAGE = re.compile(r"^package\s+\S+[ \t]*$", re.M)
KOTLIN_IMPORTS = (
    "android.Manifest",
    "android.content.ActivityNotFoundException",
    "android.content.Intent",
    "android.content.pm.PackageManager",
    "android.media.AudioFormat",
    "android.media.AudioRecord",
    "android.media.MediaRecorder",
    "android.net.Uri",
    "android.os.Build",
    "android.os.Bundle",
    "android.os.Handler",
    "android.os.Looper",
    "android.os.ParcelFileDescriptor",
    "android.provider.Settings",
    "android.speech.RecognitionListener",
    "android.speech.RecognizerIntent",
    "android.speech.SpeechRecognizer",
    "android.speech.tts.TextToSpeech",
    "androidx.core.content.FileProvider",
    "io.flutter.embedding.android.FlutterActivity",
    "io.flutter.embedding.engine.FlutterEngine",
    "io.flutter.plugin.common.MethodCall",
    "io.flutter.plugin.common.MethodChannel",
    "java.io.File",
)
# What went in MainActivity before shareFiles: the channel, with
# openVoiceSettings, which answers with the name of the page that opened,
# which the Dart side reads as a VoiceSettingsPage: textToSpeech,
# installVoices or none. Kept as it was written, so that an activity
# written then is recognised and brought up to date by [share].
VOICE_MEMBERS = """
    // Written by tools/brand_android.py: Settings > Voices opens the phone's
    // text-to-speech settings through this, from lib/app/system_settings.dart.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.fluenough/system")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openVoiceSettings" -> result.success(openVoiceSettings())
                    else -> result.notImplemented()
                }
            }
    }

    // Android's text-to-speech settings; failing that, the default engine's
    // page for installing voice data; failing that, any engine's. Answers
    // with the name of the one that opened, or "none".
    private fun openVoiceSettings(): String {
        if (startIfHandled(Intent("com.android.settings.TTS_SETTINGS"))) {
            return "textToSpeech"
        }
        val engine = defaultTtsEngine()
        if (engine != null &&
            startIfHandled(
                Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA).setPackage(engine)
            )
        ) {
            return "installVoices"
        }
        if (startIfHandled(Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA))) {
            return "installVoices"
        }
        return "none"
    }

    // Starts intent if an activity on the phone handles it. False if none
    // does, or it would not start.
    private fun startIfHandled(intent: Intent): Boolean {
        if (intent.resolveActivity(packageManager) == null) return false
        return try {
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        } catch (e: SecurityException) {
            false
        }
    }

    // The package of the phone's preferred text-to-speech engine, or null.
    private fun defaultTtsEngine(): String? =
        try {
            Settings.Secure.getString(contentResolver, Settings.Secure.TTS_DEFAULT_SYNTH)
                ?.takeIf { it.isNotBlank() }
        } catch (e: SecurityException) {
            null
        }
"""

# What [share] adds to the channel: a line where it answers, and shareFiles
# before the helper that starts an intent.
SHARE_METHOD = '"shareFiles" ->'
SHARE_DISPATCH_AFTER = (
    '                    "openVoiceSettings" -> result.success(openVoiceSettings())\n'
)
SHARE_DISPATCH = '                    "shareFiles" -> result.success(shareFiles(call))\n'
SHARE_MEMBERS_BEFORE = "    // Starts intent if an activity on the phone handles it."
SHARE_MEMBERS = """    // Written by tools/brand_android.py: a mail with files attached, such as
    // a report with the app log (ADR-0021). Takes "to", "subject", "text",
    // "mimeType" and "files", paths in the cache's shared/ folder, which
    // ShareFileProvider lends to the app that takes them. Android's share
    // (ACTION_SEND, or ACTION_SEND_MULTIPLE for several files), to the
    // phone's mail apps first, then to any app that takes the files. True
    // if one opened.
    private fun shareFiles(call: MethodCall): Boolean {
        val to = call.argument<List<String>>("to") ?: emptyList()
        val uris = ArrayList<Uri>()
        try {
            for (path in call.argument<List<String>>("files") ?: emptyList()) {
                uris.add(FileProvider.getUriForFile(this, "$packageName.share", File(path)))
            }
        } catch (e: IllegalArgumentException) {
            return false
        }
        val send = Intent(
            if (uris.size > 1) Intent.ACTION_SEND_MULTIPLE else Intent.ACTION_SEND
        )
        send.type = call.argument<String>("mimeType") ?: "text/plain"
        if (to.isNotEmpty()) send.putExtra(Intent.EXTRA_EMAIL, to.toTypedArray())
        call.argument<String>("subject")?.let { send.putExtra(Intent.EXTRA_SUBJECT, it) }
        call.argument<String>("text")?.let { send.putExtra(Intent.EXTRA_TEXT, it) }
        if (uris.size == 1) send.putExtra(Intent.EXTRA_STREAM, uris[0])
        if (uris.size > 1) send.putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
        send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        // Mail apps only, through a mailto selector; failing that, the
        // phone's share sheet.
        val mail = Intent(send)
        mail.selector = Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:"))
        return startIfHandled(mail) || startIfHandled(Intent.createChooser(send, null))
    }

"""

APK_MIME = "application/vnd.android.package-archive"

# What [install] adds to the channel: installApk, which reopens Android's
# installer on a download kept in files/ota_update, with no download (#487).
INSTALL_METHOD = '"installApk" ->'
INSTALL_DISPATCH = '                    "installApk" -> result.success(installApk(call))\n'
INSTALL_MEMBERS = """    // Written by tools/brand_android.py: opens Android's installer on an
    // update already downloaded into files/ota_update, which ota_update's
    // FileProvider lends to it (#487). Takes "path". True if the installer
    // opened.
    private fun installApk(call: MethodCall): Boolean {
        val path = call.argument<String>("path") ?: return false
        val uri = try {
            FileProvider.getUriForFile(this, "$packageName.ota_update_provider", File(path))
        } catch (e: IllegalArgumentException) {
            return false
        }
        val view = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, "application/vnd.android.package-archive")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        // Started without asking the package manager first: on Android 11+
        // that hides the installer unless the manifest queries for it.
        return try {
            startActivity(view)
            true
        } catch (e: ActivityNotFoundException) {
            false
        } catch (e: SecurityException) {
            false
        }
    }

"""


class BrandError(Exception):
    """Why the brand could not be applied."""


def share(text: str) -> str:
    """[text], MainActivity.kt or the members written into it, with
    shareFiles added to the app.fluenough/system channel, unless it has it.
    Fails if the channel is not in the shape this wrote."""
    if SHARE_METHOD in text:
        return text
    if (
        text.count(SHARE_DISPATCH_AFTER) != 1
        or text.count(SHARE_MEMBERS_BEFORE) != 1
    ):
        raise BrandError(
            f"{ACTIVITY} has the {CHANNEL} channel, but not as this writes "
            "it; add shareFiles to it by hand, or run flutter create again"
        )
    text = text.replace(SHARE_DISPATCH_AFTER, SHARE_DISPATCH_AFTER + SHARE_DISPATCH)
    return text.replace(SHARE_MEMBERS_BEFORE, SHARE_MEMBERS + SHARE_MEMBERS_BEFORE)


def install(text: str) -> str:
    """[text], MainActivity.kt or the members written into it, with
    installApk added to the app.fluenough/system channel, unless it has it.
    Fails if the channel is not in the shape this wrote."""
    if INSTALL_METHOD in text:
        return text
    if (
        text.count(SHARE_DISPATCH) != 1
        or text.count(SHARE_MEMBERS_BEFORE) != 1
    ):
        raise BrandError(
            f"{ACTIVITY} has the {CHANNEL} channel, but not as this writes "
            "it; add installApk to it by hand, or run flutter create again"
        )
    text = text.replace(SHARE_DISPATCH, SHARE_DISPATCH + INSTALL_DISPATCH)
    return text.replace(SHARE_MEMBERS_BEFORE, INSTALL_MEMBERS + SHARE_MEMBERS_BEFORE)


# What [wallpaper] adds to the channel: wallpaperColour, the system's primary
# accent colour on Android 12 (API 31) and later, which Wallpaper colours in
# Settings > Look and language builds the app's scheme from.
WALLPAPER_METHOD = '"wallpaperColour" ->'
WALLPAPER_DISPATCH = (
    '                    "wallpaperColour" -> result.success(wallpaperColour())\n'
)
WALLPAPER_MEMBERS = """    // Written by tools/brand_android.py: the colour Android 12 and later
    // draw their Material You palette from the wallpaper: the middle tone
    // of the system's primary accent. Null below Android 12, where there is
    // none. Read by lib/app/wallpaper_colours.dart.
    private fun wallpaperColour(): Int? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return null
        return try {
            resources.getColor(android.R.color.system_accent1_500, theme)
        } catch (e: Exception) {
            null
        }
    }

"""


def wallpaper(text: str) -> str:
    """[text], MainActivity.kt or the members written into it, with
    wallpaperColour added to the app.fluenough/system channel, unless it
    has it. Fails if the channel is not in the shape this wrote."""
    if WALLPAPER_METHOD in text:
        return text
    if (
        text.count(INSTALL_DISPATCH) != 1
        or text.count(SHARE_MEMBERS_BEFORE) != 1
    ):
        raise BrandError(
            f"{ACTIVITY} has the {CHANNEL} channel, but not as this writes "
            "it; add wallpaperColour to it by hand, or run flutter create again"
        )
    text = text.replace(INSTALL_DISPATCH, INSTALL_DISPATCH + WALLPAPER_DISPATCH)
    return text.replace(SHARE_MEMBERS_BEFORE, WALLPAPER_MEMBERS + SHARE_MEMBERS_BEFORE)


# What [listen] adds to the channel: listenWithAudio, Say's listen that owns
# the microphone and feeds the recogniser from it, so that the learner's voice
# is kept at the moment it is recognised (ADR-0054, option 2). Android 13
# (API 33) lets an app give the recogniser audio it captures itself
# (RecognizerIntent.EXTRA_AUDIO_SOURCE); below that, or where the recogniser
# service does not take it, the Dart side listens the plain way.
LISTEN_METHOD = '"listenWithAudio" ->'
LISTEN_DISPATCH = (
    '                    "canListenWithAudio" -> result.success(canListenWithAudio())\n'
    '                    "listenWithAudio" -> listenWithAudio(call, result)\n'
    '                    "cancelListen" -> {\n'
    "                        sayStop?.invoke()\n"
    "                        result.success(null)\n"
    "                    }\n"
)
LISTEN_MEMBERS = """    // Written by tools/brand_android.py: Say's listen that keeps the learner's
    // voice (ADR-0054, option 2), read by lib/core/speech/native_listen.dart.
    // The app captures the microphone itself (16 kHz mono PCM, in memory only)
    // and gives the recogniser the same stream through
    // RecognizerIntent.EXTRA_AUDIO_SOURCE (Android 13 and later), so there is
    // one reader of the microphone and the audio kept is what was recognised.
    // Takes "language" (BCP-47), "onDevice" and "seconds"; answers a map with
    // "texts", "confidences", "error" (null, or the recogniser's code such as
    // error_no_match, or "unsupported" below Android 13), "pcm" and
    // "sampleRate". Never throws; no file is written.
    //
    // One listen at a time: a new one first aborts any that is still running
    // (sayAbort), so that two never read the microphone. An abandoned listen
    // (the app is paused or destroyed) is aborted at once, so the recogniser
    // and the recorder let go of the microphone and the phone's microphone
    // indicator goes off; the answer is "aborted".
    private var sayStop: (() -> Unit)? = null
    private var sayAbort: (() -> Unit)? = null

    override fun onPause() {
        sayAbort?.invoke()
        super.onPause()
    }

    override fun onDestroy() {
        sayAbort?.invoke()
        super.onDestroy()
    }

    private fun canListenWithAudio(): Boolean =
        Build.VERSION.SDK_INT >= 33 && SpeechRecognizer.isRecognitionAvailable(this)

    private fun sayError(code: Int): String =
        when (code) {
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "error_network_timeout"
            SpeechRecognizer.ERROR_NETWORK -> "error_network"
            SpeechRecognizer.ERROR_AUDIO -> "error_audio"
            SpeechRecognizer.ERROR_SERVER -> "error_server"
            SpeechRecognizer.ERROR_CLIENT -> "error_client"
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "error_speech_timeout"
            SpeechRecognizer.ERROR_NO_MATCH -> "error_no_match"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "error_busy"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "error_permission"
            SpeechRecognizer.ERROR_TOO_MANY_REQUESTS -> "error_busy"
            SpeechRecognizer.ERROR_SERVER_DISCONNECTED -> "error_server_disconnected"
            SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED -> "error_language_not_supported"
            SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> "error_language_unavailable"
            else -> "error_$code"
        }

    @android.annotation.SuppressLint("NewApi", "MissingPermission")
    private fun listenWithAudio(call: MethodCall, result: MethodChannel.Result) {
        if (!canListenWithAudio()) {
            result.success(mapOf("error" to "unsupported"))
            return
        }
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            result.success(mapOf("error" to "error_permission"))
            return
        }
        sayAbort?.invoke()
        val language = call.argument<String>("language") ?: "en-US"
        val onDevice = call.argument<Boolean>("onDevice") ?: false
        val seconds = call.argument<Int>("seconds") ?: 8
        val rate = 16000
        val minimum = AudioRecord.getMinBufferSize(
            rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
        )
        if (minimum <= 0) {
            result.success(mapOf("error" to "error_audio"))
            return
        }
        val recorder = try {
            AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                rate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                minimum * 4
            )
        } catch (e: Exception) {
            null
        }
        if (recorder == null || recorder.state != AudioRecord.STATE_INITIALIZED) {
            recorder?.release()
            result.success(mapOf("error" to "error_audio"))
            return
        }
        val pipe = try {
            ParcelFileDescriptor.createPipe()
        } catch (e: java.io.IOException) {
            null
        }
        if (pipe == null) {
            recorder.release()
            result.success(mapOf("error" to "error_audio"))
            return
        }
        val source = pipe[0]
        val sink = pipe[1]
        val kept = java.io.ByteArrayOutputStream()
        val handler = Handler(Looper.getMainLooper())
        val recognizer =
            if (onDevice && SpeechRecognizer.isOnDeviceRecognitionAvailable(this)) {
                SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
            } else {
                SpeechRecognizer.createSpeechRecognizer(this)
            }
        val running = java.util.concurrent.atomic.AtomicBoolean(true)
        var done = false

        // The microphone is read on its own thread: the bytes go to the
        // recogniser through the pipe and are kept here. The pipe is closed
        // after the listening time, which ends the recogniser's input.
        val writer = Thread {
            val out = ParcelFileDescriptor.AutoCloseOutputStream(sink)
            val buffer = ByteArray(minimum)
            val end = System.currentTimeMillis() + seconds * 1000L
            try {
                recorder.startRecording()
                while (running.get() && System.currentTimeMillis() < end) {
                    val n = recorder.read(buffer, 0, buffer.size)
                    if (n < 0) break
                    if (n == 0) continue
                    synchronized(kept) { kept.write(buffer, 0, n) }
                    out.write(buffer, 0, n)
                }
            } catch (e: Exception) {
                // The recogniser stopped reading, or the recorder failed:
                // what was kept is still delivered.
            } finally {
                // The thread lets go of the microphone itself, so that
                // finish never waits for it on the main thread.
                try { recorder.stop() } catch (e: Exception) {}
                try { recorder.release() } catch (e: Exception) {}
                try { out.close() } catch (e: Exception) {}
            }
        }

        fun finish(texts: List<String>, confidences: FloatArray?, error: String?) {
            if (done) return
            done = true
            running.set(false)
            handler.removeCallbacksAndMessages(null)
            sayStop = null
            sayAbort = null
            try { recognizer.destroy() } catch (e: Exception) {}
            try { source.close() } catch (e: java.io.IOException) {}
            val pcm = synchronized(kept) { kept.toByteArray() }
            val answer = HashMap<String, Any?>()
            answer["texts"] = texts
            answer["confidences"] = confidences?.map { it.toDouble() } ?: emptyList<Double>()
            answer["error"] = error
            answer["pcm"] = pcm
            answer["sampleRate"] = rate
            result.success(answer)
        }

        recognizer.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onPartialResults(partialResults: Bundle?) {}
            override fun onEvent(eventType: Int, params: Bundle?) {}
            override fun onError(error: Int) {
                finish(emptyList(), null, sayError(error))
            }
            override fun onResults(results: Bundle?) {
                val texts =
                    results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        ?: arrayListOf<String>()
                val scores = results?.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)
                finish(texts, scores, if (texts.isEmpty()) "error_no_match" else null)
            }
        })

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE, language)
            .putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
            .putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, onDevice)
            .putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
            .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, source)
            .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, 1)
            .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
            .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_SAMPLING_RATE, rate)
        sayStop = {
            try { recognizer.stopListening() } catch (e: Exception) {}
        }
        sayAbort = {
            try { recognizer.cancel() } catch (e: Exception) {}
            finish(emptyList(), null, "aborted")
        }
        try {
            writer.start()
        } catch (e: Exception) {
            // The thread never ran, so nothing else will release these.
            try { sink.close() } catch (x: java.io.IOException) {}
            try { recorder.release() } catch (x: Exception) {}
            finish(emptyList(), null, "error_client")
            return
        }
        try {
            recognizer.startListening(intent)
        } catch (e: Exception) {
            finish(emptyList(), null, "error_client")
            return
        }
        // A recogniser that never answers: give up after the time plus a grace.
        handler.postDelayed({ finish(emptyList(), null, "error_speech_timeout") }, (seconds + 3) * 1000L)
    }

"""


def listen(text: str) -> str:
    """[text], MainActivity.kt or the members written into it, with
    listenWithAudio added to the app.fluenough/system channel, unless it has
    it. Fails if the channel is not in the shape this wrote."""
    if LISTEN_METHOD in text:
        return text
    if (
        text.count(WALLPAPER_DISPATCH) != 1
        or text.count(SHARE_MEMBERS_BEFORE) != 1
    ):
        raise BrandError(
            f"{ACTIVITY} has the {CHANNEL} channel, but not as this writes "
            "it; add listenWithAudio to it by hand, or run flutter create again"
        )
    text = text.replace(WALLPAPER_DISPATCH, WALLPAPER_DISPATCH + LISTEN_DISPATCH)
    return text.replace(SHARE_MEMBERS_BEFORE, LISTEN_MEMBERS + SHARE_MEMBERS_BEFORE)


# What goes in MainActivity: the channel, with openVoiceSettings, shareFiles,
# installApk, wallpaperColour and listenWithAudio.
CHANNEL_MEMBERS = listen(wallpaper(install(share(VOICE_MEMBERS))))

# The version ota_update 7.1.0's own build uses.
DESUGAR_LIBS = "com.android.tools:desugar_jdk_libs:2.1.4"


def app_name(root: Path) -> str:
    """The app's name, as the interface has it."""
    name = json.loads((root / ARB).read_text(encoding="utf-8")).get("appTitle")
    if not isinstance(name, str) or not name.strip():
        raise BrandError(f"{ARB} has no appTitle")
    return name


def permit(text: str, permission: str) -> str:
    """[text], a manifest, with a <uses-permission> for [permission] after
    any it has already, unless it has that one."""
    found = list(PERMISSION.finditer(text))
    if any(m.group(1) == permission for m in found):
        return text
    at = found[-1].end() if found else MANIFEST_OPEN.search(text).end()
    line = f'\n    <uses-permission android:name="{permission}"/>'
    return text[:at] + line + text[at:]


def refuse(text: str, permission: str) -> str:
    """[text], a manifest, removing [permission], which a plugin asks for,
    from the manifest the build merges, unless it removes it already."""
    found = list(PERMISSION.finditer(text))
    if any(
        m.group(1) == permission and 'tools:node="remove"' in m.group(0)
        for m in found
    ):
        return text
    if TOOLS not in text:
        opening = MANIFEST_OPEN.search(text)
        text = (
            text[: opening.end() - 1].rstrip()
            + f" {TOOLS}"
            + text[opening.end() - 1 :]
        )
        found = list(PERMISSION.finditer(text))
    at = found[-1].end() if found else MANIFEST_OPEN.search(text).end()
    line = f'\n    <uses-permission android:name="{permission}" tools:node="remove"/>'
    return text[:at] + line + text[at:]


def provide(text: str) -> str:
    """[text], a manifest, with ota_update's FileProvider and the app's own
    ShareFileProvider last in its <application>, each unless it has it."""
    for name, provider in (
        (OTA_PROVIDER, PROVIDER),
        (SHARE_PROVIDER_CLASS, SHARE_PROVIDER),
    ):
        if f'android:name="{name}"' not in text:
            text = text.replace(
                "    </application>", f"{provider}    </application>", 1
            )
    return text


def notify(text: str) -> str:
    """[text], a manifest, with flutter_local_notifications' two receivers
    last in its <application>, each unless it has it."""
    for name, receiver in (
        (NOTIFICATION_RECEIVER, NOTIFICATION_RECEIVER_XML),
        (NOTIFICATION_BOOT_RECEIVER, NOTIFICATION_BOOT_RECEIVER_XML),
    ):
        if f'android:name="{name}"' not in text:
            text = text.replace("    </application>", f"{receiver}    </application>", 1)
    return text


def desugar(text: str) -> str:
    """[text], the app's build.gradle.kts, with core library desugaring
    switched on and its library added, each unless it is there already."""
    if "isCoreLibraryDesugaringEnabled" not in text:
        text = text.replace(
            "compileOptions {",
            "compileOptions {\n        isCoreLibraryDesugaringEnabled = true",
            1,
        )
    if "coreLibraryDesugaring(" not in text:
        text = (
            text.rstrip("\n")
            + f'\n\ndependencies {{\n    coreLibraryDesugaring("{DESUGAR_LIBS}")\n}}\n'
        )
    return text


def channel(text: str) -> str:
    """[text], MainActivity.kt, with the app.fluenough/system channel and
    the imports it needs, unless it has the channel already. Everything
    else in the file is kept. One with the channel from before shareFiles
    gets shareFiles."""
    if CHANNEL in text:
        shared = listen(wallpaper(install(share(text))))
        return text if shared == text else imported(shared)
    if len(ACTIVITY_CLASS.findall(text)) != 1:
        raise BrandError(
            f"{ACTIVITY} does not have one "
            "`class MainActivity : FlutterActivity()`; "
            "flutter create has changed what it writes"
        )
    if "configureFlutterEngine" in text:
        raise BrandError(
            f"{ACTIVITY} has a configureFlutterEngine of its own; "
            f"add the {CHANNEL} channel to it by hand"
        )
    text = imported(text)
    found = ACTIVITY_CLASS.search(text)
    rest = text[found.end() :]
    body = re.match(r"\s*\{", rest)
    if body:
        at = found.end() + body.end()
        return text[:at] + CHANNEL_MEMBERS + text[at:]
    if not re.match(r"[ \t]*(\n|$)", rest):
        raise BrandError(
            f"{ACTIVITY} declares MainActivity in a shape this does not know; "
            "flutter create has changed what it writes"
        )
    return text[: found.end()] + " {" + CHANNEL_MEMBERS + "}" + rest


def imported(text: str) -> str:
    """[text], MainActivity.kt, with an import for each of KOTLIN_IMPORTS
    it does not have, after the imports it has."""
    missing = [
        f"import {name}"
        for name in KOTLIN_IMPORTS
        if not re.search(rf"^import\s+{re.escape(name)}[ \t]*$", text, re.M)
    ]
    if not missing:
        return text
    imports = list(IMPORT.finditer(text))
    lines = "".join(f"\n{line}" for line in missing)
    if imports:
        at = imports[-1].end()
    elif package := PACKAGE.search(text):
        at, lines = package.end(), "\n" + lines
    else:
        at, lines = 0, lines.lstrip("\n") + "\n\n"
    return text[:at] + lines + text[at:]


def queries(
    text: str, action: str, scheme: str | None = None, mime: str | None = None
) -> bool:
    """Whether [text]'s <queries> has an intent for [action], and, if
    [scheme] or [mime] is given, for data in that scheme or of that type."""
    return any(
        f'android:name="{action}"' in intent
        and (scheme is None or f'android:scheme="{scheme}"' in intent)
        and (mime is None or f'android:mimeType="{mime}"' in intent)
        for block in QUERIES.findall(text)
        for intent in INTENT.findall(block)
    )


def query(text: str, *lines: str) -> str:
    """[text] with an <intent> of [lines] first in its <queries>, which is
    added if it has none."""
    body = "".join(f"\n            {line}" for line in lines)
    intent = f"<intent>{body}\n        </intent>"
    if "<queries>" in text:
        return text.replace("<queries>", f"<queries>\n        {intent}", 1)
    return text.replace(
        "</manifest>", f"    <queries>\n        {intent}\n    </queries>\n</manifest>", 1
    )


def declare(text: str) -> str:
    """[text], a manifest, with the microphone and internet permissions, the
    queries for the speech recogniser, the text-to-speech engine, its
    settings and its voice data, for opening https links, for UPI apps and for mail apps,
    and the FileProviders, ota_update's and the app's own, each added if it
    is not there already, and external storage removed."""
    if len(MANIFEST_OPEN.findall(text)) != 1 or text.count("</manifest>") != 1:
        raise BrandError(
            f"{MANIFEST} does not have one <manifest> element; "
            "flutter create has changed what it writes"
        )
    if text.count("    </application>") != 1:
        raise BrandError(
            f"{MANIFEST} does not have one <application> element; "
            "flutter create has changed what it writes"
        )
    for permission in (
        RECORD_AUDIO,
        INTERNET,
        POST_NOTIFICATIONS,
        RECEIVE_BOOT_COMPLETED,
    ):
        text = permit(text, permission)
    for permission in STORAGE:
        text = refuse(text, permission)
    text = provide(text)
    text = notify(text)
    for action in (RECOGNITION_SERVICE, TTS_SERVICE, TTS_SETTINGS, INSTALL_TTS_DATA):
        if not queries(text, action):
            text = query(text, f'<action android:name="{action}"/>')
    if not queries(text, VIEW, scheme="https"):
        text = query(
            text,
            f'<action android:name="{VIEW}"/>',
            '<data android:scheme="https"/>',
        )
    if not queries(text, VIEW, scheme="upi"):
        text = query(
            text,
            f'<action android:name="{VIEW}"/>',
            '<data android:scheme="upi"/>',
        )
    if not queries(text, VIEW, mime=APK_MIME):
        text = query(
            text,
            f'<action android:name="{VIEW}"/>',
            f'<data android:mimeType="{APK_MIME}"/>',
        )
    if not queries(text, SENDTO, scheme="mailto"):
        text = query(
            text,
            f'<action android:name="{SENDTO}"/>',
            '<data android:scheme="mailto"/>',
        )
    return text


def apply(root: Path) -> str:
    """Copies the brand's resources into [root]'s android/, sets the
    launcher label, declares what the app needs, sets up ota_update, gives
    MainActivity its channel and writes ShareFileProvider beside it.
    Returns the label."""
    manifest = root / MANIFEST
    if not manifest.is_file():
        raise BrandError(f"{MANIFEST} is missing; run flutter create first")
    text = manifest.read_text(encoding="utf-8")
    found = LABEL.findall(text)
    if len(found) != 1:
        raise BrandError(
            f"{MANIFEST} has {len(found)} android:label attributes, expected 1; "
            "flutter create has changed what it writes"
        )
    gradle = root / GRADLE
    if not gradle.is_file():
        raise BrandError(f"{GRADLE} is missing; run flutter create first")
    build = gradle.read_text(encoding="utf-8")
    if (
        "isCoreLibraryDesugaringEnabled" not in build
        and build.count("compileOptions {") != 1
    ):
        raise BrandError(
            f"{GRADLE} does not have one compileOptions block; "
            "flutter create has changed what it writes"
        )

    activity = root / ACTIVITY
    if not activity.is_file():
        raise BrandError(f"{ACTIVITY} is missing; run flutter create first")
    kotlin = activity.read_text(encoding="utf-8")
    channelled = channel(kotlin)

    name = app_name(root)
    label = f'android:label="{escape(name, {chr(34): "&quot;"})}"'
    # Everything is worked out before anything is written.
    declared = declare(LABEL.sub(lambda _: label, text))
    shutil.copytree(root / BRAND, root / RES, dirs_exist_ok=True)
    (root / OTA_PATHS).parent.mkdir(parents=True, exist_ok=True)
    (root / OTA_PATHS).write_text(PATHS, encoding="utf-8")
    (root / SHARE_PATHS).write_text(SHARE_PATHS_XML, encoding="utf-8")
    (root / SHARE_PROVIDER_FILE).write_text(SHARE_PROVIDER_KOTLIN, encoding="utf-8")
    manifest.write_text(declared, encoding="utf-8")
    gradle.write_text(desugar(build), encoding="utf-8")
    if channelled != kotlin:
        activity.write_text(channelled, encoding="utf-8")
    return name


def main() -> int:
    try:
        name = apply(ROOT)
    except BrandError as e:
        print(f"brand_android: {e}", file=sys.stderr)
        return 1
    print(f"Brand applied to {RES}; launcher label {name!r}; microphone, "
          "internet, notifications and their receivers, speech recogniser, text-to-speech settings, https and upi links and "
          "mail apps declared; ota_update set up; MainActivity's channel and "
          "ShareFileProvider written.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
