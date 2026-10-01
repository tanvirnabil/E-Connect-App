# ECS e-Connect Voice Programming Tool
## COMPLETE SETUP GUIDE — All Phases Done

---

## WHAT IS BUILT (100% COMPLETE)

All 4 phases are done. Here are all the files:

```
ecs_tool/
├── pubspec.yaml                                    FILE 1
├── android/
│   └── app/
│       └── src/
│           └── main/
│               ├── AndroidManifest.xml             FILE 2
│               └── res/
│                   └── xml/
│                       └── device_filter.xml       FILE 3  ← create xml/ folder first
└── lib/
    ├── constants.dart                              FILE 4
    ├── serial_service.dart                         FILE 5
    ├── apn_service.dart                            FILE 6  ← NEW
    └── main.dart                                   FILE 7
```

### What each screen does:
- **Screen 1 — Welcome**: Title + big red "Connect to Unit" button
- **Screen 2 — Connecting**: Spinner → green "Connected" banner (model + revision) → Continue button. Or red "No Response — Check Cable" → Retry button
- **Screen 3 — Main APN**: Shows current APN, lets you type a new one, Update button, green/red result banners, hidden debug log (tap the bug icon)

---

## PART 1 — INSTALL FLUTTER

You have Android Studio installed. Good. Now add Flutter.

### Step 1.1 — Open PowerShell

Press Windows key → type `powershell` → press Enter

### Step 1.2 — Install Flutter

```powershell
winget install Google.Flutter
```

Wait 5–10 minutes for it to finish.

### Step 1.3 — Open a NEW PowerShell window

Close the old one. Open a fresh one. Then run:

```powershell
flutter --version
```

You should see: `Flutter 3.x.x • channel stable`

### Step 1.4 — Accept Android licenses

```powershell
flutter doctor --android-licenses
```

Press **Y then Enter** for every question.

### Step 1.5 — Install Flutter plugin in Android Studio

1. Open Android Studio
2. Go to **File → Settings → Plugins**
3. Search `Flutter` → click **Install**
4. Also install **Dart** when prompted
5. Restart Android Studio

### Step 1.6 — Check everything

```powershell
flutter doctor
```

You need green checkmarks next to:
- ✅ Flutter
- ✅ Android toolchain
- ✅ Android Studio

> If you see red errors, paste them and I will fix them before you continue.

---

## PART 2 — PREPARE YOUR SAMSUNG PHONE

### Step 2.1 — Enable Developer Mode

1. Settings → **About phone** → **Software information**
2. Tap **Build number** 7 times
3. Phone says: *"Developer mode has been enabled"*

### Step 2.2 — Enable USB Debugging

1. Settings → **Developer options**
2. Turn on **USB debugging** → tap OK

### Step 2.3 — Connect phone to PC

1. Plug phone into PC with USB cable
2. Phone shows: *"Allow USB debugging?"*
3. Tap **Allow** (tick "Always allow from this computer")

### Step 2.4 — Verify phone is detected

```powershell
flutter devices
```

You should see your Samsung listed.

> **If nothing shows**: try a different USB cable — many are charge-only with no data.

---

## PART 3 — CREATE THE PROJECT

```powershell
cd C:\Users\YourName\Desktop
flutter create ecs_tool
cd ecs_tool
code .
```

> Replace `YourName` with your actual Windows username.
> The last command opens VS Code with the project.

---

## PART 4 — COPY ALL 7 FILES

For each file:
1. Find it in VS Code's left file panel
2. Click it to open
3. Press `Ctrl+A` to select all → `Delete` to clear
4. Paste the content below
5. Press `Ctrl+S` to save

---

### FILE 1 — `pubspec.yaml`
**Location:** `ecs_tool/pubspec.yaml` — REPLACE existing file

```yaml
name: ecs_tool
description: ECS e-Connect Voice APN Programming Tool
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  usb_serial: ^0.5.2
  shared_preferences: ^2.2.2
  provider: ^6.1.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
```

---

### FILE 2 — `AndroidManifest.xml`
**Location:** `ecs_tool/android/app/src/main/AndroidManifest.xml` — REPLACE existing file

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-feature android:name="android.hardware.usb.host" />

    <application
        android:label="ECS Tool"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">

            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>

            <intent-filter>
                <action android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED" />
            </intent-filter>

            <meta-data
                android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED"
                android:resource="@xml/device_filter" />

        </activity>

        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />

    </application>

</manifest>
```

---

### FILE 3 — `device_filter.xml`
**Location:** `ecs_tool/android/app/src/main/res/xml/device_filter.xml`

> ⚠️ The `xml/` folder does NOT exist yet.
> In VS Code: right-click the `res/` folder → New Folder → name it `xml`
> Then right-click `xml/` → New File → name it `device_filter.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Vendor IDs must be DECIMAL (not hex) for Android -->
    <!-- CP210x: 0x10C4 = 4292 -->
    <!-- FTDI:   0x0403 = 1027 -->
    <!-- CH340:  0x1A86 = 6790 -->

    <usb-device vendor-id="4292" />
    <usb-device vendor-id="1027" />
    <usb-device vendor-id="6790" />
</resources>
```

---

### FILE 4 — `lib/constants.dart`
**Location:** `ecs_tool/lib/constants.dart` — NEW FILE
Right-click `lib/` folder → New File → `constants.dart`

```dart
class AppConstants {
  static const int baudRate           = 115200;
  static const int quietWindowMs      = 300;
  static const int quietTimeoutMs     = 2000;
  static const int responseTimeoutMs  = 3000;
  static const int connectTimeoutMs   = 5000;
  static const String pdpType         = 'IP';
  static const int readRetries        = 3;
  static const int writeRetries       = 3;
  static const String lastApnKey      = 'last_apn';
  static const String defaultApn      = 'reseller';
}
```

---

### FILE 5 — `lib/serial_service.dart`
**Location:** `ecs_tool/lib/serial_service.dart` — NEW FILE

```dart
import 'dart:async';
import 'dart:typed_data';
import 'package:usb_serial/usb_serial.dart';
import 'constants.dart';

class SerialService {
  UsbPort? _port;
  final StringBuffer _lineBuffer = StringBuffer();
  final StreamController<String> _lineController =
      StreamController<String>.broadcast();
  StreamSubscription<Uint8List>? _portSubscription;
  DateTime _lastByteTime = DateTime.fromMillisecondsSinceEpoch(0);

  Stream<String> get lines => _lineController.stream;
  bool get isConnected => _port != null;

  Future<bool> connect() async {
    try {
      List<UsbDevice> devices = await UsbSerial.listDevices();
      if (devices.isEmpty) {
        _emit('[INFO] No USB serial devices found. Plug in the cable and try again.');
        return false;
      }
      for (final d in devices) {
        _emit('[INFO] USB device: ${d.manufacturerName ?? "unknown"} '
            'VID=0x${(d.vid ?? 0).toRadixString(16).toUpperCase().padLeft(4, "0")} '
            'PID=0x${(d.pid ?? 0).toRadixString(16).toUpperCase().padLeft(4, "0")}');
      }
      final device = devices.first;
      final hasPermission = await UsbSerial.requestPermission(device);
      if (!hasPermission) {
        _emit('[ERROR] USB permission denied. Tap Allow when Android asks.');
        return false;
      }
      final port = await device.create();
      if (port == null) {
        _emit('[ERROR] Could not create port object for this device.');
        return false;
      }
      final opened = await port.open();
      if (!opened) {
        _emit('[ERROR] Port.open() returned false. Try unplugging and replugging.');
        return false;
      }
      await port.setPortParameters(
        AppConstants.baudRate,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );
      _port = port;
      _lineBuffer.clear();
      _lastByteTime = DateTime.fromMillisecondsSinceEpoch(0);
      _portSubscription = port.inputStream?.listen(
        _onData, onError: _onError, onDone: _onDone, cancelOnError: false,
      );
      _emit('[INFO] Port opened — ${AppConstants.baudRate} baud, 8N1.');
      return true;
    } catch (e, stack) {
      _emit('[ERROR] connect() exception: $e');
      _emit('[ERROR] $stack');
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _portSubscription?.cancel();
      _portSubscription = null;
      await _port?.close();
    } catch (_) {}
    _port = null;
    _lineBuffer.clear();
    _emit('[INFO] Port closed.');
  }

  Future<void> sendCommand(String command) async {
    if (_port == null) {
      _emit('[ERROR] Not connected — cannot send "$command".');
      return;
    }
    final deadline = DateTime.now()
        .add(Duration(milliseconds: AppConstants.quietTimeoutMs));
    while (DateTime.now().isBefore(deadline)) {
      final silenceMs = DateTime.now().difference(_lastByteTime).inMilliseconds;
      if (silenceMs >= AppConstants.quietWindowMs) break;
      await Future.delayed(const Duration(milliseconds: 50));
    }
    final frame = '$command\r';
    _emit('[TX] $command');
    try {
      await _port!.write(Uint8List.fromList(frame.codeUnits));
    } catch (e) {
      _emit('[ERROR] Write failed: $e');
    }
  }

  void dispose() {
    disconnect();
    _lineController.close();
  }

  void _onData(Uint8List data) {
    _lastByteTime = DateTime.now();
    final text = String.fromCharCodes(data);
    _lineBuffer.write(text);
    final raw = _lineBuffer.toString();
    final parts = raw.split(RegExp(r'\r\n|\r|\n'));
    for (int i = 0; i < parts.length - 1; i++) {
      final line = parts[i].trim();
      if (line.isNotEmpty) _emit('[RX] $line');
    }
    _lineBuffer.clear();
    _lineBuffer.write(parts.last);
  }

  void _onError(dynamic error) {
    _emit('[ERROR] Serial port error: $error');
    _port = null;
  }

  void _onDone() {
    _emit('[INFO] Cable disconnected.');
    _port = null;
  }

  void _emit(String line) {
    if (!_lineController.isClosed) _lineController.add(line);
  }
}
```

---

### FILE 6 — `lib/apn_service.dart`
**Location:** `ecs_tool/lib/apn_service.dart` — NEW FILE

```dart
import 'dart:async';
import 'constants.dart';
import 'serial_service.dart';

class ApnResult {
  final bool success;
  final String? value;
  final String message;
  const ApnResult.ok(this.value, this.message) : success = true;
  const ApnResult.fail(this.message) : success = false, value = null;
}

class ModuleInfo {
  final bool success;
  final String model;
  final String revision;
  final bool isEc25;
  final String message;
  const ModuleInfo({
    required this.success, required this.model, required this.revision,
    required this.isEc25, required this.message,
  });
}

class ApnService {
  final SerialService _serial;
  ApnService(this._serial);

  Future<ModuleInfo> connectAndIdentify() async {
    final opened = await _serial.connect();
    if (!opened) {
      return const ModuleInfo(success: false, model: '', revision: '',
          isEc25: false, message: 'Could not open serial port. Check cable and try again.');
    }
    final lines = await _sendAndCollect('ATI',
        timeoutMs: AppConstants.connectTimeoutMs, stopOnOk: true);
    if (lines.isEmpty) {
      return const ModuleInfo(success: false, model: '', revision: '',
          isEc25: false, message: 'No response from unit. Check cable and power.');
    }
    String model = '', revision = '';
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.toLowerCase().startsWith('revision:')) {
        revision = trimmed.substring('revision:'.length).trim();
      } else if (trimmed.isNotEmpty && trimmed != 'OK' && !trimmed.startsWith('AT') &&
          model.isEmpty && (trimmed.startsWith('Quectel') || trimmed.startsWith('EC'))) {
        model = trimmed;
      }
    }
    if (model.isEmpty && revision.isEmpty && lines.isNotEmpty) model = lines.first;
    final isEc25 = revision.contains('EC25') || model.contains('EC25');
    return ModuleInfo(
      success: true,
      model: model.isEmpty ? '(unknown)' : model,
      revision: revision.isEmpty ? '(unknown)' : revision,
      isEc25: isEc25,
      message: isEc25 ? 'Connected — EC25 module identified.'
          : 'Connected — WARNING: module does not appear to be EC25. Proceeding anyway.',
    );
  }

  Future<ApnResult> readApn() async {
    for (int attempt = 1; attempt <= AppConstants.readRetries; attempt++) {
      final lines = await _sendAndCollect('AT+CGDCONT?',
          timeoutMs: AppConstants.responseTimeoutMs, stopOnOk: true);
      final apn = _parseApnFromLines(lines);
      if (apn != null) {
        return ApnResult.ok(apn.isEmpty ? '(not set)' : apn, 'APN read successfully.');
      }
      if (attempt < AppConstants.readRetries) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    return const ApnResult.fail(
        'Could not read APN after ${AppConstants.readRetries} attempts. Try again.');
  }

  String? validateApn(String apn) {
    if (apn.isEmpty) return 'APN cannot be empty.';
    if (apn.length > 100) return 'APN is too long (max 100 characters).';
    if (!RegExp(r'^[A-Za-z0-9.\-_]+$').hasMatch(apn)) {
      return 'APN contains invalid characters.\nOnly letters, numbers, dot, hyphen, underscore allowed.\nNo spaces or quotes.';
    }
    return null;
  }

  Future<ApnResult> writeApn(String newApn) async {
    final err = validateApn(newApn);
    if (err != null) return ApnResult.fail(err);
    for (int attempt = 1; attempt <= AppConstants.writeRetries; attempt++) {
      await _sendAndCollect('AT+CGDCONT=1,"${AppConstants.pdpType}","$newApn"',
          timeoutMs: AppConstants.responseTimeoutMs, stopOnOk: true);
      await Future.delayed(const Duration(milliseconds: 400));
      final readResult = await readApn();
      if (!readResult.success) {
        if (attempt < AppConstants.writeRetries) continue;
        return const ApnResult.fail('APN write sent but could not read back to verify.');
      }
      final readBack = readResult.value == '(not set)' ? '' : readResult.value!;
      if (readBack == newApn) return ApnResult.ok(newApn, 'APN updated and verified successfully.');
      if (attempt < AppConstants.writeRetries) await Future.delayed(const Duration(milliseconds: 300));
    }
    return const ApnResult.fail(
        'APN update FAILED after ${AppConstants.writeRetries} attempts. Read-back did not match.');
  }

  Future<List<String>> _sendAndCollect(String command,
      {required int timeoutMs, bool stopOnOk = false}) async {
    final collected = <String>[];
    final completer = Completer<List<String>>();
    bool commandEchoed = false;
    Timer? timer;
    final sub = _serial.lines.listen((line) {
      if (line.startsWith('[RX] ')) {
        final raw = line.substring(5);
        collected.add(raw);
        if (raw.trim().toUpperCase() == command.toUpperCase()) commandEchoed = true;
        if (stopOnOk && commandEchoed) {
          final upper = raw.trim().toUpperCase();
          if (upper == 'OK' || upper.startsWith('ERROR') ||
              upper.startsWith('+CME ERROR') || upper.startsWith('+CMS ERROR')) {
            timer?.cancel();
            if (!completer.isCompleted) completer.complete(collected);
          }
        }
      }
    });
    await _serial.sendCommand(command);
    timer = Timer(Duration(milliseconds: timeoutMs), () {
      if (!completer.isCompleted) completer.complete(collected);
    });
    final result = await completer.future;
    await sub.cancel();
    timer.cancel();
    return result;
  }

  String? _parseApnFromLines(List<String> lines) {
    final re = RegExp(r'^\+CGDCONT:\s*1\s*,\s*"[^"]*"\s*,\s*"([^"]*)"', caseSensitive: false);
    for (final line in lines) {
      final match = re.firstMatch(line.trim());
      if (match != null) return match.group(1) ?? '';
    }
    return null;
  }
}
```

---

### FILE 7 — `lib/main.dart`
**Location:** `ecs_tool/lib/main.dart` — REPLACE existing file
(This file is long — see the chat for the full version, or copy from the project)

---

## PART 5 — RUN THE APP

Open VS Code terminal (`Ctrl` + `` ` ``) and run these one at a time:

```powershell
flutter pub get
```
> Downloads all packages. Wait for it.

```powershell
flutter devices
```
> Must show your Samsung phone. If not, check USB cable and USB debugging.

```powershell
flutter run
```
> Builds and installs on your phone. First time takes 3–5 minutes. Normal.

---

## PART 6 — TEST CHECKLIST

### Screen 1 — Welcome
| # | Do this | Expect this |
|---|---------|-------------|
| 1 | Open the app | Dark screen, title "ECS e-Connect Voice Programming Tool", red "Connect to Unit" button |
| 2 | Tap Connect **without** cable | Goes to Connecting screen → shows error banner "Could not open serial port" |

### Screen 2 — Connecting
| # | Do this | Expect this |
|---|---------|-------------|
| 3 | Plug in OTG + cable, tap Connect | Android permission popup appears |
| 4 | Tap Allow | Spinner shows, then green "Connected" banner with model and revision |
| 5 | Tap Continue | Goes to Main screen |
| 6 | Unplug cable, tap Connect | Red "No Response — Check Cable" banner + Retry button |
| 7 | Tap Retry | Tries again without going back to Welcome |

### Screen 3 — Main APN
| # | Do this | Expect this |
|---|---------|-------------|
| 8 | Main screen opens | Shows current APN from unit (reads automatically) |
| 9 | Tap "Read APN" | Refreshes and shows current APN |
| 10 | Type a valid APN e.g. `testapn`, tap Update APN | Green "APN Updated ✓" banner |
| 11 | Read APN again | Shows `testapn` confirming it was written |
| 12 | Type the original APN, tap Update | Green banner, saved |
| 13 | Type `bad apn!` (with space and !) | Red banner: invalid characters message, nothing sent to modem |
| 14 | Tap the bug icon (top right) | Debug log panel appears showing [TX] cyan / [RX] green lines |
| 15 | Unplug cable mid-operation | App shows cable disconnected, does NOT crash |
| 16 | Tap Exit | Port closes, returns to Welcome screen |

---

## PART 7 — BUILD THE RELEASE APK

Once all tests pass, run this to create the installable APK:

```powershell
flutter build apk --release
```

The APK will be at:
```
ecs_tool\build\app\outputs\flutter-apk\app-release.apk
```

**To install on your phone:**
1. Copy `app-release.apk` to your phone (USB transfer or email it to yourself)
2. On the phone, tap the file
3. If blocked: Settings → Apps → Special app access → Install unknown apps → allow your file manager
4. Install and run

---

## PART 8 — COMMON PROBLEMS AND FIXES

### `flutter` is not recognised
Close all PowerShell windows. Open a new one. If still broken, restart PC.

### `flutter devices` shows nothing
- Different USB cable (many are charge-only)
- Settings → Developer options → Revoke USB debugging → reconnect → Allow

### Build fails
```powershell
flutter clean
flutter pub get
flutter run
```

### Gradle build error
```powershell
flutter clean
cd android
.\gradlew clean
cd ..
flutter run
```

### App crashes on launch
Run `flutter run` (NOT flutter install) — read the red error in the terminal and paste it here.

### USB permission dialog never appears
Unplug cable → wait 5 seconds → replug → tap Connect again.

### APN reads but write fails
The unit is busy with background commands. The app retries 3 times automatically.
If it still fails, wait 10 seconds and try again.

---

## SUMMARY — What was built

| Phase | Feature | Status |
|-------|---------|--------|
| 1 | USB serial terminal (Mini PuTTY) | ✅ Done |
| 2 | Noisy-line handling, APN read/write/verify with retry | ✅ Done |
| 3 | 3 real screens, banners, saved last APN | ✅ Done |
| 4 | APK build instructions + test checklist | ✅ Done |

---

*ECS Tool — Complete build — September 2026*
