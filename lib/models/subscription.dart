/// Подписка (список серверов по URL).
class Subscription {
  Subscription({
    required this.id,
    required this.name,
    required this.url,
    this.updateIntervalHours = 24,
    this.lastUpdated,
    this.upload = 0,
    this.download = 0,
    this.total = 0,
    this.expireAt,
  });

  final String id;
  String name;
  String url;
  int updateIntervalHours;
  DateTime? lastUpdated;

  /// Квоты из заголовка `subscription-userinfo`.
  int upload;
  int download;
  int total;
  DateTime? expireAt;

  int get usedTraffic => upload + download;

  double? get usageRatio {
    if (total <= 0) return null;
    return (usedTraffic / total).clamp(0.0, 1.0);
  }

  bool get isExpired =>
      expireAt != null && expireAt!.isBefore(DateTime.now());

  Duration? get expiresIn {
    final e = expireAt;
    if (e == null) return null;
    final d = e.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'updateIntervalHours': updateIntervalHours,
        if (lastUpdated != null) 'lastUpdated': lastUpdated!.toIso8601String(),
        'upload': upload,
        'download': download,
        'total': total,
        if (expireAt != null) 'expireAt': expireAt!.toIso8601String(),
      };

  factory Subscription.fromJson(Map<String, dynamic> j) => Subscription(
        id: j['id'] as String? ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: j['name'] as String? ?? 'Subscription',
        url: j['url'] as String? ?? '',
        updateIntervalHours:
            int.tryParse(j['updateIntervalHours']?.toString() ?? '') ?? 24,
        lastUpdated: DateTime.tryParse(j['lastUpdated'] as String? ?? ''),
        upload: int.tryParse(j['upload']?.toString() ?? '') ?? 0,
        download: int.tryParse(j['download']?.toString() ?? '') ?? 0,
        total: int.tryParse(j['total']?.toString() ?? '') ?? 0,
        expireAt: DateTime.tryParse(j['expireAt'] as String? ?? ''),
      );
}
