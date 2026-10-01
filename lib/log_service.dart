// log_service.dart
// Send log entries to the remote server.
// Call LogService.error() / .warn() / .info() anywhere in the app.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const String _kLogUrl     = 'https://connect.myelevatorphones.com/app_logs/ingest';
const String _kApiToken   = 'ecs-log-token-2026';
const String _kAppVersion = '1.0.12';

class LogService {

  // ── Call these from anywhere in the app ──────────────────────────

  /// Use for detailed tracing during development
  static Future<void> debug(String tag, String message, {String? rawLog}) =>
      _send('debug', tag, message, rawLog: rawLog);

  /// Normal events (connected, APN read, etc.)
  static Future<void> info(String tag, String message, {String? rawLog}) =>
      _send('info', tag, message, rawLog: rawLog);

  /// Something unexpected but not fatal
  static Future<void> warn(String tag, String message, {String? rawLog}) =>
      _send('warn', tag, message, rawLog: rawLog);

  /// Something failed (port error, APN mismatch, etc.)
  static Future<void> error(String tag, String message, {String? rawLog}) =>
      _send('error', tag, message, rawLog: rawLog);

  /// App is in a broken state
  static Future<void> critical(String tag, String message, {String? rawLog}) =>
      _send('critical', tag, message, rawLog: rawLog);

  // ── Internal ─────────────────────────────────────────────────────

  static Future<void> _send(String level, String tag, String message, {String? rawLog}) async {
    // Always print to console too.
    // ignore: avoid_print
    print('[${level.toUpperCase()}][$tag] $message${rawLog != null ? "\n$rawLog" : ""}');

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.postUrl(Uri.parse(_kLogUrl));
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('X-Log-Token', _kApiToken);
      request.write(jsonEncode({
        'device_id':   _deviceId,
        'app_version': _kAppVersion,
        'level':       level,
        'tag':         tag,
        'message':     message,
        'raw_log':     rawLog,
      }));
      final response = await request.close().timeout(const Duration(seconds: 8));
      await response.drain<void>();
      client.close();
    } catch (_) {
      // Never crash the app because of a logging failure.
    }
  }

  static String get _deviceId {
    try {
      return Platform.isAndroid ? 'Android Phone' : Platform.operatingSystem;
    } catch (_) {
      return 'unknown';
    }
  }
}

