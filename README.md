# ECS e-Connect Voice Programming Tool

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=flat-square&logo=Flutter&logoColor=white)](https://flutter.dev)
[![Android](https://img.shields.io/badge/Android-3DDC84?style=flat-square&logo=android&logoColor=white)](https://developer.android.com)
[![Version](https://img.shields.io/badge/Version-1.0.12-red.svg?style=flat-square)](https://github.com/tanvirnabil/E-Connect-App)
[![License](https://img.shields.io/badge/License-Proprietary-blue.svg?style=flat-square)](#)

A dedicated, mobile-first engineering and configuration tool built with Flutter for field technicians managing **ECS e-Connect Voice** cellular elevator emergency phone terminals (FWT-8848 series and Quectel EC25 cellular modems).

The tool establishes a direct hardware bridge over USB-to-Serial OTG to query device diagnostics, program cellular Access Point Names (APN), verify carrier settings directly against modem memory, and flash updated firmware over the serial link using the XMODEM-1K protocol.

---

## 📱 Key Features

### 1. High-Reliability USB Serial Bridge
* Connects directly to hardware terminals using standard Android USB OTG cables.
* Compatible with major USB-UART bridge chipsets (FTDI, Prolific PL2303, Silicon Labs CP210x, and WCH CH340/CH341).
* Configured for **115,200 Baud, 8 Data Bits, 1 Stop Bit, No Parity (8N1)**.
* Built-in noise filtration and dynamic quiet-window detection (300 ms silence guard) to prevent command collision with unsolicited modem outputs (URCs).

### 2. Cellular APN Configuration & Verification
* **Auto-Discovery**: Automatically queries and parses active PDP context (`AT+CGDCONT?`).
* **Hardware-Verified Writes**: Writes new APNs (`AT+CGDCONT=1,"IP","<APN>"`) and immediately reads back from modem non-volatile memory to guarantee changes took effect.
* **Smart Defaults**: Defaults to **`ERESELLER`** out-of-the-box with validation for RFC-compliant network strings.
* **Persistent Cache**: Remembers previously applied APNs via local storage for rapid multi-device programming.

### 3. Firmware Flasher (XMODEM-1K Protocol)
* In-field binary updates for terminal microcontrollers and modem interfaces.
* Implements the **XMODEM-1K** protocol with 1024-byte block framing and **CRC-16** error detection.
* Real-time transfer metrics (progress bar, packet count, transfer speed, and transmission logs).
* Automatic retry and NAK/CAN cancellation handling.

### 4. Hardware Diagnostics & Device Identification
* Reads modem manufacturing information via `ATI` interrogation.
* Displays model identification, baseband firmware revision, and detected MCU boot info.
* Detects hardware compatibility (standard Quectel EC25 vs. alternate modular boards).

### 5. Diagnostics & Field Telemetry
* Live terminal streaming console to observe raw AT command/response transactions.
* Automated error tracing and crash reporting via background ingestion endpoints (`LogService`).

---

## 🏗️ Architecture & Project Structure

```
ecs_tool/
├── android/                        # Android host wrapper & permissions
│   └── app/src/main/
│       ├── AndroidManifest.xml     # USB device permissions & intent filters
│       └── res/xml/device_filter.xml # Auto-attach filters for UART chips
├── assets/                         # Graphic assets and icons
│   └── images/logo.png
├── lib/
│   ├── main.dart                   # Multi-screen UI (Welcome, Connecting, Main APN & Flash)
│   ├── apn_service.dart            # AT protocol engine, command queues & APN verification
│   ├── serial_service.dart         # USB serial stream controller and byte buffers
│   ├── xmodem_service.dart         # XMODEM-1K firmware upload protocol implementation
│   ├── firmware_info.dart          # Firmware header parser and build metadata model
│   ├── constants.dart              # Global timeouts, baud rates, retry counts & default APN
│   └── log_service.dart            # Remote logging and diagnostic ingestion client
├── test/
│   └── widget_test.dart            # Unit and smoke test suites
└── pubspec.yaml                    # Dependencies and application metadata
```

---

## 🚀 Getting Started

### Prerequisites
* **Flutter SDK**: `>= 3.0.0 < 4.0.0`
* **Android SDK**: `compileSdk 35`, `minSdk 21`
* **Java Development Kit**: JDK 17
* **Hardware**: Android phone/tablet with USB Host (OTG) support and a compatible USB-to-Serial adapter cable.

### Installation & Build

1. **Clone the repository:**
   ```bash
   git clone https://github.com/tanvirnabil/E-Connect-App.git
   cd E-Connect-App
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Verify the environment:**
   ```bash
   flutter doctor
   ```

4. **Build Release APK:**
   ```bash
   flutter build apk --release
   ```
   The compiled APK will be located at:
   `build/app/outputs/flutter-apk/app-release.apk`

---

## 🛠️ Field Usage Instructions

1. **Physical Connection**:
   * Connect your phone to the ECS terminal using a USB OTG cable connected to the terminal's programming serial port.
2. **Launch Application**:
   * Open the app; grant the USB device permission prompt when requested by Android.
3. **Connect to Unit**:
   * Tap **Connect to Unit**. The app executes an initial handshake and displays the detected hardware and firmware version.
4. **Configure APN**:
   * Switch to the **APN Configuration** tab.
   * Verify the current APN read from the device.
   * Enter the new APN (defaults to `ERESELLER`).
   * Tap **Update APN**. The app programs the unit, re-reads memory, and displays a verified confirmation banner.
5. **Firmware Updates (Optional)**:
   * Switch to the **Firmware Flasher** tab.
   * Select a valid firmware `.bin` file.
   * Initiate upload and monitor XMODEM-1K progress until reboot confirmation.

---

## ⚙️ Configuration & Customization

All hardware timing windows, retry parameters, and default values are centralized in [`lib/constants.dart`](lib/constants.dart):

```dart
class AppConstants {
  static const int baudRate          = 115200;
  static const int quietWindowMs     = 300;     // Quiet window for AT traffic
  static const int responseTimeoutMs = 3000;    // Max wait for AT response
  static const int connectTimeoutMs  = 5000;    // Handshake timeout
  static const String pdpType        = 'IP';    // PDP Context Type
  static const int writeRetries      = 3;       // Retries for failed write-verify cycles
  static const String defaultApn     = 'ERESELLER'; // Default cellular APN
}
```

---

## 🔒 Security & Privacy

* This application communicates exclusively over direct point-to-point hardware serial links.
* No cellular data or private credentials are stored in unencrypted form.
* Serial traffic logs in debug mode remain local to the runtime session unless explicitly ingested via the diagnostic log service.

---

## 📄 License & Maintainer

Maintained for **ECS (Elevator Communication Systems)** operations and deployments.  
Repository: [tanvirnabil/E-Connect-App](https://github.com/tanvirnabil/E-Connect-App)
