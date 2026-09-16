import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadid_crm/app_router.dart';
import 'package:jadid_crm/core/app_theme.dart';
import 'package:jadid_crm/data/crm_store.dart';
import 'package:jadid_crm/data/models.dart';
import 'package:jadid_crm/features/group_page.dart';

void main() {
  testWidgets(
    'teacher dashboard, group tabs and homework form fit desktop and phone',
    (tester) async {
      final store = CrmStore();
      addTearDown(store.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 960);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final font in [
        ('SF Pro Display', 'assets/fonts/SF-Pro-Display-Regular.otf'),
        ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      ]) {
        await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
      }
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp.router(
            theme: buildTheme(),
            routerConfig: buildRouter(store),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final text in [
        'Jami guruhlar',
        'Jami o‘quvchilar',
        'Ketgan o‘quvchilar',
        'Bitirgan o‘quvchilar',
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      expect(find.text('Scratch S03'), findsNothing);
      await tester.runAsync(() async {
        for (final icon in ['dashboards_active', 'groups_noactive', 'menu']) {
          await precacheImage(
            AssetImage('assets/icons/$icon.png'),
            key.currentContext!,
          );
        }
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '/tmp/jadid-teacher-dashboard.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: GroupPage(store: store, group: store.groups.first),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final label in ['Davomat', 'Uy vazifalari', 'Jurnal', 'Reyting']) {
        final tab = find.widgetWithText(TextButton, label);
        await tester.ensureVisible(tab);
        await tester.tap(tab);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
        if (label == 'Davomat') {
          expect(find.text('Suratga tushish'), findsOneWidget);
          final switcher = tester.widgetList<Switch>(find.byType(Switch)).first;
          expect(switcher.onChanged, isNull);
        }
        if (label == 'Uy vazifalari') {
          await tester.tap(find.text('Uy vazifa qo‘shish'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.widgetWithText(TextField, 'Nima qilish kerak?'),
            'New linked task',
          );
          await tester.tap(find.widgetWithText(FilledButton, 'Qo‘shish'));
          await tester.pumpAndSettle();
          expect(store.homeworks.last.lessonId, isNotNull);
          expect(tester.takeException(), isNull);
        }
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('admin can create an unassigned group then open its editor', (
    tester,
  ) async {
    final store = CrmStore()..changeRole(AppRole.admin);
    addTearDown(store.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp.router(theme: buildTheme(), routerConfig: buildRouter(store)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guruhlar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guruh qo‘shish'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Guruh nomi'),
      'New group',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Kurs'),
      'Course',
    );
    await tester.tap(find.text('Du'));
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();
    expect(store.groups.last.teacherId, '');
    expect(store.groups.last.weekDays, [1]);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Guruhni tahrirlash').last);
    await tester.pumpAndSettle();
    expect(find.text('Guruhni tahrirlash'), findsOneWidget);
    await tester.tap(find.text('Bekor qilish'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('journal ranks pupils and reports shares, not counts', (
    tester,
  ) async {
    final store = CrmStore();
    addTearDown(store.dispose);
    store.users.addAll([
      const AppUser(
        id: 'student-2',
        name: 'Madina Salimova',
        role: AppRole.student,
      ),
      const AppUser(
        id: 'student-3',
        name: 'Aziz Rustamov',
        role: AppRole.student,
      ),
    ]);
    final lessons = store.lessonsOf('g1');
    expect(lessons.length, greaterThanOrEqualTo(2));
    // Deliberately the reverse of the pupils' natural order, so the ranking
    // has to do real work for the expectations below to hold.
    store.attendance
      ..clear()
      ..addAll({
        for (final lesson in lessons)
          lesson.id: {
            'student-3': AttendanceStatus.present,
            'student-1': AttendanceStatus.absent,
          },
      });
    // Only the first lesson for the middle pupil, so the ranking is decided.
    store.attendance[lessons.first.id]!['student-2'] = AttendanceStatus.late;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: GroupPage(store: store, group: store.groups.first, startTab: 3),
      ),
    );
    await tester.pumpAndSettle();

    // Whole history by default, each pupil's share as one figure.
    expect(find.text('Hammasi'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('0%'), findsWidgets);
    expect(
      find.text('${lessons.length} / ${lessons.length} (100 %)'),
      findsNothing,
    );

    // Best attendance on top, worst at the bottom.
    double yOf(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(yOf('Aziz Rustamov'), lessThan(yOf('Madina Salimova')));
    expect(yOf('Madina Salimova'), lessThan(yOf('Ali Karimov')));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('rating splits points and opens a pupil’s award history', (
    tester,
  ) async {
    final store = CrmStore()..changeRole(AppRole.admin);
    addTearDown(store.dispose);
    store.attendance.clear();
    store.results.clear();
    await store.saveAttendance(
      store.lessons.firstWhere((l) => l.groupId == 'g1').id,
      {'student-1': AttendanceStatus.present},
    );
    await store.addScoreAward(
      studentId: 'student-1',
      groupId: 'g1',
      amount: 7,
      note: 'Faol qatnashdi',
    );
    await store.addScoreAward(
      studentId: 'student-1',
      groupId: 'g1',
      amount: -3,
      note: 'Dafter olib kelmadi',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: GroupPage(store: store, group: store.groups.first, startTab: 4),
      ),
    );
    await tester.pumpAndSettle();

    // Homework, attendance, reward, penalty and total each get a column.
    for (final header in [
      'Uy vazifa',
      'Darsda qatnashish',
      'Rag‘bat',
      'Jarima',
      'Jami',
    ]) {
      expect(find.text(header), findsOneWidget);
    }
    expect(find.text('10'), findsOneWidget);
    expect(find.text('+7'), findsOneWidget);
    expect(find.text('-3'), findsOneWidget);
    expect(find.text('14 ball'), findsOneWidget);

    // Tapping the pupil shows who gave what, and why.
    await tester.tap(find.text('Ali Karimov'));
    await tester.pumpAndSettle();
    expect(find.text('Faol qatnashdi'), findsOneWidget);
    expect(find.text('Dafter olib kelmadi'), findsOneWidget);
    expect(find.textContaining(store.activeUser.name), findsWidgets);

    // A plain number rewards, from its own window.
    await tester.tap(find.widgetWithText(FilledButton, 'Ball qo‘shish'));
    await tester.pumpAndSettle();
    expect(find.text('Ali Karimov — ball qo‘shish'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Ball'), '5');
    await tester.pumpAndSettle();
    expect(find.text('rag‘bat'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Izoh'),
      'Uyga vazifani a’lo bajardi',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Saqlash'));
    await tester.pumpAndSettle();
    expect(store.bonusPointsOf('student-1'), 12);
    expect(find.text('Uyga vazifani a’lo bajardi'), findsOneWidget);

    // The same window fines when the number carries a minus.
    await tester.tap(find.widgetWithText(FilledButton, 'Ball qo‘shish'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Ball'), '-4');
    await tester.pumpAndSettle();
    expect(find.text('jarima'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Izoh'), 'Kechikdi');
    await tester.tap(find.widgetWithText(FilledButton, 'Saqlash'));
    await tester.pumpAndSettle();
    expect(store.penaltyPointsOf('student-1'), -7);
    expect(store.bonusPointsOf('student-1'), 12);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('every rating row carries its own give-points button', (
    tester,
  ) async {
    final store = CrmStore()..changeRole(AppRole.admin);
    addTearDown(store.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: GroupPage(store: store, group: store.groups.first, startTab: 4),
      ),
    );
    await tester.pumpAndSettle();

    // Reachable straight from the row, without opening the history first.
    final give = find.widgetWithIcon(IconButton, Icons.add_circle_rounded);
    expect(give, findsWidgets);
    await tester.tap(give.first);
    await tester.pumpAndSettle();
    expect(find.textContaining('ball qo‘shish'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Ball'), '-6');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Saqlash'));
    await tester.pumpAndSettle();
    expect(store.penaltyPointsOf('student-1'), -6);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the award history fits the widest penalty without overflow', (
    tester,
  ) async {
    final store = CrmStore()..changeRole(AppRole.admin);
    addTearDown(store.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    // The extremes the column allows, one of them with no reason given.
    await store.addScoreAward(
      studentId: 'student-1',
      groupId: 'g1',
      amount: -1000,
      note: '',
    );
    await store.addScoreAward(
      studentId: 'student-1',
      groupId: 'g1',
      amount: 1000,
      note: 'Juda uzun izoh: viloyat olimpiadasida birinchi o‘rin',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: GroupPage(store: store, group: store.groups.first, startTab: 4),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ali Karimov'));
    await tester.pumpAndSettle();

    Finder inDialog(String text) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text(text),
    );
    expect(inDialog('-1000'), findsOneWidget);
    expect(inDialog('+1000'), findsOneWidget);

    // The reason leads the row, in bold, or says there wasn't one.
    final reason = tester.widget<Text>(
      inDialog('Juda uzun izoh: viloyat olimpiadasida birinchi o‘rin'),
    );
    expect(reason.style?.fontWeight, FontWeight.w700);
    expect(inDialog('Izohsiz'), findsOneWidget);

    // Under it: who gave it and what they are, then the centre's clock.
    final now = tashkentDate(DateTime.now());
    const months = [
      'yanvar',
      'fevral',
      'mart',
      'aprel',
      'may',
      'iyun',
      'iyul',
      'avgust',
      'sentabr',
      'oktabr',
      'noyabr',
      'dekabr',
    ];
    final byLine = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.textContaining('${store.activeUser.name} • Admin'),
    );
    expect(byLine, findsWidgets);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('${now.day}-${months[now.month - 1]} '),
      ),
      findsWidgets,
    );
    // A RenderFlex overflow would surface here.
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a temporary team sums its pupils and takes their place', (
    tester,
  ) async {
    final store = CrmStore()..changeRole(AppRole.admin);
    addTearDown(store.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    store.users.addAll([
      const AppUser(
        id: 'student-2',
        name: 'Madina Salimova',
        role: AppRole.student,
      ),
      const AppUser(
        id: 'student-3',
        name: 'Aziz Rustamov',
        role: AppRole.student,
      ),
    ]);
    store.attendance.clear();
    store.results.clear();
    // 35 / 20 / 10, so the pair behind still falls short of the leader.
    for (final (id, amount) in [
      ('student-1', 35),
      ('student-2', 20),
      ('student-3', 10),
    ]) {
      await store.addScoreAward(
        studentId: id,
        groupId: 'g1',
        amount: amount,
        note: 'boshlang‘ich',
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: GroupPage(store: store, group: store.groups.first, startTab: 4),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('35 ball'), findsOneWidget);

    await tester.tap(find.text('Jamoa tuzish'));
    await tester.pumpAndSettle();
    expect(find.textContaining('kamida ikki'), findsOneWidget);

    // The two behind the leader, together, edge past them.
    await tester.tap(find.text('Madina Salimova'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aziz Rustamov'));
    await tester.pumpAndSettle();
    expect(find.text('Madina Salimova + Aziz Rustamov'), findsOneWidget);
    expect(find.text('30'), findsOneWidget); // 20 + 10, the team's own score
    expect(find.textContaining('birinchi o‘rinni'), findsNothing);
    expect(find.textContaining('2-o‘rinda'), findsOneWidget);

    // Each figure is read from the chip carrying its own label.
    Color statColor(String label) {
      final chip = find
          .ancestor(of: find.text(label), matching: find.byType(Row))
          .first;
      return tester
          .widget<Text>(
            find.descendant(of: chip, matching: find.byType(Text)).first,
          )
          .style!
          .color!;
    }

    // Last of the two places on offer, so the rank reads red; the member
    // count is always primary.
    expect(statColor('O‘rin'), AppColors.penaltyRed);
    expect(statColor('A’zolar'), AppColors.primary);

    // Adding the leader puts the team clear of everyone left.
    await tester.tap(find.text('Ali Karimov'));
    await tester.pumpAndSettle();
    expect(find.text('65'), findsOneWidget);
    expect(find.textContaining('birinchi o‘rinni'), findsOneWidget);
    expect(statColor('O‘rin'), AppColors.rewardGreen);

    // It is a what-if only: nobody's own score moved.
    expect(store.pointsOf('student-1'), 35);
    expect(store.pointsOf('student-2'), 20);
    expect(store.pointsOf('student-3'), 10);

    await tester.tap(find.text('Tozalash'));
    await tester.pumpAndSettle();
    expect(find.textContaining('kamida ikki'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('attendance stays shut for a teacher off the group schedule', (
    tester,
  ) async {
    final store = CrmStore();
    addTearDown(store.dispose);
    final group = store.groups.first;
    // No lesson today, and a weekday this group never meets, so the teacher
    // must be told why rather than being offered the start-lesson form.
    store.lessons.removeWhere((lesson) => lesson.groupId == group.id);
    store.groups[0] = group.copyWith(
      weekDays: [tashkentDate(DateTime.now()).weekday % 7 + 1],
      lessonStartTime: '15:30',
      lessonEndTime: '17:00',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: GroupPage(store: store, group: store.groups.first, startTab: 1),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('dars kuni emas'), findsOneWidget);
    expect(find.text('Darsni boshlash'), findsNothing);

    // A window tight around the current Tashkent minute lets the teacher in —
    // and only lines up if the window is read in Tashkent time, so a stray
    // extra conversion anywhere on this path fails the expectation below.
    final now = tashkentDate(DateTime.now());
    String hhmm(DateTime value) =>
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
    store.groups[0] = store.groups.first.copyWith(
      weekDays: [now.weekday],
      lessonStartTime: hhmm(now.subtract(const Duration(minutes: 2))),
      lessonEndTime: hhmm(now.add(const Duration(minutes: 2))),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: GroupPage(store: store, group: store.groups.first, startTab: 1),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Darsni boshlash'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
