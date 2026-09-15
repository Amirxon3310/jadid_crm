import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadid_crm/core/app_theme.dart';
import 'package:jadid_crm/data/crm_store.dart';
import 'package:jadid_crm/data/models.dart';
import 'package:jadid_crm/features/workspace.dart';
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
          child: MaterialApp(
            theme: buildTheme(),
            home: Workspace(store: store),
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
      for (final label in [
        'Davomat',
        'Uy vazifalari',
        'Jurnal',
        'Reyting',
      ]) {
        final tab = find.widgetWithText(TextButton, label);
        await tester.ensureVisible(tab);
        await tester.tap(tab);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
        if (label == 'Davomat') {
          expect(find.text('Suratga tushish'), findsOneWidget);
          final switcher = tester
              .widgetList<Switch>(find.byType(Switch))
              .first;
          expect(switcher.onChanged, isNull);
        }
        if (label == 'Uy vazifalari') {
          await tester.tap(find.text('Vazifa berish'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.widgetWithText(TextField, 'Vazifa (nima qilish kerak)'),
            'New linked task',
          );
          await tester.tap(find.text('Berish'));
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
      MaterialApp(
        theme: buildTheme(),
        home: Workspace(store: store),
      ),
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
