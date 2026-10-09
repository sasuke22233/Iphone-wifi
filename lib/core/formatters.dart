/// Форматирование чисел, скоростей и времени.
class Fmt {
  Fmt._();

  /// 1.2 КБ/с, 3.4 МБ/с …
  static String speed(double bytesPerSecond) {
    if (bytesPerSecond < 1) return '0 Б/с';
    const units = ['Б/с', 'КБ/с', 'МБ/с', 'ГБ/с'];
    var value = bytesPerSecond;
    var i = 0;
    while (value >= 1024 && i < units.length - 1) {
      value /= 1024;
      i++;
    }
    final digits = value >= 100 ? 0 : (value >= 10 ? 1 : 2);
    return '${value.toStringAsFixed(digits)} ${units[i]}';
  }

  /// 512 Б, 3.4 МБ, 1.2 ГБ …
  static String bytes(num bytesCount) {
    if (bytesCount <= 0) return '0 Б';
    const units = ['Б', 'КБ', 'МБ', 'ГБ', 'ТБ'];
    var value = bytesCount.toDouble();
    var i = 0;
    while (value >= 1024 && i < units.length - 1) {
      value /= 1024;
      i++;
    }
    final digits = value >= 100 ? 0 : (value >= 10 ? 1 : 2);
    return '${value.toStringAsFixed(digits)} ${units[i]}';
  }

  static String ping(int? ms) {
    if (ms == null || ms < 0) return '—';
    return '$ms мс';
  }

  static String pingEn(int? ms) {
    if (ms == null || ms < 0) return '—';
    return '$ms ms';
  }

  /// 01:23:45
  static String duration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  static String dateTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (day == today) return time;
    if (day == today.subtract(const Duration(days: 1))) return 'вчера $time';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')} $time';
  }

  /// Человекочитаемый рейтинг задержки.
  static String latencyLabel(int? ms) {
    if (ms == null || ms < 0) return '—';
    if (ms < 120) return 'отлично';
    if (ms < 250) return 'хорошо';
    if (ms < 500) return 'средне';
    return 'высокая';
  }
}
