import 'package:flutter/material.dart';

import '../core/theme.dart';

enum LogLevel { debug, info, warning, error }

class LogEntry {
  LogEntry({
    required this.time,
    required this.level,
    required this.message,
    this.source = 'core',
  });

  final DateTime time;
  final LogLevel level;
  final String message;
  final String source;

  Color get color {
    switch (level) {
      case LogLevel.debug:
        return AuraColors.textFaint;
      case LogLevel.info:
        return AuraColors.textSecondary;
      case LogLevel.warning:
        return AuraColors.warning;
      case LogLevel.error:
        return AuraColors.danger;
    }
  }

  String get levelTag {
    switch (level) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
    }
  }

  /// Разбор строки лога Xray (`2026/01/01 12:00:00 [Info] ...`).
  factory LogEntry.fromCoreLine(String line, {String source = 'xray'}) {
    var level = LogLevel.info;
    final lower = line.toLowerCase();
    if (lower.contains('[error]') || lower.contains('failed')) {
      level = LogLevel.error;
    } else if (lower.contains('[warning]') || lower.contains('warning')) {
      level = LogLevel.warning;
    } else if (lower.contains('[debug]') || lower.contains('[debug')) {
      level = LogLevel.debug;
    }
    return LogEntry(
      time: DateTime.now(),
      level: level,
      message: line.trim(),
      source: source,
    );
  }
}
