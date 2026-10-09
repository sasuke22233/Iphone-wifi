import 'package:flutter/material.dart';

import '../models/log_entry.dart';

/// Простой кольцевой буфер логов для экрана «Логи» (ChangeNotifier).
class AppLogger extends ChangeNotifier {
  AppLogger({this.capacity = 500});

  final int capacity;
  final List<LogEntry> _entries = [];

  List<LogEntry> get entries => List.unmodifiable(_entries);

  void add(LogEntry entry) {
    _entries.add(entry);
    if (_entries.length > capacity) {
      _entries.removeRange(0, _entries.length - capacity);
    }
    notifyListeners();
  }

  void info(String message, {String source = 'app'}) => add(LogEntry(
      time: DateTime.now(),
      level: LogLevel.info,
      message: message,
      source: source));

  void warn(String message, {String source = 'app'}) => add(LogEntry(
      time: DateTime.now(),
      level: LogLevel.warning,
      message: message,
      source: source));

  void error(String message, {String source = 'app'}) => add(LogEntry(
      time: DateTime.now(),
      level: LogLevel.error,
      message: message,
      source: source));

  void addCoreLines(Iterable<String> lines, {String source = 'core'}) {
    var changed = false;
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      _entries.add(LogEntry.fromCoreLine(line, source: source));
      changed = true;
    }
    if (_entries.length > capacity) {
      _entries.removeRange(0, _entries.length - capacity);
    }
    if (changed) notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}
