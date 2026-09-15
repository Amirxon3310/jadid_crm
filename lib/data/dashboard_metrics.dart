import 'models.dart';

class MetricValue {
  const MetricValue(this.current, this.previous);
  final double current;
  final double? previous;
  double? get growth => previous == null || previous == 0
      ? null
      : (current - previous!) / previous! * 100;
  bool get isNew => previous == 0 && current > 0;
  String get growthLabel {
    if (isNew) return 'Yangi';
    if (previous == null) return '—';
    final value = growth ?? 0;
    final rounded = value
        .abs()
        .toStringAsFixed(1)
        .replaceFirst(RegExp(r'\.0$'), '');
    return '${value > 0
        ? '+'
        : value < 0
        ? '−'
        : ''}$rounded%';
  }

  String get explanation => previous == null
      ? 'O‘tgan oy uchun tarix mavjud emas.'
      : isNew
      ? 'Bir oy oldin qiymat 0 edi. O‘sish foizini hisoblab bo‘lmaydi.'
      : 'Bir oy oldingi qiymatga nisbatan o‘zgarish.';
}

class DashboardMetrics {
  DashboardMetrics(this.current, this.previous);
  final Map<String, dynamic> current;
  final Map<String, dynamic>? previous;
  factory DashboardMetrics.fromJson(Map<String, dynamic> json) =>
      DashboardMetrics(
        Map<String, dynamic>.from(json['current']),
        json['previous'] == null
            ? null
            : Map<String, dynamic>.from(json['previous']),
      );
  factory DashboardMetrics.fromUsers(List<AppUser> users) {
    final students = users.where((u) => u.role == AppRole.student).toList();
    return DashboardMetrics({
      'employees': users.where((u) => u.role != AppRole.student).length,
      'students': students.length,
      'graduates': students.where((u) => u.studyStatus != 'studying').length,
      'success_rate': students.isEmpty
          ? 0
          : 100 *
                students.where((u) => u.studyStatus == 'graduated').length /
                students.length,
    }, null);
  }
  MetricValue value(String key) => MetricValue(
    (current[key] as num? ?? 0).toDouble(),
    (previous?[key] as num?)?.toDouble(),
  );
}
