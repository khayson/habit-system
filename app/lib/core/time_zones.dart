import 'dart:async';

import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import '../domain/calendar/timezone_timeline.dart';

/// The bundled tz database, loaded once after the first frame so start-up is never delayed.
/// Anything that resolves habit-days (Today, the writer) waits for [ready].
abstract final class TimeZones {
  static final Completer<void> _ready = Completer<void>();

  static Future<void> get ready => _ready.future;

  static void load() {
    if (_ready.isCompleted) return;
    ensureTimeZonesLoaded(tzdata.initializeTimeZones);
    _ready.complete();
  }
}

/// The device's IANA zone. Replaceable in tests; screens never read the platform directly.
abstract final class DeviceZone {
  static Future<String> Function() read = _platform;

  static Future<String> _platform() async => (await FlutterTimezone.getLocalTimezone()).identifier;
}

Future<String> deviceTimezone() => DeviceZone.read();
