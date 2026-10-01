// ============================================================
// apn_service.dart  —  Phase 2
//
// All APN logic lives here. The UI and serial layer are kept
// completely separate — this file only knows about AT commands.
//
// Responsibilities:
//   • Send ATI and parse model / revision
//   • Read the current APN (AT+CGDCONT?) with retry
//   • Validate a new APN string
//   • Write a new APN and verify it by reading back
//   • Handle the noisy line (background AT+QLTS, AT+CSQ traffic)
//   • Never throw — all errors returned as ApnResult
// ============================================================

import 'dart:async';

import 'constants.dart';
import 'serial_service.dart';
import 'log_service.dart';

// ── Result types ─────────────────────────────────────────────────────

/// Returned by every public method so the UI never has to catch exceptions.
class ApnResult {
  final bool success;
  final String? value;   // APN string on success, null on failure
  final String message;  // Human-readable status / error

  const ApnResult.ok(this.value, this.message) : success = true;
  const ApnResult.fail(this.message) : success = false, value = null;
}

/// Holds detailed hardware, modem firmware, and MCU boot info.
class ModuleInfo {
  final bool success;
  final String hardwareModel;     // e.g. "EC25-EUX"
  final String firmwareRevision;  // e.g. "EC25EUXGAR08A17M1G"
  final String detailedBuild;     // from AT+QGMR (exact Quectel build)
  final String mcuBootInfo;       // e.g. "HC32f460 boot v0.0.0.1b1"
  final bool isEc25;
  final String message;

  // Backwards compatibility getters
  String get model => hardwareModel;
  String get revision => firmwareRevision;

  const ModuleInfo({
    required this.success,
    required this.hardwareModel,
    required this.firmwareRevision,
    this.detailedBuild = '',
    this.mcuBootInfo = '',
    required this.isEc25,
    required this.message,
  });

  const ModuleInfo.failed(String msg)
      : success = false,
        hardwareModel = '',
        firmwareRevision = '',
        detailedBuild = '',
        mcuBootInfo = '',
        isEc25 = false,
        message = msg;
}

// ── Service ──────────────────────────────────────────────────────────

class ApnService {
  final SerialService _serial;
  String _capturedMcuBootInfo = '';

  ApnService(this._serial) {
    // Monitor incoming lines for MCU bootloader banners
    _serial.lines.listen((line) {
      final upper = line.toUpperCase();
      if (upper.contains('HC32') ||
          upper.contains('BOOT V') ||
          upper.contains('FWT') ||
          upper.contains('UPDATA MODE') ||
          upper.contains('UPDATE MODE')) {
        _capturedMcuBootInfo = line.replaceAll(RegExp(r'^\[(RX|TX)\]\s*'), '').trim();
      }
    });
  }

  // ── Connect & Identify ────────────────────────────────────────────

  /// Opens the port (via SerialService) then queries ATI, AT+CGMR, and AT+QGMR.
  Future<ModuleInfo> connectAndIdentify() async {
    // 1. Open the port.
    final opened = await _serial.connect();
    if (!opened) {
      LogService.error('ApnService', 'Failed to connect: serial port could not be opened');
      return const ModuleInfo.failed(
        'Could not open serial port. Check cable and try again.',
      );
    }

    return queryDetailedDeviceInfo();
  }

  /// Queries ATI to extract exact hardware and firmware versions.
  Future<ModuleInfo> queryDetailedDeviceInfo() async {
    if (!_serial.isConnected) {
      LogService.warn('ApnService', 'queryDetailedDeviceInfo called but serial port is not connected');
      return const ModuleInfo.failed('Serial port is not connected.');
    }

    // 1. Send ATI and collect lines
    final atiLines = await _sendAndCollect(
      'ATI',
      timeoutMs: AppConstants.connectTimeoutMs,
      stopOnOk: true,
    );

    if (atiLines.isEmpty) {
      LogService.error('ApnService', 'No response from unit on ATI query. Check cable and power.');
      return const ModuleInfo.failed(
        'No response from unit. Check cable and power.',
      );
    }

    String vendor = '';
    String subModel = '';
    String revision = '';

    for (final line in atiLines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed == 'OK' || trimmed.startsWith('AT')) {
        continue;
      }
      if (trimmed.toLowerCase().startsWith('revision:')) {
        revision = trimmed.substring('revision:'.length).trim();
      } else if (trimmed.toLowerCase().contains('quectel')) {
        vendor = 'Quectel';
      } else if (trimmed.length > 8 &&
          (trimmed.startsWith('EC') ||
              trimmed.contains('GAR') ||
              trimmed.contains('R0') ||
              trimmed.contains('B0'))) {
        // Full firmware build string like EC25EUXGAR08A17M1G
        revision = trimmed;
      } else if (trimmed.startsWith('EC25') ||
          trimmed.startsWith('EC20') ||
          trimmed.startsWith('EG')) {
        subModel = trimmed;
      } else if (!trimmed.startsWith('+')) {
        if (vendor.isEmpty) {
          vendor = trimmed;
        } else if (revision.isEmpty) {
          revision = trimmed;
        }
      }
    }

    // If subModel was not isolated but revision has module code (e.g. EC25EUX)
    if (subModel.isEmpty && revision.isNotEmpty) {
      if (revision.startsWith('EC25EUX')) {
        subModel = 'EC25-EUX';
      } else if (revision.startsWith('EC25E')) {
        subModel = 'EC25-E';
      } else if (revision.startsWith('EC25AF')) {
        subModel = 'EC25-AF';
      } else if (revision.startsWith('EC25')) {
        subModel = 'EC25';
      } else if (revision.startsWith('EC20')) {
        subModel = 'EC20';
      }
    }

    // Construct clean model string (e.g. Quectel EC25-EUX)
    String model = '';
    if (vendor.isNotEmpty && subModel.isNotEmpty) {
      model = '$vendor $subModel';
    } else if (subModel.isNotEmpty) {
      model = 'Quectel $subModel';
    } else if (vendor.isNotEmpty) {
      model = '$vendor EC25';
    } else {
      model = 'Quectel EC25';
    }

    final isEc25 = revision.contains('EC25') || model.contains('EC25');

    LogService.info('ApnService', 'Unit identified: $model ($revision)');

    return ModuleInfo(
      success: true,
      hardwareModel: model,
      firmwareRevision: revision.isEmpty ? '(unknown)' : revision,
      detailedBuild: revision,
      mcuBootInfo: _capturedMcuBootInfo,
      isEc25: isEc25,
      message: isEc25
          ? 'Connected — EC25 module identified.'
          : 'Connected — Note: hardware module identification does not match standard EC25.',
    );
  }

  // ── Read APN ──────────────────────────────────────────────────────

  /// Sends AT+CGDCONT? and parses the APN from context 1.
  /// Retries up to [AppConstants.readRetries] times.
  /// Returns "(not set)" if the APN field is empty.
  Future<ApnResult> readApn() async {
    for (int attempt = 1; attempt <= AppConstants.readRetries; attempt++) {
      final lines = await _sendAndCollect(
        'AT+CGDCONT?',
        timeoutMs: AppConstants.responseTimeoutMs,
        stopOnOk: true,
      );

      final apn = _parseApnFromLines(lines);

      if (apn != null) {
        final display = apn.isEmpty ? '(not set)' : apn;
        LogService.info('ApnService', 'APN read successfully: $display');
        return ApnResult.ok(display, 'APN read successfully.');
      }

      // Not found — wait a moment and retry.
      if (attempt < AppConstants.readRetries) {
        LogService.warn('ApnService', 'APN read attempt $attempt failed, retrying...');
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    LogService.error('ApnService', 'Could not read APN after ${AppConstants.readRetries} attempts');
    return const ApnResult.fail(
      'Could not read APN after ${AppConstants.readRetries} attempts. '
      'The unit may be busy — try again.',
    );
  }

  // ── Validate APN input ────────────────────────────────────────────

  /// Returns null if [apn] is valid, or an error message string if not.
  /// Rules: 1–100 chars, only letters/digits/dot/hyphen/underscore.
  String? validateApn(String apn) {
    if (apn.isEmpty) return 'APN cannot be empty.';
    if (apn.length > 100) return 'APN is too long (max 100 characters).';
    final valid = RegExp(r'^[A-Za-z0-9.\-_]+$');
    if (!valid.hasMatch(apn)) {
      return 'APN contains invalid characters.\n'
          'Only letters, numbers, dot (.), hyphen (-), underscore (_) allowed.\n'
          'No spaces or quotes.';
    }
    return null; // valid
  }

  // ── Write APN ─────────────────────────────────────────────────────

  /// Writes [newApn] using AT+CGDCONT=1,"<pdpType>","<newApn>",
  /// then reads back and compares (case-sensitive).
  ///
  /// Retries the whole write+readback up to [AppConstants.writeRetries] times.
  /// Returns success only if readback matches exactly.
  Future<ApnResult> writeApn(
    String newApn, {
    void Function(String phase)? onProgress,
  }) async {
    // Validate first — never send invalid input to the modem.
    final validationError = validateApn(newApn);
    if (validationError != null) {
      LogService.warn('ApnService', 'Validation rejected APN: $newApn', rawLog: validationError);
      return ApnResult.fail(validationError);
    }

    LogService.info('ApnService', 'Writing APN: $newApn');

    for (int attempt = 1; attempt <= AppConstants.writeRetries; attempt++) {
      onProgress?.call(
          attempt == 1 ? 'Sending APN…' : 'Sending APN (attempt $attempt)…');

      // Build the write command.
      final cmd =
          'AT+CGDCONT=1,"${AppConstants.pdpType}","$newApn"';

      // Send write command — collect response but we don't trust OK alone
      // because background traffic may inject a stray OK.
      await _sendAndCollect(
        cmd,
        timeoutMs: AppConstants.responseTimeoutMs,
        stopOnOk: true,
      );

      // Small pause before reading back.
      await Future.delayed(const Duration(milliseconds: 400));

      onProgress?.call('Verifying on unit…');

      // Read back and compare.
      final readResult = await readApn();

      if (!readResult.success) {
        // Couldn't even read back — retry.
        if (attempt < AppConstants.writeRetries) {
          LogService.warn('ApnService', 'Write attempt $attempt: could not read back to verify, retrying...');
          continue;
        }
        LogService.error('ApnService', 'APN write sent but could not read back to verify', rawLog: 'Target: $newApn');
        return const ApnResult.fail(
          'APN write sent but could not read back to verify.',
        );
      }

      // readApn returns "(not set)" for empty — but we just wrote something,
      // so compare the raw value.
      final readBack = readResult.value == '(not set)' ? '' : readResult.value!;

      if (readBack == newApn) {
        LogService.info('ApnService', 'APN verified on unit: $newApn');
        return ApnResult.ok(
          newApn,
          'APN updated and verified directly from unit memory.',
        );
      }

      // Mismatch — retry.
      LogService.warn('ApnService', 'Write mismatch on attempt $attempt: wrote "$newApn", read back "$readBack"');
      if (attempt < AppConstants.writeRetries) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    LogService.error('ApnService', 'APN update FAILED after ${AppConstants.writeRetries} attempts',
        rawLog: 'Target: $newApn');
    return const ApnResult.fail(
      'APN update FAILED after ${AppConstants.writeRetries} attempts. '
      'The value read back did not match what was written.',
    );
  }

  // ── Private helpers ───────────────────────────────────────────────

  /// Sends [command] and collects all RX lines for up to [timeoutMs] ms.
  /// Stops early if [stopOnOk] is true and an "OK" or "ERROR" line arrives
  /// AFTER our command echo — but see the class-level comment: we still
  /// collect by line rather than trusting a bare OK.
  Future<List<String>> _sendAndCollect(
    String command, {
    required int timeoutMs,
    bool stopOnOk = false,
  }) async {
    final collected = <String>[];
    final completer = Completer<List<String>>();
    bool commandEchoed = false;
    Timer? timer;

    final sub = _serial.lines.listen((line) {
      // Strip the [RX] / [TX] prefix that SerialService adds.
      if (line.startsWith('[RX] ')) {
        final raw = line.substring(5);
        collected.add(raw);

        // Note when our echo came back.
        if (raw.trim().toUpperCase() == command.toUpperCase()) {
          commandEchoed = true;
        }

        // Check for +CME ERROR (SIM problem) — log as info, don't block.
        if (raw.contains('+CME ERROR')) {
          // Already in collected — UI will see it in the debug log.
          // Do not treat as fatal.
        }

        // Stop collecting when we see OK or ERROR.
        if (stopOnOk) {
          final upper = raw.trim().toUpperCase();
          final isTerminator = upper == 'OK' ||
              upper.startsWith('ERROR') ||
              upper.startsWith('+CME ERROR') ||
              upper.startsWith('+CMS ERROR');

          if (isTerminator) {
            final cmdUpper = command.toUpperCase();
            final hasMatch = commandEchoed ||
                (cmdUpper.startsWith('AT+CGDCONT') &&
                    collected.any((l) => l.trim().startsWith('+CGDCONT:'))) ||
                (cmdUpper.startsWith('ATI') &&
                    collected.any((l) =>
                        l.toUpperCase().contains('QUECTEL') ||
                        l.toUpperCase().contains('EC25') ||
                        l.toUpperCase().contains('REVISION'))) ||
                collected.length >= 2;

            if (hasMatch) {
              timer?.cancel();
              if (!completer.isCompleted) completer.complete(collected);
            }
          }
        }
      }
    });

    // Send the command.
    await _serial.sendCommand(command);

    // Timeout fallback.
    timer = Timer(Duration(milliseconds: timeoutMs), () {
      if (!completer.isCompleted) completer.complete(collected);
    });

    final result = await completer.future;
    await sub.cancel();
    timer.cancel();
    return result;
  }

  /// Parses the APN from a list of raw RX lines.
  ///
  /// Looks for a line matching:
  ///   +CGDCONT: 1,"<type>","<apn>", ...
  /// Returns the APN string (may be empty string), or null if not found.
  String? _parseApnFromLines(List<String> lines) {
    // Tolerant regex: optional spaces, context 1 only.
    final re = RegExp(
      r'^\+CGDCONT:\s*1\s*,\s*"[^"]*"\s*,\s*"([^"]*)"',
      caseSensitive: false,
    );

    for (final line in lines) {
      final match = re.firstMatch(line.trim());
      if (match != null) {
        return match.group(1) ?? '';
      }
    }
    return null; // not found in this batch
  }
}
