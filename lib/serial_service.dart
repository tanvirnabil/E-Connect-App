// ============================================================
// serial_service.dart
//
// Handles everything to do with the physical USB serial port:
//   • Finding and listing USB serial devices
//   • Requesting Android USB permission
//   • Opening / closing the port
//   • Buffering incoming bytes and splitting them into lines
//   • "Quiet-window" send: waits for line silence before TX
//   • Emitting every line (TX and RX) on a broadcast stream
//     so the UI and APN logic can both subscribe
//
// Does NOT know anything about AT commands or APN logic.
// ============================================================

import 'dart:async';
import 'dart:typed_data';

import 'package:usb_serial/usb_serial.dart';

import 'constants.dart';
import 'log_service.dart';

class SerialService {
  // ── State ───────────────────────────────────────────────
  UsbPort? _port;

  /// Incomplete line fragment waiting for its terminator.
  final StringBuffer _lineBuffer = StringBuffer();

  /// Every complete RX line and every TX line are broadcast here.
  final StreamController<String> _lineController =
      StreamController<String>.broadcast();

  /// Raw byte stream controller for binary transfers (e.g. Xmodem)
  final StreamController<Uint8List> _rawByteController =
      StreamController<Uint8List>.broadcast();

  /// When the last byte arrived from the port.
  DateTime _lastByteTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Subscription to the underlying port input stream.
  StreamSubscription<Uint8List>? _portSubscription;

  // ── Public API ───────────────────────────────────────────

  /// Stream of formatted lines — prefix is [TX], [RX], [INFO], or [ERROR].
  Stream<String> get lines => _lineController.stream;

  /// Stream of raw incoming byte chunks (used by Xmodem-1k flasher).
  Stream<Uint8List> get rawBytes => _rawByteController.stream;

  /// True if the serial port is currently open.
  bool get isConnected => _port != null;

  // ── Connect ─────────────────────────────────────────────

  /// Attempts to find an attached USB serial device, request permission,
  /// open the port, configure it for 115200 8N1, and begin listening.
  ///
  /// Never throws — all errors are emitted as [ERROR] log lines.
  Future<bool> connect() async {
    try {
      // 1. List attached USB serial devices.
      List<UsbDevice> devices = await UsbSerial.listDevices();

      if (devices.isEmpty) {
        _emit('[INFO] No USB serial devices found. Plug in the cable and try again.');
        LogService.warn('SerialService', 'No USB serial devices found. Plug in cable.');
        return false;
      }

      // Log every device found (useful for debugging unknown hardware).
      for (final d in devices) {
        final infoStr = 'USB device: ${d.manufacturerName ?? "unknown"} '
            'VID=0x${(d.vid ?? 0).toRadixString(16).toUpperCase().padLeft(4, "0")} '
            'PID=0x${(d.pid ?? 0).toRadixString(16).toUpperCase().padLeft(4, "0")}';
        _emit('[INFO] $infoStr');
      }

      // Use the first device.
      final device = devices.first;
      final devId = 'VID=0x${(device.vid ?? 0).toRadixString(16).toUpperCase().padLeft(4, "0")} '
          'PID=0x${(device.pid ?? 0).toRadixString(16).toUpperCase().padLeft(4, "0")} '
          '(${device.manufacturerName ?? "unknown"})';

      // 2. Create a port object from the device descriptor.
      // Note: device.create() automatically prompts the Android USB permission dialog if needed.
      final port = await device.create();
      if (port == null) {
        _emit('[ERROR] USB permission denied or could not create port.');
        LogService.error('SerialService', 'USB permission denied or could not create port', rawLog: devId);
        return false;
      }

      // 4. Open the port.
      final opened = await port.open();
      if (!opened) {
        _emit('[ERROR] Port.open() returned false. Try unplugging and replugging.');
        LogService.error('SerialService', 'Port.open() returned false', rawLog: devId);
        return false;
      }

      // 5. Apply 115200 8N1 — matches the ECS unit.
      await port.setPortParameters(
        AppConstants.baudRate,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      // 6. Start listening to the incoming byte stream.
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
      LogService.info('SerialService', 'Port opened successfully (115200 baud, 8N1)', rawLog: devId);
      return true;
    } catch (e, stack) {
      _emit('[ERROR] connect() exception: $e');
      _emit('[ERROR] $stack');
      LogService.error('SerialService', 'connect() exception: $e', rawLog: stack.toString());
      return false;
    }
  }

  // ── Disconnect ──────────────────────────────────────────

  /// Closes the serial port cleanly.
  Future<void> disconnect() async {
    try {
      await _portSubscription?.cancel();
      _portSubscription = null;
      await _port?.close();
    } catch (_) {
      // Ignore close errors — we are disconnecting anyway.
    }
    _port = null;
    _lineBuffer.clear();
    _emit('[INFO] Port closed.');
  }

  // ── Send ────────────────────────────────────────────────

  /// Sends [command] to the unit.
  ///
  /// 1. Waits until no bytes have arrived for [AppConstants.quietWindowMs] ms
  ///    (the "quiet window") — gives up after [AppConstants.quietTimeoutMs].
  /// 2. Appends a CR (\r) and writes the bytes.
  ///
  /// This prevents our command from colliding with the unit's own background
  /// AT traffic (AT+QLTS=2, AT+CSQ, etc.).
  Future<void> sendCommand(String command) async {
    if (_port == null) {
      _emit('[ERROR] Not connected — cannot send "$command".');
      return;
    }

    // ── Wait for quiet window ──────────────────────────────
    final deadline = DateTime.now()
        .add(const Duration(milliseconds: AppConstants.quietTimeoutMs));

    while (DateTime.now().isBefore(deadline)) {
      final silenceMs =
          DateTime.now().difference(_lastByteTime).inMilliseconds;
      if (silenceMs >= AppConstants.quietWindowMs) {
        break; // Line is quiet — safe to transmit.
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }
    // If we fell out of the loop because the deadline passed,
    // we send anyway — partial collision is better than never sending.

    // ── Transmit ──────────────────────────────────────────
    // AT commands use CR only (no LF). No leading spaces.
    final frame = '$command\r';
    _emit('[TX] $command');
    try {
      await _port!.write(Uint8List.fromList(frame.codeUnits));
    } catch (e) {
      _emit('[ERROR] Write failed: $e');
      LogService.error('SerialService', 'Write failed for $command', rawLog: e.toString());
    }
  }

  /// Sends raw binary [data] directly to the serial port without delays or formatting.
  /// Used by binary transfer protocols such as Xmodem-1k.
  Future<bool> sendRawBytes(Uint8List data) async {
    if (_port == null) {
      _emit('[ERROR] Port not open - cannot send raw bytes.');
      LogService.warn('SerialService', 'Attempted sendRawBytes on closed port');
      return false;
    }
    try {
      await _port!.write(data);
      return true;
    } catch (e) {
      _emit('[ERROR] sendRawBytes failed: $e');
      LogService.error('SerialService', 'sendRawBytes failed: $e');
      return false;
    }
  }

  // ── Dispose ─────────────────────────────────────────────

  /// Call when the screen/app is closing to free all resources.
  void dispose() {
    disconnect();
    _lineController.close();
    _rawByteController.close();
  }

  // ── Private helpers ─────────────────────────────────────

  /// Processes a chunk of raw bytes from the port.
  void _onData(Uint8List data) {
    _lastByteTime = DateTime.now();

    // Broadcast raw chunk for binary protocol listeners
    if (!_rawByteController.isClosed) {
      _rawByteController.add(data);
    }

    // Convert bytes to ASCII string.
    final text = String.fromCharCodes(data);

    // Append to the rolling buffer then split on any line ending.
    _lineBuffer.write(text);
    final raw = _lineBuffer.toString();

    // Split on \r\n, \r, or \n — the modem uses \r\n but let's be tolerant.
    final parts = raw.split(RegExp(r'\r\n|\r|\n'));

    // Every part except the last one is a complete line.
    for (int i = 0; i < parts.length - 1; i++) {
      final line = parts[i].trim();
      if (line.isNotEmpty) {
        _emit('[RX] $line');
      }
    }

    // The last element has no terminator yet — keep it for the next chunk.
    _lineBuffer.clear();
    _lineBuffer.write(parts.last);
  }

  void _onError(dynamic error) {
    _emit('[ERROR] Serial port error: $error');
    LogService.error('SerialService', 'Serial port error: $error');
    _port = null;
  }

  void _onDone() {
    // Port stream closed — cable was unplugged.
    _emit('[INFO] Cable disconnected.');
    LogService.warn('SerialService', 'Serial cable disconnected unexpectedly');
    _port = null;
  }

  /// Adds a line to the broadcast stream. Safe to call from anywhere.
  void _emit(String line) {
    if (!_lineController.isClosed) {
      _lineController.add(line);
    }
  }
}
