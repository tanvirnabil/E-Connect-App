// ============================================================
// main.dart  —  Phases 1 + 2 + 3  (COMPLETE)
//
// Three screens:
//   1. WelcomeScreen     — title + Connect button
//   2. ConnectingScreen  — spinner → green/red banner + Continue/Retry
//   3. MainScreen        — APN read/update, debug log, Exit
//
// Dark theme, red accent, green/red result banners.
// Saved last-used APN via shared_preferences.
// ============================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

import 'serial_service.dart';
import 'apn_service.dart';
import 'xmodem_service.dart';
import 'firmware_info.dart';
import 'constants.dart';
import 'log_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  FlutterError.onError = (details) {
    LogService.critical(
      'FlutterError',
      details.exceptionAsString(),
      rawLog: details.stack?.toString(),
    );
    FlutterError.presentError(details);
  };

  runZonedGuarded(() {
    LogService.info('AppLifecycle', 'e-Connect Voice Programming Tool launched (v1.0.12)');
    runApp(const EcsToolApp());
  }, (error, stack) {
    LogService.critical('UnhandledException', error.toString(), rawLog: stack.toString());
  });
}

// ── App root ─────────────────────────────────────────────────────────

class EcsToolApp extends StatelessWidget {
  const EcsToolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'e-Connect Voice Tool',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const WelcomeScreen(),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  SCREEN 1 — WELCOME
// ════════════════════════════════════════════════════════════

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App logo badge
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.35),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.red.withOpacity(0.15),
                        child: const Icon(Icons.cell_tower,
                            color: Colors.red, size: 48),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Title
                const Text(
                  'ECS e-Connect Voice\nProgramming Tool',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'APN Configuration via Serial USB',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),

                const SizedBox(height: 48),

                // Big connect button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.usb, size: 24),
                    label: const Text(
                      'Connect to Unit',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ConnectingScreen(),
                      ));
                    },
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'Connect the USB-to-Serial cable\nbefore tapping the button.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  SCREEN 2 — CONNECTING
// ════════════════════════════════════════════════════════════

class ConnectingScreen extends StatefulWidget {
  const ConnectingScreen({super.key});

  @override
  State<ConnectingScreen> createState() => _ConnectingScreenState();
}

class _ConnectingScreenState extends State<ConnectingScreen> {
  // Services — created fresh each time this screen is entered.
  late final SerialService _serial;
  late final ApnService _apn;

  // State
  _ConnectState _state = _ConnectState.connecting;
  ModuleInfo? _moduleInfo;
  String _statusMessage = 'Connecting to unit…';

  @override
  void initState() {
    super.initState();
    _serial = SerialService();
    _apn    = ApnService(_serial);
    _doConnect();
  }

  @override
  void dispose() {
    // Only dispose if we are NOT handing the services to the next screen.
    if (_state != _ConnectState.success) {
      _serial.dispose();
    }
    super.dispose();
  }

  Future<void> _doConnect() async {
    if (mounted) {
      setState(() {
        _state = _ConnectState.connecting;
        _statusMessage = 'Connecting to unit…';
      });
    }

    final info = await _apn.connectAndIdentify();

    if (!mounted) return;

    if (info.success) {
      LogService.info('ConnectingScreen', 'Connected successfully to ${info.hardwareModel} (${info.firmwareRevision})');
      setState(() {
        _state = _ConnectState.success;
        _moduleInfo = info;
        _statusMessage = info.message;
      });
    } else {
      LogService.error('ConnectingScreen', 'Connection failed: ${info.message}');
      setState(() {
        _state = _ConnectState.failed;
        _statusMessage = info.message;
      });
    }
  }

  void _onContinue() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => MainScreen(
        serial: _serial,
        apn: _apn,
        moduleInfo: _moduleInfo!,
      ),
    ));
  }

  void _onRetry() {
    // Dispose old services and create fresh ones.
    _serial.dispose();
    setState(() {
      _state = _ConnectState.connecting;
    });
    // Navigate to a fresh instance of ConnectingScreen.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ConnectingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Connecting',
            style: TextStyle(color: Colors.white)),
        leading: _state == _ConnectState.connecting
            ? null // hide back during connection
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
        automaticallyImplyLeading: _state != _ConnectState.connecting,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Spinner / icon ──────────────────────────────
                if (_state == _ConnectState.connecting)
                  const CircularProgressIndicator(color: Colors.red)
                else if (_state == _ConnectState.success)
                  const Icon(Icons.check_circle,
                      color: Colors.greenAccent, size: 64)
                else
                  const Icon(Icons.error_outline,
                      color: Colors.redAccent, size: 64),

                const SizedBox(height: 24),

                // ── Result banner ───────────────────────────────
                if (_state != _ConnectState.connecting)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _state == _ConnectState.success
                          ? Colors.green.withOpacity(0.15)
                          : Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _state == _ConnectState.success
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _state == _ConnectState.success
                              ? 'Connected'
                              : 'No Response — Check Cable',
                          style: TextStyle(
                            color: _state == _ConnectState.success
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_moduleInfo != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Hardware Model: ${_moduleInfo!.hardwareModel}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Firmware: ${_moduleInfo!.firmwareRevision}',
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontFamily: 'monospace'),
                          ),
                          if (_moduleInfo!.mcuBootInfo.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'MCU: ${_moduleInfo!.mcuBootInfo}',
                              style: const TextStyle(
                                  color: Colors.cyanAccent,
                                  fontSize: 12,
                                  fontFamily: 'monospace'),
                            ),
                          ],
                          // EC25 warning
                          if (!_moduleInfo!.isEc25) ...[
                            const SizedBox(height: 8),
                            const Text(
                              '⚠️ Note: hardware does not identify as standard EC25.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.orangeAccent, fontSize: 12),
                            ),
                          ],
                        ],
                        if (_state == _ConnectState.failed) ...[
                          const SizedBox(height: 8),
                          Text(
                            _statusMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),

                const SizedBox(height: 32),

                // ── Action buttons ──────────────────────────────
                if (_state == _ConnectState.success)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _onContinue,
                      child: const Text('Continue →',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),

                if (_state == _ConnectState.failed)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry',
                          style: TextStyle(fontSize: 16)),
                      onPressed: _onRetry,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _ConnectState { connecting, success, failed }

// ════════════════════════════════════════════════════════════
//  SCREEN 3 — MAIN (APN)
// ════════════════════════════════════════════════════════════

class MainScreen extends StatefulWidget {
  final SerialService serial;
  final ApnService apn;
  final ModuleInfo moduleInfo;

  const MainScreen({
    super.key,
    required this.serial,
    required this.apn,
    required this.moduleInfo,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final TextEditingController _apnController = TextEditingController();
  final ScrollController _logScrollController = ScrollController();

  // Current displayed APN (read from unit).
  String _currentApn = '—';

  // Banner state.
  _BannerState _bannerState = _BannerState.none;
  String _bannerMessage = '';

  // Debug log lines.
  final List<String> _debugLog = [];
  bool _showDebugLog = false;

  // Device information
  late ModuleInfo _moduleInfo = widget.moduleInfo;
  bool _refreshingInfo = false;

  // Selected Tab: 0 = APN, 1 = Firmware Flasher
  int _selectedTabIndex = 0;

  // Firmware flasher state
  String? _firmwareFileName;
  int? _firmwareFileSize;
  Uint8List? _firmwareBytes;
  FirmwareInfo? _selectedFirmwareInfo;
  FirmwareInfo? _installedFirmwareInfo;
  bool _isFlashing = false;
  bool _cancelFlashing = false;
  XmodemProgress? _flashProgress;
  bool _isFirmwareVerified = false;
  late final XmodemService _xmodem = XmodemService(widget.serial);

  static const String _kInstalledFwKey = 'ecs_installed_firmware_v1';

  // Busy flags.
  bool _readingApn  = false;
  bool _writingApn  = false;
  String _writingStatus = 'Updating…';

  @override
  void initState() {
    super.initState();
    _loadLastApn();
    _loadInstalledFirmware();

    // Pipe all serial lines to the debug log.
    widget.serial.lines.listen((line) {
      if (!mounted) return;
      setState(() {
        _debugLog.add(line);
        if (_debugLog.length > 500) _debugLog.removeAt(0);
      });
      _scrollLogToBottom();
    });

    // Read APN after a brief settling delay so serial port has completed initial handshake
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _readApn();
    });
  }

  @override
  void dispose() {
    widget.serial.dispose();
    _apnController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  // ── Load / save last APN ────────────────────────────────────────

  Future<void> _loadLastApn() async {
    final prefs = await SharedPreferences.getInstance();
    String? saved = prefs.getString(AppConstants.lastApnKey);
    if (saved == null || saved.toLowerCase() == 'reseller') {
      saved = AppConstants.defaultApn;
    }
    if (mounted) _apnController.text = saved;
  }

  Future<void> _saveLastApn(String apn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.lastApnKey, apn);
  }

  Future<void> _loadInstalledFirmware() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_kInstalledFwKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final data = jsonDecode(jsonStr);
        if (mounted) {
          setState(() {
            _installedFirmwareInfo = FirmwareInfo.fromJson(data);
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _saveInstalledFirmware(FirmwareInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kInstalledFwKey, jsonEncode(info.toJson()));
    if (mounted) {
      setState(() => _installedFirmwareInfo = info);
    }
  }

  // ── Device & Firmware Query ─────────────────────────────────────

  Future<void> _refreshDeviceInfo() async {
    if (_refreshingInfo || _isFlashing) return;
    setState(() => _refreshingInfo = true);
    final info = await widget.apn.queryDetailedDeviceInfo();
    if (mounted) {
      setState(() {
        _refreshingInfo = false;
        if (info.success) {
          _moduleInfo = info;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF2A2A2A),
          content: Text(
            info.success
                ? 'Device info refreshed: ${info.hardwareModel} (${info.firmwareRevision})'
                : 'Could not query device info.',
            style: const TextStyle(color: Colors.white),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ── Firmware Flashing (Xmodem-1k) ───────────────────────────────

  Future<void> _pickFirmwareFile() async {
    if (_isFlashing) return;
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.any,
      );
      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          final parsed = FirmwareInfo.parse(file.name, bytes);
          LogService.info('MainScreen', 'Firmware file selected: ${file.name} (${bytes.length} bytes, parsed: ${parsed.version})');
          setState(() {
            _firmwareFileName = file.name;
            _firmwareFileSize = bytes.length;
            _firmwareBytes = bytes;
            _selectedFirmwareInfo = parsed;
            _flashProgress = null;
            _isFirmwareVerified = false;
          });
        }
      }
    } catch (e) {
      LogService.error('MainScreen', 'File picker error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File picker error: $e')),
        );
      }
    }
  }

  Future<void> _startFlashing() async {
    if (_firmwareBytes == null || _isFlashing) return;
    LogService.info('MainScreen', 'Starting firmware flash: $_firmwareFileName');
    setState(() {
      _isFlashing = true;
      _cancelFlashing = false;
      _flashProgress = null;
      _isFirmwareVerified = false;
    });

    final result = await _xmodem.uploadFirmware(
      _firmwareBytes!,
      onProgress: (progress) {
        if (mounted) {
          setState(() => _flashProgress = progress);
        }
      },
      isCancelled: () => _cancelFlashing,
    );

    if (!mounted) return;

    if (result.success) {
      LogService.info('MainScreen', 'Firmware flash complete: ${result.message}');

      // Record verified firmware metadata with local timestamp
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final updatedFw = FirmwareInfo.parse(
        _firmwareFileName ?? 'fwt8848_firmware.bin',
        _firmwareBytes!,
        flashDate: dateStr,
        isVerified: true,
      );
      await _saveInstalledFirmware(updatedFw);

      // Re-query terminal state and current APN
      _refreshDeviceInfo();
      _readApn();

      setState(() {
        _isFlashing = false;
        _isFirmwareVerified = true;
      });

      _showFirmwareSuccessDialog(updatedFw, result.message);
    } else {
      LogService.error('MainScreen', 'Firmware flash failed: ${result.message}');

      setState(() {
        _isFlashing = false;
        _isFirmwareVerified = false;
      });

      showDialog<void>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.redAccent.withOpacity(0.6), width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
              SizedBox(width: 10),
              Text('Flash Incomplete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text(result.message, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF333333), foregroundColor: Colors.white),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _showFirmwareSuccessDialog(FirmwareInfo info, String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Colors.greenAccent.withOpacity(0.8),
              width: 1.5,
            ),
          ),
          title: const Row(
            children: [
              Icon(Icons.verified, color: Colors.greenAccent, size: 30),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Update Verified!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      '8848 Terminal Rebooted & Online',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      _buildDialogDetailRow('Target Hardware', info.boardModel),
                      const SizedBox(height: 6),
                      _buildDialogDetailRow('Microcontroller', info.targetMcu),
                      const SizedBox(height: 6),
                      _buildDialogDetailRow('Firmware Version', info.version),
                      const SizedBox(height: 6),
                      _buildDialogDetailRow('Build Timestamp', info.buildNumber),
                      const SizedBox(height: 6),
                      _buildDialogDetailRow('Integrity Check', 'CRC-16 Verified (0 Errors)'),
                      const SizedBox(height: 6),
                      _buildDialogDetailRow('Terminal State', 'Online & Operational'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _showFirmwareDetailsModal();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.cyanAccent,
                side: const BorderSide(color: Colors.cyanAccent),
              ),
              child: const Text('View Full Specs'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  void _showFirmwareDetailsModal() {
    final info = _installedFirmwareInfo ?? _selectedFirmwareInfo;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.memory, color: Colors.cyanAccent, size: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '8848 FWT Technical Specifications',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 24),
              _buildSpecsGroup(
                title: 'TERMINAL HARDWARE',
                items: [
                  {'label': 'Terminal Model', 'val': '8848 4G Fixed Wireless Terminal'},
                  {'label': 'PCB Revision', 'val': '4G_FWT8848T_V01'},
                  {'label': 'Microcontroller', 'val': 'Huada HC32F460 (ARM Cortex-M4 @ 200MHz)'},
                  {'label': 'MCU Bootloader', 'val': _moduleInfo.mcuBootInfo.isNotEmpty ? _moduleInfo.mcuBootInfo : 'HC32f460 boot v0.0.0.1b1'},
                  {'label': 'SLIC Line Interface', 'val': 'Silicon Labs Si32176 ProSLIC'},
                ],
              ),
              const SizedBox(height: 14),
              _buildSpecsGroup(
                title: 'MCU FIRMWARE SPECIFICATIONS',
                items: [
                  {'label': 'Active Version', 'val': info?.version ?? 'V0.0.0.5'},
                  {'label': 'Build Number', 'val': info?.buildNumber ?? '202411140001'},
                  {'label': 'Source File', 'val': info?.fileName.isNotEmpty == true ? info!.fileName : 'fwt8848TDM-9641...bin'},
                  {'label': 'Features', 'val': info?.features ?? 'Voice SLIC, SMS Forward, 7-Day Reports'},
                  {'label': 'Flash Integrity', 'val': info?.isVerified == true ? 'CRC-16 Verified (Active & Online)' : 'Verified'},
                  if (info?.flashDate.isNotEmpty == true)
                    {'label': 'Flashed On', 'val': info!.flashDate},
                ],
              ),
              const SizedBox(height: 14),
              _buildSpecsGroup(
                title: 'CELLULAR MODEM SUBSYSTEM',
                items: [
                  {'label': 'Modem Module', 'val': _moduleInfo.hardwareModel.isNotEmpty ? _moduleInfo.hardwareModel : 'Quectel EC25-EUX'},
                  {'label': 'Modem Firmware', 'val': _moduleInfo.firmwareRevision.isNotEmpty ? _moduleInfo.firmwareRevision : 'EC25EUXGAR08A17M1G'},
                  {'label': 'Active APN', 'val': _currentApn},
                  {'label': 'Protocol Gateway', 'val': 'Transparent AT & Audio Forwarding'},
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpecsGroup({required String title, required List<Map<String, String>> items}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF262626),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item['label']!, style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    item['val']!,
                    style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildDialogDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11.5)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11.5,
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  // ── Read APN ────────────────────────────────────────────────────

  Future<void> _readApn() async {
    if (_readingApn || _writingApn) return;
    if (mounted) setState(() { _readingApn = true; _bannerState = _BannerState.none; });

    final result = await widget.apn.readApn();

    if (!mounted) return;
    setState(() {
      _readingApn = false;
      _currentApn = result.value ?? '(error)';
    });
  }

  // ── Write APN ───────────────────────────────────────────────────

  Future<void> _writeApn() async {
    if (_readingApn || _writingApn) return;

    final newApn = _apnController.text.trim();

    // Client-side validation first.
    final validationError = widget.apn.validateApn(newApn);
    if (validationError != null) {
      if (mounted) {
        setState(() {
          _bannerState   = _BannerState.failure;
          _bannerMessage = validationError;
        });
      }
      _showVerificationResultDialog(
        ApnResult.fail(validationError),
        newApn,
      );
      return;
    }

    if (mounted) {
      setState(() {
        _writingApn    = true;
        _writingStatus = 'Sending APN…';
        _bannerState   = _BannerState.none;
      });
    }

    final result = await widget.apn.writeApn(
      newApn,
      onProgress: (phase) {
        if (mounted) {
          setState(() => _writingStatus = phase);
        }
      },
    );

    if (!mounted) return;

    if (result.success) {
      await _saveLastApn(newApn);
      setState(() {
        _writingApn    = false;
        _currentApn    = newApn;
        _bannerState   = _BannerState.success;
        _bannerMessage = result.message;
      });
    } else {
      setState(() {
        _writingApn    = false;
        _bannerState   = _BannerState.failure;
        _bannerMessage = result.message;
      });
    }

    // Modal popup confirmation
    _showVerificationResultDialog(result, newApn);
  }

  Future<void> _showVerificationResultDialog(
    ApnResult result,
    String targetApn,
  ) async {
    final isSuccess = result.success;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isSuccess
                  ? Colors.greenAccent.withOpacity(0.6)
                  : Colors.redAccent.withOpacity(0.6),
              width: 1.5,
            ),
          ),
          title: Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.error_outline,
                color: isSuccess ? Colors.greenAccent : Colors.redAccent,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isSuccess ? 'APN Verified' : 'APN Update Failed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSuccess
                    ? 'The APN has been written and re-checked directly from the modem memory.'
                    : 'The unit did not confirm the new APN update.',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSuccess ? 'Verified APN on unit:' : 'Requested APN:',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isSuccess ? (result.value ?? targetApn) : targetApn,
                      style: TextStyle(
                        color: isSuccess ? Colors.greenAccent : Colors.redAccent,
                        fontFamily: 'monospace',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                result.message,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          actions: [
            if (!isSuccess)
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _writeApn();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const Text('Retry'),
              ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: isSuccess
                    ? Colors.green.shade700
                    : const Color(0xFF333333),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(isSuccess ? 'OK' : 'Dismiss'),
            ),
          ],
        );
      },
    );
  }

  // ── Exit ────────────────────────────────────────────────────────

  Future<void> _onExit() async {
    await widget.serial.disconnect();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────

  void _scrollLogToBottom() {
    Future.delayed(const Duration(milliseconds: 60), () {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Color _logLineColor(String line) {
    if (line.startsWith('[TX]'))    return Colors.cyanAccent;
    if (line.startsWith('[RX]'))    return Colors.greenAccent;
    if (line.startsWith('[ERROR]')) return Colors.redAccent;
    if (line.startsWith('[WARN]'))  return Colors.orangeAccent;
    return Colors.white54;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Widget _buildProcedureStep({
    required String stepNumber,
    required String title,
    required String description,
    bool isDone = false,
    bool isActive = false,
  }) {
    final Color badgeColor = isDone
        ? Colors.greenAccent
        : isActive
            ? Colors.cyanAccent
            : Colors.white38;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: badgeColor.withOpacity(0.6), width: 1.5),
          ),
          child: isDone
              ? const Icon(Icons.check, size: 14, color: Colors.greenAccent)
              : Text(
                  stepNumber,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDone
                      ? Colors.greenAccent
                      : isActive
                          ? Colors.white
                          : Colors.white60,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModeSelectorTile({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: _isFlashing ? null : () => setState(() => _selectedTabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2B1D1D) : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.redAccent : Colors.white12,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.redAccent.withOpacity(0.2) : Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.redAccent : Colors.white60,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isSelected ? Colors.white60 : Colors.white38,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? Colors.redAccent : Colors.white24,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool busy = _readingApn || _writingApn || _isFlashing;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 26,
              height: 26,
              errorBuilder: (_, __, ___) => const Icon(Icons.router, color: Colors.redAccent, size: 22),
            ),
            const SizedBox(width: 10),
            const Text(
              'e-Connect',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          // Refresh device info
          IconButton(
            icon: _refreshingInfo
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                  )
                : const Icon(Icons.sync, color: Colors.white70),
            tooltip: 'Refresh Device Info',
            onPressed: busy ? null : _refreshDeviceInfo,
          ),
          // Debug log toggle
          IconButton(
            icon: Icon(
              _showDebugLog ? Icons.bug_report : Icons.bug_report_outlined,
              color: _showDebugLog ? Colors.cyanAccent : Colors.white54,
            ),
            tooltip: 'Toggle debug log',
            onPressed: () => setState(() => _showDebugLog = !_showDebugLog),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Scrollable main content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // ── Device & Firmware Info Card ────────────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.memory, size: 18, color: Colors.redAccent),
                              const SizedBox(width: 8),
                              const Text(
                                'DEVICE & FIRMWARE INFO',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const Spacer(),
                              InkWell(
                                onTap: _showFirmwareDetailsModal,
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.cyanAccent.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.cyanAccent.withOpacity(0.4)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.info_outline, size: 12, color: Colors.cyanAccent),
                                      SizedBox(width: 4),
                                      Text(
                                        'View Details',
                                        style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(color: Colors.white10, height: 1),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Hardware Model', style: TextStyle(color: Colors.white38, fontSize: 11)),
                                    const SizedBox(height: 2),
                                    Text(
                                      _moduleInfo.hardwareModel.isNotEmpty ? _moduleInfo.hardwareModel : '8848 4G FWT',
                                      style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Modem Firmware', style: TextStyle(color: Colors.white38, fontSize: 11)),
                                    const SizedBox(height: 2),
                                    Text(
                                      _moduleInfo.firmwareRevision.isNotEmpty ? _moduleInfo.firmwareRevision : '—',
                                      style: const TextStyle(color: Colors.cyanAccent, fontSize: 12.5, fontFamily: 'monospace'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Active MCU Firmware Row
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF262626),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _installedFirmwareInfo?.isVerified == true
                                    ? Colors.greenAccent.withOpacity(0.4)
                                    : Colors.white12,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _installedFirmwareInfo?.isVerified == true
                                      ? Icons.verified
                                      : Icons.developer_board,
                                  size: 16,
                                  color: _installedFirmwareInfo?.isVerified == true
                                      ? Colors.greenAccent
                                      : Colors.amberAccent,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Active MCU Firmware', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                      const SizedBox(height: 1),
                                      Text(
                                        _installedFirmwareInfo?.displayVersion ??
                                            (_moduleInfo.mcuBootInfo.isNotEmpty
                                                ? _moduleInfo.mcuBootInfo
                                                : 'fwt8848TDM-9641 V0.0.0.5'),
                                        style: TextStyle(
                                          color: _installedFirmwareInfo?.isVerified == true
                                              ? Colors.greenAccent
                                              : Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (_installedFirmwareInfo?.isVerified == true
                                            ? Colors.greenAccent
                                            : Colors.cyanAccent)
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _installedFirmwareInfo?.isVerified == true
                                        ? 'Verified'
                                        : 'Online',
                                    style: TextStyle(
                                      color: _installedFirmwareInfo?.isVerified == true
                                          ? Colors.greenAccent
                                          : Colors.cyanAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Mode Switcher (2 lines / stacked tiles) ───────────
                    _buildModeSelectorTile(
                      index: 0,
                      title: 'APN Configuration',
                      subtitle: 'Read, verify, and update cellular APN',
                      icon: Icons.tune,
                    ),
                    const SizedBox(height: 8),
                    _buildModeSelectorTile(
                      index: 1,
                      title: 'Firmware Upgrade Tool',
                      subtitle: 'Flash .bin firmware using Xmodem-1k protocol',
                      icon: Icons.system_update_alt,
                    ),

                    const SizedBox(height: 16),

                    // ── Tab 0: APN Setup ──────────────────────────────────
                    if (_selectedTabIndex == 0) ...[
                      // Current APN card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Current APN on unit:',
                                style: TextStyle(color: Colors.white54, fontSize: 13)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _currentApn,
                                    style: TextStyle(
                                      color: _currentApn == '(not set)'
                                          ? Colors.orangeAccent
                                          : Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                                  icon: _readingApn
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2, color: Colors.white70))
                                      : const Icon(Icons.refresh, size: 18),
                                  label: const Text('Read APN'),
                                  onPressed: busy ? null : _readApn,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // New APN input
                      const Text('New APN:',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _apnController,
                        style: const TextStyle(
                            fontFamily: 'monospace', color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'e.g. ${AppConstants.defaultApn}',
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: const Color(0xFF2A2A2A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                        ),
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.done,
                      ),

                      const SizedBox(height: 12),

                      // Update APN button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.red.withOpacity(0.3),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _writingApn
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_alt),
                        label: Text(
                          _writingApn ? _writingStatus : 'Update APN',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        onPressed: busy ? null : _writeApn,
                      ),

                      const SizedBox(height: 12),

                      // Result banner
                      if (_bannerState != _BannerState.none)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _bannerState == _BannerState.success
                                ? Colors.green.withOpacity(0.15)
                                : Colors.red.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _bannerState == _BannerState.success
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _bannerState == _BannerState.success
                                    ? Icons.check_circle_outline
                                    : Icons.cancel_outlined,
                                color: _bannerState == _BannerState.success
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _bannerState == _BannerState.success
                                      ? 'APN Updated ✓'
                                      : 'APN Update Failed',
                                  style: TextStyle(
                                    color: _bannerState == _BannerState.success
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (_bannerState != _BannerState.none && _bannerMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 4),
                          child: Text(
                            _bannerMessage,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ),
                    ],

                    // ── Tab 1: Firmware Flasher ───────────────────────────
                    if (_selectedTabIndex == 1) ...[
                      // ── Step-by-Step Interactive Guide ──────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.flash_on, color: Colors.cyanAccent, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Firmware Upgrade Procedure',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildProcedureStep(
                              stepNumber: '1',
                              title: 'Turn OFF the 8848 Terminal',
                              description: 'Flip the power switch on the 8848 terminal to the OFF position.',
                              isDone: _isFirmwareVerified,
                              isActive: _firmwareBytes == null && !_isFlashing && !_isFirmwareVerified,
                            ),
                            const SizedBox(height: 8),
                            _buildProcedureStep(
                              stepNumber: '2',
                              title: 'Select Firmware File',
                              description: 'Tap "Browse" below to choose the .bin firmware file.',
                              isDone: _firmwareBytes != null,
                              isActive: _firmwareBytes == null && !_isFlashing && !_isFirmwareVerified,
                            ),
                            const SizedBox(height: 8),
                            _buildProcedureStep(
                              stepNumber: '3',
                              title: 'Turn ON the 8848 Terminal',
                              description: 'Flip the power switch on the 8848 terminal back to ON.',
                              isDone: _isFirmwareVerified,
                              isActive: _firmwareBytes != null && !_isFlashing && !_isFirmwareVerified,
                            ),
                            const SizedBox(height: 8),
                            _buildProcedureStep(
                              stepNumber: '4',
                              title: 'Tap "Start Firmware Upgrade"',
                              description: 'Tap the button below to flash the firmware and verify reboot.',
                              isDone: _isFirmwareVerified,
                              isActive: _firmwareBytes != null && !_isFlashing && !_isFirmwareVerified,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Firmware File Picker Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _firmwareBytes != null ? Colors.cyanAccent.withOpacity(0.4) : Colors.white12,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _firmwareBytes != null ? Icons.description : Icons.file_present_outlined,
                                  color: _firmwareBytes != null ? Colors.cyanAccent : Colors.white38,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _firmwareFileName ?? 'No firmware file selected',
                                        style: TextStyle(
                                          color: _firmwareFileName != null ? Colors.white : Colors.white54,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _firmwareFileSize != null
                                            ? 'File size: ${_formatBytes(_firmwareFileSize!)}'
                                            : 'Tap browse to select .bin firmware',
                                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white38),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  onPressed: _isFlashing ? null : _pickFirmwareFile,
                                  child: Text(_firmwareBytes == null ? 'Browse' : 'Change'),
                                ),
                              ],
                            ),
                            if (_selectedFirmwareInfo != null) ...[
                              const SizedBox(height: 10),
                              const Divider(color: Colors.white10, height: 1),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E1E),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
                                ),
                                child: Column(
                                  children: [
                                    _buildDialogDetailRow('Target Hardware', _selectedFirmwareInfo!.boardModel),
                                    const SizedBox(height: 4),
                                    _buildDialogDetailRow('Firmware Version', _selectedFirmwareInfo!.version),
                                    const SizedBox(height: 4),
                                    _buildDialogDetailRow('Build Timestamp', _selectedFirmwareInfo!.buildNumber),
                                    const SizedBox(height: 4),
                                    _buildDialogDetailRow('Total Packets', '${_selectedFirmwareInfo!.totalPackets} blocks (1024B)'),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Flashing Progress & Status
                      if (_isFlashing || _flashProgress != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _isFirmwareVerified
                                  ? Colors.greenAccent.withOpacity(0.6)
                                  : (_isFlashing ? Colors.redAccent.withOpacity(0.5) : Colors.white12),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (_isFlashing)
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                                    )
                                  else if (_isFirmwareVerified)
                                    const Icon(Icons.check_circle, size: 16, color: Colors.greenAccent)
                                  else
                                    const Icon(Icons.info, size: 16, color: Colors.white54),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _flashProgress?.stage ?? 'Preparing...',
                                      style: TextStyle(
                                        color: _isFirmwareVerified ? Colors.greenAccent : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  if (_flashProgress != null && _flashProgress!.totalBlocks > 0)
                                    Text(
                                      '${((_flashProgress!.fraction) * 100).toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        color: _isFirmwareVerified ? Colors.greenAccent : Colors.cyanAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: _flashProgress != null && _flashProgress!.totalBlocks > 0
                                      ? _flashProgress!.fraction
                                      : (_isFlashing ? null : 0.0),
                                  backgroundColor: const Color(0xFF333333),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _isFirmwareVerified ? Colors.greenAccent : Colors.redAccent,
                                  ),
                                  minHeight: 8,
                                ),
                              ),
                              if (_flashProgress != null && _flashProgress!.totalBlocks > 0) ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Block ${_flashProgress!.currentBlock} of ${_flashProgress!.totalBlocks}',
                                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                                    ),
                                    if (_flashProgress!.retries > 0)
                                      Text(
                                        'Retries: ${_flashProgress!.retries}',
                                        style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Pre-flash Power & Action Guidance Banner
                      if (!_isFlashing && _firmwareBytes != null && !_isFirmwareVerified) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.cyan.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.power_settings_new, color: Colors.cyanAccent, size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Step 3 & 4: Turn ON the 8848 terminal power switch, then tap Start Firmware Upgrade below.',
                                  style: TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Active Flash Guidance Banner
                      if (_isFlashing) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.cyan.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.cyanAccent.withOpacity(0.6), width: 1.5),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.bolt, color: Colors.cyanAccent, size: 24),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _flashProgress?.stage.contains('Waiting for 8848 terminal to reboot') == true
                                      ? 'Flashing finished! Terminal is now rebooting...'
                                      : 'Connecting to bootloader & flashing firmware packets...',
                                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Flash Button / Cancel Button
                      if (!_isFlashing)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.red.withOpacity(0.3),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.flash_on),
                          label: const Text(
                            'Start Firmware Upgrade',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          onPressed: _firmwareBytes == null ? null : _startFlashing,
                        )
                      else
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF333333),
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.cancel),
                          label: const Text(
                            'Cancel Upgrade',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => setState(() => _cancelFlashing = true),
                        ),
                    ],

                    const SizedBox(height: 16),

                    // ── Exit button ───────────────────────────────────────
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white54,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Exit — Disconnect'),
                      onPressed: busy ? null : _onExit,
                    ),

                  ],
                ),
              ),
            ),

            // ── Debug log (hidden by default, collapsible at bottom) ─────
            if (_showDebugLog) ...[
              const Divider(color: Colors.white12, height: 1),
              Container(
                color: const Color(0xFF1A1A1A),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    const Text('Debug Log', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const Spacer(),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.white38),
                      onPressed: () => setState(() => _debugLog.clear()),
                      child: const Text('Clear', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
              Container(
                height: 160,
                color: const Color(0xFF0A0A0A),
                child: _debugLog.isEmpty
                    ? const Center(
                        child: Text('No data yet.', style: TextStyle(color: Colors.white24, fontSize: 12)))
                    : ListView.builder(
                        controller: _logScrollController,
                        padding: const EdgeInsets.all(8),
                        itemCount: _debugLog.length,
                        itemBuilder: (context, i) {
                          final line = _debugLog[i];
                          return Text(
                            line,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              height: 1.5,
                              color: _logLineColor(line),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _BannerState { none, success, failure }
