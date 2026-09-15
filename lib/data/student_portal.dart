class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.studentId,
    required this.amount,
    required this.paidOn,
    required this.method,
    this.groupId,
    this.note = '',
  });
  final String id, studentId, method, note;
  final int amount;
  final DateTime paidOn;
  final String? groupId;
}

class CourseProgress {
  const CourseProgress(this.completed, this.total);
  final int completed, total;
  double get fraction => total == 0 ? 0 : completed / total;
  String get label => total == 0 ? '—' : '${(fraction * 100).round()}%';
}
