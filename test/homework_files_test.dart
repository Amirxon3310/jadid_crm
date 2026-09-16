import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadid_crm/core/app_theme.dart';
import 'package:jadid_crm/data/crm_store.dart';
import 'package:jadid_crm/data/models.dart';
import 'package:jadid_crm/features/group_page.dart';

import 'support/fake_crm_backend.dart';

void main() {
  test('editing a homework replaces its file, old one and all', () async {
    final backend = FakeCrmBackend();
    backend.tables['assignments']!.add({
      'id': 40,
      'organization_id': 'org',
      'group_id': 10,
      'title': 'Eski vazifa',
      'description': '',
      'due_at': '2026-09-20T18:59:00Z',
      'created_at': '2026-09-13T12:00:00Z',
      'lesson_id': null,
      'files': [
        {'path': 'org/10/tasks/old.png', 'name': 'old.png'},
      ],
    });
    await backend.signIn();
    final store = CrmStore.online(backend.client, enableLiveUpdates: false);
    addTearDown(store.dispose);
    await store.load();
    store.activeRole = AppRole.admin;
    final old = store.homeworks.single.files.single;
    expect(old.name, 'old.png');

    await store.updateHomework(
      '40',
      title: 'Yangilangan vazifa',
      dueDate: DateTime.now().add(const Duration(days: 3)),
      addedFiles: [PickedFile('new.pdf', Uint8List(4))],
      removedFiles: [old],
    );

    // The row carries the new file only.
    final patch = backend.calls.lastWhere((call) => call.method == 'PATCH');
    final files = (jsonDecode(patch.body) as Map)['files'] as List;
    expect(files, hasLength(1));
    expect(files.single['name'], 'new.pdf');
    expect(store.homeworks.single.files.single.name, 'new.pdf');
    expect(store.homeworks.single.title, 'Yangilangan vazifa');

    // The replaced file is taken out of the bucket, once the row is saved.
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final removals = backend.calls.where(
      (call) =>
          call.method == 'DELETE' && call.url.path.contains('homework-files'),
    );
    expect(removals, isNotEmpty);
    expect(removals.last.body, contains('old.png'));
  });

  testWidgets('the journal reads as shares, not counts', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1500, 1400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final store = CrmStore()..changeRole(AppRole.teacher);
    addTearDown(store.dispose);
    final pupil = store.studentsOf('g1').first;
    final day = DateTime.now().subtract(const Duration(days: 5));
    store.lessons
      ..clear()
      ..addAll([
        for (var i = 0; i < 5; i++)
          Lesson(
            id: 'l$i',
            groupId: 'g1',
            topic: 'Dars $i',
            startsAt: day.add(Duration(days: i)),
          ),
      ]);
    store.attendance.clear();
    // Four of five lessons attended: 80%, the first shade of green.
    for (var i = 0; i < 4; i++) {
      store.attendance['l$i'] = {pupil.id: AttendanceStatus.present};
    }
    store.attendance['l4'] = {pupil.id: AttendanceStatus.absent};

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: GroupPage(store: store, group: store.groups.first, startTab: 3),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('80%'), findsOneWidget);
    // The counts are gone, and so is the column the number used to sit in.
    expect(find.text('4 / 5 (80 %)'), findsNothing);
    expect(find.text('#'), findsNothing);
  });
}
