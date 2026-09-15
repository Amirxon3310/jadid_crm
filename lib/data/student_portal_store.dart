part of 'crm_store.dart';

extension StudentPortalStore on CrmStore {
  Future<void> _loadStudentPortal() async {
    final org = activeUser.organizationId;
    final data = await Future.wait<dynamic>([
      client!
          .from('branches')
          .select('name')
          .eq('organization_id', org)
          .order('name'),
      activeRole == AppRole.teacher
          ? Future.value(<dynamic>[])
          : client!
                .from('payments')
                .select()
                .eq('organization_id', org)
                .order('paid_on', ascending: false),
      activeRole == AppRole.student
          ? client!.rpc('student_rankings', params: {'p_organization_id': org})
          : Future.value(<String, dynamic>{}),
    ]);
    branches
      ..clear()
      ..addAll((data[0] as List).map((row) => row['name'] as String));
    payments
      ..clear()
      ..addAll(
        (data[1] as List).map(
          (row) => _paymentFromRow(Map<String, dynamic>.from(row)),
        ),
      );
    _studentRanks = Map<String, dynamic>.from(data[2] as Map);
  }

  PaymentRecord _paymentFromRow(Map<String, dynamic> row) => PaymentRecord(
    id: row['id'].toString(),
    studentId: users
        .firstWhere(
          (u) => u.membershipId == row['student_membership_id'].toString(),
        )
        .id,
    amount: (row['amount'] as num).toInt(),
    paidOn: DateTime.parse(row['paid_on'] as String),
    method: row['method'] as String,
    groupId: row['group_id']?.toString(),
    note: row['note'] as String? ?? '',
  );
  bool canManageGroup(String groupId) =>
      activeRole == AppRole.admin ||
      (activeRole == AppRole.teacher &&
          groupById(groupId).teacherId == activeUser.id);
  int pointsOf(String userId) =>
      (_pointTotals[userId] ?? 0) +
      localPointsOf(userId) -
      (_pointBaseline[userId] ?? 0);
  int? rankFor({String? groupId}) {
    if (isOnline && activeRole == AppRole.student) {
      final value = groupId == null
          ? _studentRanks['center_rank']
          : (_studentRanks['groups'] as Map?)?[resolveId(groupId)];
      return (value as num?)?.toInt();
    }
    final peers = groupId == null
        ? users.where((u) => u.role == AppRole.student).map((u) => u.id).toSet()
        : studentsOf(groupId).map((s) => s.id).toSet();
    if (!peers.contains(activeUser.id)) return null;
    return 1 +
        peers.where((id) => pointsOf(id) > pointsOf(activeUser.id)).length;
  }

  CourseProgress progressFor(String groupId) {
    final schedule = lessonsOf(
      groupId,
    ).where((l) => l.status != 'cancelled').toList();
    return CourseProgress(
      schedule.where((l) => l.status == 'completed').length,
      schedule.length,
    );
  }

  Future<void> addBranch(String name) async {
    if (activeRole != AppRole.admin) throw StateError('Admin huquqi kerak.');
    final value = name.trim();
    if (value.isEmpty || value.length > 80)
      throw ArgumentError('Filial nomini kiriting.');
    if (branches.any((b) => b.toLowerCase() == value.toLowerCase()))
      throw ArgumentError('Bu filial mavjud.');
    final org = activeUser.organizationId;
    await _mutate<void>(
      apply: () {
        branches.add(value);
        branches.sort();
      },
      send: () async {
        await client!.from('branches').insert({
          'organization_id': org,
          'name': value,
        });
      },
    );
  }

  Future<void> addPayment({
    required String studentId,
    required int amount,
    required DateTime paidOn,
    required String method,
    String? groupId,
    String note = '',
  }) async {
    if (activeRole != AppRole.admin) throw StateError('Admin huquqi kerak.');
    if (amount <= 0 ||
        amount > 1000000000000 ||
        !['cash', 'card', 'transfer'].contains(method) ||
        note.length > 500)
      throw ArgumentError('To‘lov ma’lumotlarini tekshiring.');
    final student = users.firstWhere(
      (u) => u.id == studentId && u.role == AppRole.student,
    );
    if (groupId != null) studentById(studentId, groupId);
    final temp = _newId();
    final org = activeUser.organizationId;
    await _mutate<Map<String, dynamic>>(
      apply: () {
        if (groupId != null) studentById(studentId, groupId);
        payments.insert(
          0,
          PaymentRecord(
            id: temp,
            studentId: studentId,
            amount: amount,
            paidOn: paidOn,
            method: method,
            groupId: groupId == null ? null : resolveId(groupId),
            note: note,
          ),
        );
      },
      send: () => client!
          .from('payments')
          .insert({
            'organization_id': org,
            'student_membership_id': int.parse(student.membershipId),
            'group_id': groupId == null ? null : _serverId(groupId),
            'amount': amount,
            'paid_on': paidOn.toIso8601String().substring(0, 10),
            'method': method,
            'note': note,
          })
          .select()
          .single(),
      reconcile: (row) {
        payments[payments.indexWhere((p) => p.id == temp)] = _paymentFromRow(
          row,
        );
      },
    );
  }

  Future<void> setLessonStatus(String lessonId, String status) async {
    final lesson = lessons.firstWhere((l) => l.id == resolveId(lessonId));
    if (!canManageGroup(lesson.groupId))
      throw StateError('Darsni o‘zgartirishga ruxsat yo‘q.');
    if (!['planned', 'completed', 'cancelled'].contains(status))
      throw ArgumentError('Noto‘g‘ri holat.');
    await _mutate<void>(
      apply: () {
        final index = lessons.indexWhere((l) => l.id == resolveId(lessonId));
        if (index < 0) throw StateError('Dars saqlanmadi.');
        lessons[index] = lessons[index].withStatus(status);
      },
      send: () async {
        await client!
            .from('lessons')
            .update({'status': status})
            .eq('id', _serverId(lessonId))
            .select('id')
            .single();
      },
    );
  }

  Future<void> setEnrollmentCompleted(
    String studentId,
    String groupId,
    bool completed,
  ) async {
    if (!canManageGroup(groupId))
      throw StateError('Guruhni boshqarishga ruxsat yo‘q.');
    studentById(studentId, groupId);
    await _mutate<void>(
      apply: () {
        final index = students.indexWhere(
          (s) => s.id == studentId && s.groupId == resolveId(groupId),
        );
        if (index < 0) throw StateError('O‘quvchi guruhga biriktirilmagan.');
        students[index] = students[index].copyWith(
          completed: completed,
          left: false,
        );
      },
      send: () async {
        await client!.rpc(
          'set_enrollment_completed',
          params: {
            'p_enrollment_id': _serverId(
              studentById(studentId, groupId).enrollmentId,
            ),
            'p_completed': completed,
          },
        );
      },
    );
  }
}
