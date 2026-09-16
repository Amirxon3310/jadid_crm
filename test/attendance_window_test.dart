import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadid_crm/core/app_theme.dart';
import 'package:jadid_crm/core/remembered_logins.dart';
import 'package:jadid_crm/data/crm_store.dart';
import 'support/fake_crm_backend.dart';
import 'package:jadid_crm/core/helpers.dart';
import 'package:jadid_crm/data/models.dart';
import 'package:jadid_crm/features/teacher_checkins_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('attendance opens ten minutes early and shuts at the bell', () {
    final store = CrmStore();
    addTearDown(store.dispose);
    expect(attendanceLeadMinutes, 10);
    final group = store.groups.first.copyWith(
      lessonStartTime: '10:00',
      lessonEndTime: '11:00',
      weekDays: const [],
    );
    // The centre's clock runs five hours ahead of UTC.
    bool openAt(int hourUtc, int minuteUtc) => store.isScheduledNow(
      group,
      now: DateTime.utc(2026, 9, 16, hourUtc, minuteUtc),
    );

    expect(openAt(4, 49), isFalse, reason: '09:49 — eleven minutes early');
    expect(openAt(4, 50), isTrue, reason: '09:50 — ten minutes early');
    expect(openAt(5, 30), isTrue, reason: 'mid-lesson');
    expect(openAt(6, 0), isTrue, reason: '11:00 — the bell');
    expect(openAt(6, 1), isFalse, reason: '11:01 — over');
  });

  test(
    'the device remembers who has signed in, and never their password',
    () async {
      SharedPreferences.setMockInitialValues({});
      expect(await RememberedLogins.load(), isEmpty);

      await RememberedLogins.remember('ali_karimov');
      await RememberedLogins.remember('zuhra');
      await RememberedLogins.remember('ALI_KARIMOV');
      // Most recent first, and the same account only once.
      expect(await RememberedLogins.load(), ['ALI_KARIMOV', 'zuhra']);

      for (var i = 0; i < RememberedLogins.limit + 3; i++) {
        await RememberedLogins.remember('user$i');
      }
      expect((await RememberedLogins.load()).length, RememberedLogins.limit);

      await RememberedLogins.forget('user7');
      expect(await RememberedLogins.load(), isNot(contains('user7')));

      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        expect(
          prefs.get(key).toString().toLowerCase(),
          isNot(contains('parol')),
        );
      }
    },
  );

  testWidgets('an admin sees which teacher arrived, when, and how late', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1500, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final store = CrmStore()..changeRole(AppRole.admin);
    addTearDown(store.dispose);
    final start = DateTime.now().subtract(const Duration(hours: 2));
    store.lessons
      ..clear()
      ..add(
        Lesson(
          id: 'l1',
          groupId: 'g1',
          topic: 'Sanoq tizimlari',
          startsAt: start,
        ),
      );
    store.checkins
      ..clear()
      ..add(
        LessonCheckin(
          lessonId: 'l1',
          teacherId: 'teacher-1',
          photoPath: 'teacher-1/l1/1.png',
          checkedAt: start.add(const Duration(minutes: 7)),
        ),
      );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: SingleChildScrollView(child: TeacherCheckinsPage(store: store)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Qo‘zivoy Karimov'), findsOneWidget);
    expect(find.text('Sanoq tizimlari'), findsOneWidget);
    expect(find.text('7 daqiqa kech'), findsOneWidget);
    expect(find.text('Xadra Kids N34'), findsOneWidget);
  });

  test('a check-in is read on the centre\'s clock, not UTC', () async {
    final backend = FakeCrmBackend();
    backend.tables['lesson_checkins']!.add({
      'id': 7,
      'organization_id': 'org',
      'lesson_id': 3,
      'teacher_membership_id': 2,
      'photo_path': 'teacher/3/1.png',
      // 04:07 UTC is 09:07 in Tashkent.
      'checked_at': '2026-09-16T04:07:00Z',
    });
    await backend.signIn();
    final store = CrmStore.online(backend.client, enableLiveUpdates: false);
    addTearDown(store.dispose);
    await store.load();

    final checkin = store.checkins.single;
    expect(shortTime(tashkentDate(checkin.checkedAt)), '09:07');
    // The instant itself is untouched, so lateness stays right.
    expect(checkin.checkedAt.toUtc(), DateTime.utc(2026, 9, 16, 4, 7));
  });
}
