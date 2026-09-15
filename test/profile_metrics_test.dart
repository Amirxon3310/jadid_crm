import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadid_crm/core/app_theme.dart';
import 'package:jadid_crm/data/crm_store.dart';
import 'package:jadid_crm/data/dashboard_metrics.dart';
import 'package:jadid_crm/data/models.dart';
import 'package:jadid_crm/features/dashboard_page.dart';

void main() {
  test(
    'monthly growth handles increases, decreases, zero and missing history',
    () {
      expect(const MetricValue(125, 100).growthLabel, '+25%');
      expect(const MetricValue(75, 100).growthLabel, '−25%');
      expect(const MetricValue(0, 10).growthLabel, '−100%');
      expect(const MetricValue(0, 0).growthLabel, '0%');
      expect(const MetricValue(5, 0).growthLabel, 'Yangi');
      expect(const MetricValue(5, null).growthLabel, '—');
      expect(const MetricValue(2, 3).growthLabel, '−33.3%');
    },
  );
  test('success denominator includes every student, not just graduates', () {
    final metrics = DashboardMetrics.fromUsers(const [
      AppUser(id: 'a', name: 'Admin', role: AppRole.admin),
      AppUser(id: 't', name: 'Teacher', role: AppRole.teacher),
      AppUser(
        id: 's1',
        name: 'Graduate',
        role: AppRole.student,
        studyStatus: 'graduated',
      ),
      AppUser(
        id: 's2',
        name: 'Unsuccessful',
        role: AppRole.student,
        studyStatus: 'unsuccessful',
      ),
      AppUser(id: 's3', name: 'Studying', role: AppRole.student),
      AppUser(id: 's4', name: 'Studying', role: AppRole.student),
    ]);
    expect(metrics.value('employees').current, 2);
    expect(metrics.value('students').current, 4);
    expect(metrics.value('graduates').current, 2);
    expect(metrics.value('success_rate').current, 25);
    expect(DashboardMetrics.fromUsers([]).value('success_rate').current, 0);
  });
  testWidgets('growth badges use green for increase and red for decrease', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              MetricGrowthBadge(metric: MetricValue(11, 10)),
              MetricGrowthBadge(metric: MetricValue(9, 10)),
            ],
          ),
        ),
      ),
    );
    expect(
      tester.widget<Text>(find.text('+10%')).style?.color,
      AppColors.success,
    );
    expect(
      tester.widget<Text>(find.text('−10%')).style?.color,
      AppColors.danger,
    );
  });
  test(
    'teachers can grade their students but cannot edit personal fields',
    () async {
      final store = CrmStore();
      addTearDown(store.dispose);
      final student = store.users.firstWhere((u) => u.id == 'student-1');
      await expectLater(
        store.saveProfile(student, {'first_name': 'Changed'}),
        throwsStateError,
      );
      await store.saveProfile(student, {}, outcome: 'graduated');
      expect(store.users.last.studyStatus, 'graduated');
      expect(store.users.last.graduatedAt, isNotNull);
      store.students.removeWhere((s) => s.id == student.id);
      await expectLater(
        store.saveProfile(store.users.last, {}, outcome: 'studying'),
        throwsStateError,
      );
    },
  );
  test(
    'students cannot edit personal fields, admins edit anyone and metrics refresh',
    () async {
      final store = CrmStore()..changeRole(AppRole.student);
      addTearDown(store.dispose);
      final student = store.activeUser;
      await expectLater(
        store.saveProfile(student, {
          'first_name': 'Updated',
          'last_name': 'Student',
        }),
        throwsStateError,
      );
      expect(store.activeUser, same(student));
      await expectLater(
        store.saveProfile(store.activeUser, {}, role: AppRole.admin),
        throwsStateError,
      );
      await expectLater(
        store.saveProfile(store.activeUser, {}, outcome: 'graduated'),
        throwsStateError,
      );
      store.changeRole(AppRole.admin);
      await store.saveProfile(store.users.last, {
        'phone': '998',
      }, outcome: 'graduated');
      expect(store.users.last.phone, '998');
      expect(store.dashboardMetrics.value('graduates').current, 1);
      expect(store.dashboardMetrics.value('success_rate').current, 100);
    },
  );
}
