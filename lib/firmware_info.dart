// firmware_info.dart
// Encapsulates firmware metadata, binary inspection, and persistence.

import 'dart:typed_data';

class FirmwareInfo {
  final String fileName;
  final int fileSizeBytes;
  final String targetMcu;
  final String boardModel;
  final String version;
  final String buildNumber;
  final String features;
  final int totalPackets;
  final String checksumCrc;
  final String flashDate;
  final bool isVerified;

  const FirmwareInfo({
    required this.fileName,
    required this.fileSizeBytes,
    required this.targetMcu,
    required this.boardModel,
    required this.version,
    required this.buildNumber,
    required this.features,
    required this.totalPackets,
    required this.checksumCrc,
    this.flashDate = '',
    this.isVerified = false,
  });

  String get displayVersion => '$version (Build $buildNumber)';

  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'fileSizeBytes': fileSizeBytes,
        'targetMcu': targetMcu,
        'boardModel': boardModel,
        'version': version,
        'buildNumber': buildNumber,
        'features': features,
        'totalPackets': totalPackets,
        'checksumCrc': checksumCrc,
        'flashDate': flashDate,
        'isVerified': isVerified,
      };

  factory FirmwareInfo.fromJson(Map<String, dynamic> json) => FirmwareInfo(
        fileName: json['fileName'] ?? '',
        fileSizeBytes: json['fileSizeBytes'] ?? 0,
        targetMcu: json['targetMcu'] ?? 'HC32F460',
        boardModel: json['boardModel'] ?? '8848 FWT (TDM-9641)',
        version: json['version'] ?? 'V0.0.0.5',
        buildNumber: json['buildNumber'] ?? '202411140001',
        features: json['features'] ?? 'Voice SLIC, SMS Forwarding, 7-Day Reports',
        totalPackets: json['totalPackets'] ?? 0,
        checksumCrc: json['checksumCrc'] ?? 'CRC-16 CCITT',
        flashDate: json['flashDate'] ?? '',
        isVerified: json['isVerified'] ?? false,
      );

  static FirmwareInfo parse(
    String fileName,
    Uint8List bytes, {
    String? flashDate,
    bool isVerified = false,
  }) {
    // 1. Version regex match from filename (e.g. V0.0.0.5)
    final verMatch =
        RegExp(r'V[0-9]+(\.[0-9]+)+', caseSensitive: false).firstMatch(fileName);
    final version = verMatch != null ? verMatch.group(0)! : 'V0.0.0.5';

    // 2. Binary inspection (first 180 KB for strings)
    String text = '';
    try {
      final sampleLength = bytes.length > 180000 ? 180000 : bytes.length;
      text = String.fromCharCodes(bytes.sublist(0, sampleLength));
    } catch (_) {}

    // Extract build timestamp number (e.g. 202411140001)
    final buildMatch = RegExp(r'202[0-9]{9}').firstMatch(text);
    final build = buildMatch != null ? buildMatch.group(0)! : '202411140001';

    String mcu = 'Huada HC32F460';
    if (text.contains('HC32F460') || fileName.contains('HC460')) {
      mcu = 'HC32F460 (ARM Cortex-M4)';
    }

    String board = '8848 FWT (TDM-9641)';
    if (text.contains('fwt8848TDM-9641') || fileName.contains('9641')) {
      board = '8848 FWT (TDM-9641)';
    }

    String features = 'Voice SLIC, SMS Forwarding, 7-Day Health Reports';
    if (fileName.contains('forward_sms') || fileName.contains('forward-sms')) {
      features = 'SMS Forwarding & 7-Day Health Reports';
    }

    final totalPackets = ((bytes.length + 1023) ~/ 1024);

    return FirmwareInfo(
      fileName: fileName,
      fileSizeBytes: bytes.length,
      targetMcu: mcu,
      boardModel: board,
      version: version,
      buildNumber: build,
      features: features,
      totalPackets: totalPackets,
      checksumCrc: 'CRC-16 CCITT',
      flashDate: flashDate ?? '',
      isVerified: isVerified,
    );
  }
}
