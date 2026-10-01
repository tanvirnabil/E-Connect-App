// ============================================================
// constants.dart
//
// ALL timings, serial settings, and protocol constants live
// here. Change a value once and it applies everywhere.
// ============================================================

class AppConstants {
  // ── Serial port settings ────────────────────────────────
  static const int baudRate  = 115200;
  // UsbPort integer constants (see usb_serial package):
  //   DATABITS_8 = 8,  STOPBITS_1 = 1,  PARITY_NONE = 0
  // They are referenced directly in serial_service.dart via UsbPort.*

  // ── Noise / quiet-window timing ─────────────────────────
  /// Wait this many ms of silence before sending a command.
  static const int quietWindowMs   = 300;
  /// If the line never goes quiet, give up and send after this many ms.
  static const int quietTimeoutMs  = 2000;
  /// Max ms to wait for a response after sending a command.
  static const int responseTimeoutMs = 3000;
  /// Max ms to wait for ATI response during the connect handshake.
  static const int connectTimeoutMs  = 5000;

  // ── APN write ───────────────────────────────────────────
  /// PDP type used in AT+CGDCONT=1,"<pdpType>","<apn>".
  /// Change to "IPV4V6" here when ECS confirms the correct type.
  static const String pdpType = 'IP';

  // ── Retry counts ────────────────────────────────────────
  static const int readRetries  = 3;
  static const int writeRetries = 3;

  // ── Shared preferences keys ─────────────────────────────
  static const String lastApnKey = 'last_apn';
  static const String defaultApn = 'ERESELLER';
}
