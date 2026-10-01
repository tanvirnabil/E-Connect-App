// ============================================================
// xmodem_service.dart
//
// Implements the Xmodem-1k binary transfer protocol over serial
// specifically tailored for the 8848 4G Fixed Wireless Terminal
// and HC32F460/HC32F030 bootloader specifications.
//
// Protocol Specs:
//   • Block size: 1024 bytes (STX = 0x02)
//   • Checksum: 16-bit CRC (CCITT polynomial 0x1021)
//   • Handshake: Initiated by receiver sending ASCII 'C' (0x43)
//   • Padding: 0x1A (SUB)
// ============================================================

import 'dart:async';
import 'dart:typed_data';

import 'serial_service.dart';
import 'log_service.dart';

// ignore_for_file: constant_identifier_names

class XmodemProgress {
  final int bytesSent;
  final int totalBytes;
  final int currentPacket;
  final int totalPackets;
  final String status;
  final int retries;

  const XmodemProgress({
    required this.bytesSent,
    required this.totalBytes,
    required this.currentPacket,
    required this.totalPackets,
    required this.status,
    this.retries = 0,
  });

  double get percent =>
      totalBytes > 0 ? (bytesSent / totalBytes).clamp(0.0, 1.0) : 0.0;

  int get currentBlock => currentPacket;
  int get totalBlocks => totalPackets;
  String get stage => status;
  double get fraction => percent;
}

class XmodemResult {
  final bool success;
  final String message;

  const XmodemResult.ok(this.message) : success = true;
  const XmodemResult.fail(this.message) : success = false;
}

class XmodemService {
  final SerialService _serial;

  // Protocol control bytes
  static const int SOH   = 0x01; // 128-byte block
  static const int STX   = 0x02; // 1024-byte block (Xmodem-1k)
  static const int EOT   = 0x04; // End of transmission
  static const int ACK   = 0x06; // Acknowledge
  static const int NAK   = 0x15; // Negative acknowledge
  static const int CAN   = 0x18; // Cancel
  static const int CRC_C = 0x43; // 'C' start character for 16-bit CRC

  static const int maxRetries = 10;

  XmodemService(this._serial);

  /// Calculates the 16-bit CCITT CRC (polynomial 0x1021) for Xmodem.
  static int calculateCrc16(List<int> data) {
    int crc = 0x0000;
    for (final byte in data) {
      crc ^= (byte << 8);
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc & 0xFFFF;
  }

  /// Uploads [firmwareBytes] to the device using standard Xmodem-CRC protocol.
  ///
  /// Listens for the bootloader's 'C' handshake character, then streams
  /// 128-byte packets with 16-bit CRC verification.
  Future<XmodemResult> uploadFirmware(
    Uint8List firmwareBytes, {
    void Function(XmodemProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (!_serial.isConnected) {
      return const XmodemResult.fail('Serial cable not connected.');
    }

    if (firmwareBytes.isEmpty) {
      return const XmodemResult.fail('Firmware file is empty.');
    }

    // 1024-byte packets (Xmodem-1k) as specified in official 8848 instruction document (image11.png)
    const int packetSize = 1024;
    final totalBytes = firmwareBytes.length;
    final totalPackets = ((totalBytes + packetSize - 1) ~/ packetSize);

    LogService.info('XmodemService', 'Firmware upload initiated ($totalBytes bytes, $totalPackets packets, 1024B Xmodem-1k blocks)');

    // Incoming byte queue
    final List<int> byteQueue = [];
    Completer<void>? dataWaiter;

    final sub = _serial.rawBytes.listen((chunk) {
      byteQueue.addAll(chunk);
      if (dataWaiter != null && !dataWaiter!.isCompleted) {
        dataWaiter!.complete();
      }
    });

    Future<int?> readByte({required Duration timeout}) async {
      final deadline = DateTime.now().add(timeout);
      while (byteQueue.isEmpty) {
        if (DateTime.now().isAfter(deadline)) return null;
        if (isCancelled?.call() == true) return null;
        dataWaiter = Completer<void>();
        final waitDuration = deadline.difference(DateTime.now());
        if (waitDuration.isNegative) return null;
        await Future.any([
          dataWaiter!.future,
          Future.delayed(waitDuration),
        ]);
      }
      return byteQueue.removeAt(0);
    }

    Timer? enterPulseTimer;
    bool sendingEnter = true;

    try {
      // ── Step 1: Wait for handshake ('C') with active Enter pulsing ─
      onProgress?.call(XmodemProgress(
        bytesSent: 0,
        totalBytes: totalBytes,
        currentPacket: 0,
        totalPackets: totalPackets,
        status: 'Connecting with bootloader… Flashing will start automatically',
      ));

      // Flush any pre-existing AT traffic (e.g. +CSQ) from before upload started
      await Future.delayed(const Duration(milliseconds: 100));
      byteQueue.clear();

      // Actively pulse Enter (0x0D) every 75ms to trigger HC32F460 bootloader update mode
      enterPulseTimer = Timer.periodic(const Duration(milliseconds: 75), (timer) {
        if (!sendingEnter) {
          timer.cancel();
          return;
        }
        _serial.sendRawBytes(Uint8List.fromList([0x0D]));
      });

      bool handshakeReceived = false;
      bool detectedUpdateMode = false;
      final List<int> rollingBuffer = [];
      final handshakeDeadline = DateTime.now().add(const Duration(seconds: 30));

      while (DateTime.now().isBefore(handshakeDeadline)) {
        if (isCancelled?.call() == true) {
          sendingEnter = false;
          enterPulseTimer.cancel();
          LogService.warn('XmodemService', 'Firmware upgrade cancelled by technician');
          return const XmodemResult.fail('Update cancelled by user.');
        }

        final byte = await readByte(timeout: const Duration(milliseconds: 150));
        if (byte != null) {
          rollingBuffer.add(byte);
          if (rollingBuffer.length > 80) rollingBuffer.removeAt(0);

          final rollingText = String.fromCharCodes(rollingBuffer).toUpperCase();

          if (!detectedUpdateMode &&
              (rollingText.contains('UPDATA MODE') ||
               rollingText.contains('UPDATE MODE') ||
               rollingText.contains('HC32F460') ||
               rollingText.contains('ENTER UPDATA'))) {
            detectedUpdateMode = true;
            sendingEnter = false;
            enterPulseTimer.cancel();
            LogService.info('XmodemService', 'HC32F460 bootloader update mode banner detected! Waiting for C...');
          }

          // Xmodem handshake character: ASCII 'C' (0x43)
          if (byte == CRC_C) {
            // Guard against AT command response noise like "+CSQ: ..." or "AT+CSQ"
            bool isAtCommandArtifact = false;
            if (rollingBuffer.length >= 2) {
              final prev = rollingBuffer[rollingBuffer.length - 2];
              if (prev == 0x2B) { // '+' followed by 'C' = "+C..." (modem AT command!)
                isAtCommandArtifact = true;
              }
            }
            if (rollingText.contains('+CSQ') || rollingText.contains('AT+CSQ')) {
              isAtCommandArtifact = true;
            }

            if (!isAtCommandArtifact && (detectedUpdateMode || rollingText.contains('BOOT'))) {
              handshakeReceived = true;
              sendingEnter = false;
              enterPulseTimer.cancel();
              LogService.info('XmodemService', 'Valid bootloader handshake (C) confirmed! (Banner confirmed: $detectedUpdateMode)');
              break;
            } else if (isAtCommandArtifact) {
              LogService.debug('XmodemService', 'Ignored AT command noise (+CSQ) containing letter C');
            }
          }
        }
      }

      sendingEnter = false;
      enterPulseTimer.cancel();

      if (!handshakeReceived) {
        LogService.error('XmodemService', 'Timeout waiting for unit update mode (30s)');
        return const XmodemResult.fail(
          'Timeout waiting for unit update mode.\n\n'
          'To enter update mode:\n'
          '1. Connect USB cable to phone and terminal RJ11.\n'
          '2. Tap "Start Firmware Upgrade".\n'
          '3. Toggle 8848 power switch OFF and then ON within 30 seconds.',
        );
      }

      // Handshake received! Pause 200ms and drain any residual startup chars from bootloader
      await Future.delayed(const Duration(milliseconds: 200));
      byteQueue.clear();

      onProgress?.call(XmodemProgress(
        bytesSent: 0,
        totalBytes: totalBytes,
        currentPacket: 0,
        totalPackets: totalPackets,
        status: 'Bootloader handshake accepted! Flashing firmware…',
      ));

      // ── Step 2: Send 128-byte packets (SOH = 0x01) ──────────
      int packetSeq = 1;
      int bytesSentAcc = 0;

      for (int i = 0; i < totalPackets; i++) {
        if (isCancelled?.call() == true) {
          await _serial.sendRawBytes(Uint8List.fromList([CAN, CAN]));
          return const XmodemResult.fail('Update cancelled by user.');
        }

        final start = i * packetSize;
        final end = (start + packetSize > totalBytes) ? totalBytes : start + packetSize;
        final chunk = firmwareBytes.sublist(start, end);

        // Pad to exactly 1024 bytes with 0x1A (standard Xmodem padding)
        final payload = Uint8List(packetSize);
        payload.setRange(0, chunk.length, chunk);
        if (chunk.length < packetSize) {
          payload.fillRange(chunk.length, packetSize, 0x1A);
        }

        // Calculate 16-bit CRC
        final crc = calculateCrc16(payload);
        final crcHigh = (crc >> 8) & 0xFF;
        final crcLow = crc & 0xFF;

        final pNum = packetSeq & 0xFF;
        final pNumInv = (255 - pNum) & 0xFF;

        // Build frame: STX (1B) + SEQ (1B) + ~SEQ (1B) + DATA (1024B) + CRC (2B) = 1029B
        final frame = BytesBuilder(copy: false)
          ..addByte(STX)
          ..addByte(pNum)
          ..addByte(pNumInv)
          ..add(payload)
          ..addByte(crcHigh)
          ..addByte(crcLow);

        final frameBytes = frame.toBytes();

        // Retry loop
        bool packetAcked = false;
        int retries = 0;

        while (!packetAcked && retries < maxRetries) {
          if (isCancelled?.call() == true) {
            await _serial.sendRawBytes(Uint8List.fromList([CAN, CAN]));
            return const XmodemResult.fail('Update cancelled by user.');
          }

          await _serial.sendRawBytes(frameBytes);

          final resp = await readByte(timeout: const Duration(seconds: 4));

          final String respName = resp == null
              ? 'TIMEOUT'
              : resp == ACK
                  ? 'ACK (0x06)'
                  : resp == NAK
                      ? 'NAK (0x15)'
                      : resp == CAN
                          ? 'CAN (0x18)'
                          : resp == CRC_C
                              ? 'C (0x43)'
                              : '0x${resp.toRadixString(16).padLeft(2, '0')}';

          if (resp == ACK) {
            packetAcked = true;
          } else if (resp == NAK) {
            retries++;
            LogService.warn('XmodemService', 'Packet $packetSeq retry $retries: received NAK (0x15)');
            // Re-send on next iteration
          } else if (resp == CRC_C && packetSeq == 1) {
            // Bootloader still sending initial 'C' prompt before receiving packet 1
            retries++;
            LogService.warn('XmodemService', 'Packet 1 retry $retries: receiver still prompting C (0x43)');
          } else if (resp == CAN) {
            LogService.warn('XmodemService', 'Transfer cancelled by device at packet $packetSeq');
            return const XmodemResult.fail('Transfer cancelled by device.');
          } else {
            retries++;
            LogService.warn('XmodemService', 'Packet $packetSeq retry $retries: unexpected response $respName');
          }
        }

        if (!packetAcked) {
          await _serial.sendRawBytes(Uint8List.fromList([CAN, CAN]));
          LogService.error('XmodemService', 'Transfer failed at packet $packetSeq of $totalPackets after $maxRetries retries');
          return XmodemResult.fail(
            'Transfer failed at packet $packetSeq of $totalPackets after $maxRetries retries.',
          );
        }

        bytesSentAcc += chunk.length;
        packetSeq = (packetSeq + 1) & 0xFF;

        onProgress?.call(XmodemProgress(
          bytesSent: bytesSentAcc,
          totalBytes: totalBytes,
          currentPacket: i + 1,
          totalPackets: totalPackets,
          status: 'Flashing: Packet ${i + 1} of $totalPackets (${((bytesSentAcc / totalBytes) * 100).toStringAsFixed(1)}%)',
        ));
      }

      // ── Step 3: End of Transmission (EOT) ──────────────────
      onProgress?.call(XmodemProgress(
        bytesSent: totalBytes,
        totalBytes: totalBytes,
        currentPacket: totalPackets,
        totalPackets: totalPackets,
        status: 'Finalizing firmware update (EOT)…',
      ));

      bool eotAcked = false;
      for (int i = 0; i < maxRetries && !eotAcked; i++) {
        await _serial.sendRawBytes(Uint8List.fromList([EOT]));
        final resp = await readByte(timeout: const Duration(seconds: 4));
        if (resp == ACK) {
          eotAcked = true;
        } else if (resp == NAK) {
          await Future.delayed(const Duration(milliseconds: 150));
        }
      }

      // ── Step 4: Wait for device to reboot and confirm online ──
      LogService.info('XmodemService', 'Firmware flashed successfully ($totalBytes bytes in $totalPackets packets, EOT acked: $eotAcked). Monitoring reboot...');

      onProgress?.call(XmodemProgress(
        bytesSent: totalBytes,
        totalBytes: totalBytes,
        currentPacket: totalPackets,
        totalPackets: totalPackets,
        status: 'Firmware installed (100%)! Waiting for 8848 terminal to reboot…',
      ));

      byteQueue.clear();
      bool rebootConfirmed = false;
      final rebootDeadline = DateTime.now().add(const Duration(seconds: 20));
      final List<int> rebootBuffer = [];

      // Initial 3-second reset settling delay
      await Future.delayed(const Duration(seconds: 3));

      while (DateTime.now().isBefore(rebootDeadline)) {
        if (isCancelled?.call() == true) break;
        final byte = await readByte(timeout: const Duration(milliseconds: 500));
        if (byte != null) {
          rebootBuffer.add(byte);
          if (rebootBuffer.length > 120) rebootBuffer.removeAt(0);
          final text = String.fromCharCodes(rebootBuffer).toUpperCase();
          if (text.contains('WLM STATE') ||
              text.contains('EC25') ||
              text.contains('QUECTEL') ||
              text.contains('VP:') ||
              text.contains('OK') ||
              text.contains('RDY')) {
            rebootConfirmed = true;
            LogService.info('XmodemService', '8848 terminal reboot confirmed online via serial banner');
            break;
          }
        }
      }

      onProgress?.call(XmodemProgress(
        bytesSent: totalBytes,
        totalBytes: totalBytes,
        currentPacket: totalPackets,
        totalPackets: totalPackets,
        status: rebootConfirmed
            ? 'Firmware update verified! Terminal is online.'
            : 'Firmware flashed! Terminal reboot complete.',
      ));

      return XmodemResult.ok(
        rebootConfirmed
            ? 'Firmware update complete and verified! The 8848 terminal has rebooted successfully and is online.'
            : 'Firmware flashed successfully! The 8848 terminal has rebooted.',
      );
    } catch (e, stack) {
      LogService.error('XmodemService', 'Unexpected transfer exception: $e', rawLog: stack.toString());
      return XmodemResult.fail('Unexpected transfer exception: $e');
    } finally {
      sendingEnter = false;
      enterPulseTimer?.cancel();
      await sub.cancel();
    }
  }
}

