# ECS e-Connect Voice Programming Tool
## Complete Beginner Setup Guide — Phase 1

---

## WHAT YOU ARE BUILDING

A Flutter Android app that replaces PuTTY.  
It connects your Samsung phone to the ECS unit over USB and lets you read/update the APN.

**Phase 1** = a simple terminal (like PuTTY) so you can test the connection works.  
Phases 2, 3, 4 will add the real APN screens after you confirm Phase 1 works.

---

## WHAT YOU NEED BEFORE YOU START

| Item | Do you have it? |
|------|----------------|
| Windows PC | ✅ Yes |
| VS Code installed | ✅ Yes |
| Samsung Android phone | ✅ Yes |
| USB cable (phone to PC) | Need one |
| OTG adapter (phone to USB-A) | Need one |
| USB-to-RJ11 serial cable (CP210x chip) | ✅ Already have |
| ECS e-Connect Voice unit + power adapter | ✅ Already have |

---

## PART 1 — INSTALL FLUTTER ON YOUR WINDOWS PC

### Step 1.1 — Open PowerShell as Administrator

- Press the **Windows key**
- Type `PowerShell`
- Right-click **Windows PowerShell** → click **Run as administrator**
- Click **Yes**

### Step 1.2 — Install Flutter

Type this command and press Enter:

```powershell
winget install Google.Flutter
```

This downloads and installs Flutter automatically.  
It may take **5–10 minutes**. Wait for it to finish.

### Step 1.3 — Close PowerShell and open a NEW one

> Important: you must open a new PowerShell window so it picks up the new Flutter command.

- Close the current PowerShell window
- Open a new one (does not need to be Administrator this time)

### Step 1.4 — Check Flutter installed correctly

Type each command and press Enter:

```powershell
flutter --version
```

You should see something like:
```
Flutter 3.x.x • channel stable
```

Then run:
```powershell
flutter doctor --android-licenses
```

It will ask questions. **Press Y then Enter** for every single question.

Then run:
```powershell
flutter doctor
```

You want to see green checkmarks (✅) next to:
- Flutter
- Android toolchain
- VS Code

If you see a warning about "no connected devices" — that is fine for now.

> **If flutter doctor shows any RED errors, paste them to me before continuing.**

---

## PART 2 — PREPARE YOUR SAMSUNG PHONE

### Step 2.1 — Enable Developer Mode

1. On your phone, open **Settings**
2. Tap **About phone**
3. Tap **Software information**
4. Find **Build number**
5. **Tap "Build number" 7 times in a row**
6. Your phone will say: *"Developer mode has been enabled"*

### Step 2.2 — Turn on USB Debugging

1. Go back to **Settings**
2. You will now see a new menu called **Developer options** — tap it
3. Find **USB debugging** and turn it **ON**
4. Tap **OK** when it warns you

### Step 2.3 — Connect your phone to the PC

1. Plug your phone into the PC with a USB cable
2. On the phone screen, a popup will appear:  
   **"Allow USB debugging from this computer?"**
3. Tap **Allow** (tick the "Always allow" box too)

### Step 2.4 — Verify the phone is seen by Flutter

In PowerShell, type:

```powershell
flutter devices
```

You should see your Samsung phone listed. Example:
```
SM-G991B (mobile) • R5CX123456 • android-arm64 • Android 13
```

> **If nothing shows, try a different USB cable — many cables are charge-only and carry no data.**

---

## PART 3 — CREATE THE PROJECT

### Step 3.1 — Go to your Desktop

In PowerShell:

```powershell
cd C:\Users\YourName\Desktop
```

> Replace `YourName` with your actual Windows username.  
> Example: `cd C:\Users\John\Desktop`

### Step 3.2 — Create the Flutter project

```powershell
flutter create ecs_tool
```

This creates a new folder called `ecs_tool` on your Desktop with the Flutter skeleton inside.

### Step 3.3 — Open the project in VS Code

```powershell
cd ecs_tool
code .
```

VS Code will open with the project. You will see folders on the left side:
```
ecs_tool/
├── android/
├── lib/
├── pubspec.yaml
└── ... (other files)
```

---

## PART 4 — COPY THE PROJECT FILES

You need to create/replace **6 files**. Do them one at a time.

> **How to replace a file in VS Code:**
> 1. Click the file in the left panel to open it
> 2. Press `Ctrl+A` to select all text
> 3. Press `Delete` to delete everything
> 4. Paste the new content (`Ctrl+V`)
> 5. Press `Ctrl+S` to save

---

### FILE 1 — `pubspec.yaml`

**Location:** `ecs_tool/pubspec.yaml`  
**Action:** Open it, select all, delete, paste this, save.

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

**Location:** `ecs_tool/android/app/src/main/AndroidManifest.xml`  
**Action:** Open it, select all, delete, paste this, save.

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Required for USB Host (OTG) access — lets the phone act as USB master -->
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

            <!-- Normal app launch from home screen -->
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>

            <!-- Auto-launch when one of our USB devices is plugged in -->
            <intent-filter>
                <action android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED" />
            </intent-filter>

            <!-- Points to res/xml/device_filter.xml which lists our vendor IDs -->
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

> ⚠️ The folder `xml` does NOT exist yet. You must create it first.

**How to create the folder and file in VS Code:**
1. In the left panel, navigate to `android/app/src/main/res/`
2. Right-click the `res` folder → **New Folder** → name it `xml`
3. Right-click the new `xml` folder → **New File** → name it `device_filter.xml`
4. Paste this content and save:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!--
        IMPORTANT: Android requires vendor IDs in DECIMAL here, not hex.
        CP210x  : 0x10C4 = 4292
        FTDI    : 0x0403 = 1027
        CH340   : 0x1A86 = 6790
    -->

    <!-- Silicon Labs CP210x — most common chip in ECS serial cable -->
    <usb-device vendor-id="4292" />

    <!-- FTDI -->
    <usb-device vendor-id="1027" />

    <!-- CH340 / CH341 -->
    <usb-device vendor-id="6790" />

</resources>
```

---

### FILE 4 — `lib/constants.dart`

**Location:** `ecs_tool/lib/constants.dart`

> This file does NOT exist yet. Create it.

**How:** Right-click the `lib` folder → **New File** → name it `constants.dart` → paste this → save.

```dart
// ============================================================
// constants.dart
// ALL timings, serial settings, and protocol constants live
// here. Change a value once and it applies everywhere.
// ============================================================

class AppConstants {
  // Serial port settings
  static const int baudRate  = 115200;

  // Quiet-window timing
  // Wait this many ms of silence before sending a command.
  static const int quietWindowMs   = 300;
  // If the line never goes quiet, give up and send after this many ms.
  static const int quietTimeoutMs  = 2000;
  // Max ms to wait for a response after sending a command.
  static const int responseTimeoutMs = 3000;
  // Max ms to wait for ATI response during the connect handshake.
  static const int connectTimeoutMs  = 5000;

  // APN write settings
  // PDP type used in the write command.
  // Change to "IPV4V6" here when ECS confirms the correct type.
  static const String pdpType = 'IP';

  // Retry counts
  static const int readRetries  = 3;
  static const int writeRetries = 3;

  // Shared preferences keys
  static const String lastApnKey = 'last_apn';
  static const String defaultApn = 'reseller';
}
```

---

### FILE 5 — `lib/serial_service.dart`

**Location:** `ecs_tool/lib/serial_service.dart`

> This file does NOT exist yet. Create it.

**How:** Right-click the `lib` folder → **New File** → name it `serial_service.dart` → paste this → save.

```dart
// ============================================================
// serial_service.dart
// Handles the USB serial port:
//   - Finding the device
//   - Requesting Android permission
//   - Opening / closing
//   - Buffering bytes into lines
//   - Quiet-window send
// ============================================================

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

  // Subscribe to this stream to see every [TX] and [RX] line.
  Stream<String> get lines => _lineController.stream;

  // True when a port is currently open.
  bool get isConnected => _port != null;

  // ── CONNECT ────────────────────────────────────────────
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
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      _emit('[INFO] Port opened — ${AppConstants.baudRate} baud, 8N1.');
      return true;
    } catch (e, stack) {
      _emit('[ERROR] connect() exception: $e');
      _emit('[ERROR] $stack');
      return false;
    }
  }

  // ── DISCONNECT ─────────────────────────────────────────
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

  // ── SEND COMMAND ───────────────────────────────────────
  Future<void> sendCommand(String command) async {
    if (_port == null) {
      _emit('[ERROR] Not connected — cannot send "$command".');
      return;
    }

    // Wait for quiet window before sending
    final deadline = DateTime.now()
        .add(Duration(milliseconds: AppConstants.quietTimeoutMs));

    while (DateTime.now().isBefore(deadline)) {
      final silenceMs =
          DateTime.now().difference(_lastByteTime).inMilliseconds;
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

  // ── DISPOSE ────────────────────────────────────────────
  void dispose() {
    disconnect();
    _lineController.close();
  }

  // ── PRIVATE ────────────────────────────────────────────
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

### FILE 6 — `lib/main.dart`

**Location:** `ecs_tool/lib/main.dart`

> This file ALREADY EXISTS. Open it, select all (`Ctrl+A`), delete, paste this, save.

```dart
// ============================================================
// main.dart — Phase 1 "Mini PuTTY"
// One screen: Connect button + command field + scrolling log
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'serial_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const EcsToolApp());
}

class EcsToolApp extends StatelessWidget {
  const EcsToolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ECS e-Connect Tool',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const MiniPuttyScreen(),
    );
  }
}

class MiniPuttyScreen extends StatefulWidget {
  const MiniPuttyScreen({super.key});

  @override
  State<MiniPuttyScreen> createState() => _MiniPuttyScreenState();
}

class _MiniPuttyScreenState extends State<MiniPuttyScreen> {
  final SerialService _serial = SerialService();
  final List<String> _log = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _cmdController = TextEditingController();
  bool _connected  = false;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _serial.lines.listen((line) {
      if (!mounted) return;
      setState(() {
        _log.add(line);
        if (_log.length > 500) _log.removeAt(0);
      });
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _serial.dispose();
    _scrollController.dispose();
    _cmdController.dispose();
    super.dispose();
  }

  Future<void> _onConnectPressed() async {
    if (_connected) {
      await _serial.disconnect();
      if (mounted) setState(() => _connected = false);
      return;
    }
    if (mounted) setState(() => _connecting = true);
    final ok = await _serial.connect();
    if (mounted) setState(() { _connected = ok; _connecting = false; });
  }

  Future<void> _onSendPressed() async {
    final cmd = _cmdController.text.trim();
    if (cmd.isEmpty) return;
    if (!_connected) {
      if (mounted) setState(() => _log.add('[WARN] Not connected — tap Connect first.'));
      return;
    }
    await _serial.sendCommand(cmd);
    _cmdController.selection = TextSelection(
      baseOffset: 0, extentOffset: _cmdController.text.length,
    );
  }

  void _onClearLog() { if (mounted) setState(() => _log.clear()); }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 60), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('ECS Tool — Phase 1 Terminal',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.white54),
            tooltip: 'Clear log',
            onPressed: _onClearLog,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Connect button
              _connecting
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.redAccent)),
                          SizedBox(width: 12),
                          Text('Connecting…',
                              style: TextStyle(color: Colors.white70, fontSize: 15)),
                        ],
                      ),
                    )
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _connected ? Colors.green.shade700 : Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: Icon(_connected ? Icons.usb_off : Icons.usb),
                      label: Text(_connected ? 'Disconnect' : 'Connect to Unit',
                          style: const TextStyle(fontSize: 16)),
                      onPressed: _onConnectPressed,
                    ),
              const SizedBox(height: 12),
              // Command input row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cmdController,
                      style: const TextStyle(fontFamily: 'monospace', color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'e.g.  ATI   or   AT+CGDCONT?',
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: const Color(0xFF2A2A2A),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onSubmitted: (_) => _onSendPressed(),
                      textInputAction: TextInputAction.send,
                      autocorrect: false,
                      enableSuggestions: false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.red.withOpacity(0.3),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _connected ? _onSendPressed : null,
                    child: const Text('Send', style: TextStyle(fontSize: 15)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Status dot
              Row(
                children: [
                  Icon(_connected ? Icons.circle : Icons.circle_outlined,
                      size: 11, color: _connected ? Colors.greenAccent : Colors.red),
                  const SizedBox(width: 6),
                  Text(_connected ? 'Connected' : 'Not connected',
                      style: TextStyle(
                          color: _connected ? Colors.greenAccent : Colors.redAccent, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),
              // Scrolling log
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0D0D),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: _log.isEmpty
                      ? const Center(
                          child: Text('Log is empty.\nTap Connect, then type a command.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white24, fontSize: 13)))
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(8),
                          itemCount: _log.length,
                          itemBuilder: (context, index) {
                            final line = _log[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 1.0),
                              child: Text(line,
                                  style: TextStyle(
                                      fontFamily: 'monospace', fontSize: 12,
                                      height: 1.5, color: _colorForLine(line))),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _colorForLine(String line) {
    if (line.startsWith('[TX]'))    return Colors.cyanAccent;
    if (line.startsWith('[RX]'))    return Colors.greenAccent;
    if (line.startsWith('[ERROR]')) return Colors.redAccent;
    if (line.startsWith('[WARN]'))  return Colors.orangeAccent;
    return Colors.white60;
  }
}
```

---

## PART 5 — RUN THE APP

Open the **VS Code terminal** (`Ctrl` + `` ` ``) and type these commands one at a time:

```powershell
flutter pub get
```
> Downloads all packages. Wait for it to finish.

```powershell
flutter devices
```
> Should show your Samsung phone. If nothing shows, check USB cable and USB debugging.

```powershell
flutter run
```
> Builds and installs the app on your phone. First time takes 3–5 minutes. Normal.

---

## PART 6 — TEST CHECKLIST

Do every test below. Tick them off as you go.

| # | What to do | What you should see |
|---|-----------|---------------------|
| 1 | App launches | Dark screen, red "Connect to Unit" button |
| 2 | Tap Connect **without** any cable plugged in | Log shows: `[INFO] No USB serial devices found.` |
| 3 | Plug in OTG + serial cable, tap Connect | A popup appears: **"Allow ECS Tool to access the USB device?"** |
| 4 | Tap **Allow** on the popup | Log shows: `[INFO] Port opened — 115200 baud, 8N1.` Button turns green |
| 5 | Type `ATI` in the text box, tap Send | Log shows `[TX] ATI` in **cyan**, then green `[RX]` lines below |
| 6 | Look at the RX lines from ATI | Should see the modem model and revision e.g. `EC25EUXGAR08A17M1G` |
| 7 | Type `AT+CGDCONT?`, tap Send | See a line like: `[RX] +CGDCONT: 1,"IPV4V6","gpinternet","0.0.0.0",0,0` |
| 8 | Unplug the serial cable while connected | Log shows: `[INFO] Cable disconnected.` App does NOT crash |
| 9 | Tap Disconnect | Log shows: `[INFO] Port closed.` Button goes back to red |

---

## PART 7 — COMMON PROBLEMS AND FIXES

### Problem: `flutter` is not recognised as a command
**Fix:** Close all PowerShell windows and open a new one. If still broken, restart your PC.

### Problem: `flutter devices` shows nothing
**Fix:**
- Try a different USB cable (many cables are power-only, no data)
- On the phone, go to Settings → Developer options → Revoke USB debugging authorisations → reconnect → tap Allow again

### Problem: Build fails with red errors in the terminal
**Fix:** Run these three commands in order:
```powershell
flutter clean
flutter pub get
flutter run
```

### Problem: App crashes immediately on launch
**Fix:** Run `flutter run` (not flutter install) and read the red error text in the terminal. Paste the exact error text to me and I will fix it for you.

### Problem: Tapped Allow on USB permission but nothing happens
**Fix:** Unplug cable, wait 5 seconds, replug, tap Connect again.

---

## PART 8 — BUILDING THE FINAL APK (Phase 4 — do this later)

> Do NOT do this yet. Only after all phases are complete and working.

When you are ready:

```powershell
flutter build apk --release
```

The APK file will be at:
```
ecs_tool\build\app\outputs\flutter-apk\app-release.apk
```

Copy that file to your phone and install it. You will need to allow "Install from unknown sources" in your phone settings.

---

## SUMMARY — FILE LOCATIONS

```
ecs_tool/
│
├── pubspec.yaml                                   ← FILE 1 (replace)
│
├── android/
│   └── app/
│       └── src/
│           └── main/
│               ├── AndroidManifest.xml            ← FILE 2 (replace)
│               └── res/
│                   └── xml/                       ← CREATE this folder
│                       └── device_filter.xml      ← FILE 3 (new file)
│
└── lib/
    ├── main.dart                                  ← FILE 6 (replace)
    ├── constants.dart                             ← FILE 4 (new file)
    └── serial_service.dart                        ← FILE 5 (new file)
```

---

## WHEN YOU ARE DONE WITH PHASE 1

Once all 9 tests in Part 6 pass, come back and tell me:

> **"Phase 1 done"**

I will then build Phase 2: the APN read/write logic with noisy-line handling.

---

*Guide version: Phase 1 — September 2026*
