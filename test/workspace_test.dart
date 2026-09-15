import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadid_crm/core/helpers.dart';
import 'package:jadid_crm/data/crm_store.dart';
import 'package:jadid_crm/data/models.dart';
import 'package:jadid_crm/features/workspace.dart';

void main() {
  testWidgets('workspace listens to replacement store', (tester) async {
    final oldStore = _ObservableStore();
    final newStore = _ObservableStore();
    await tester.pumpWidget(MaterialApp(home: Workspace(store: oldStore)));
    await tester.pumpWidget(MaterialApp(home: Workspace(store: newStore)));
    expect(oldStore.listening, isFalse);
    expect(newStore.listening, isTrue);
    newStore.changeRole(AppRole.student);
    await tester.pump();
    expect(
      find.text('Dars jadvali, davomat va uy vazifalaringizni kuzating.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    expect(newStore.listening, isFalse);
    oldStore.dispose();
    newStore.dispose();
  });

  testWidgets('success message waits for server and errors are displayed', (
    tester,
  ) async {
    final pending = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => runCrmAction(
                  context,
                  () => pending.future,
                  success: 'Saqlandi',
                ),
                child: const Text('Save'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Saqlandi'), findsNothing);
    pending.completeError(StateError('Offline'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Saqlandi'), findsNothing);
    expect(find.textContaining('Amal bajarilmadi.'), findsOneWidget);
    expect(
      tester.getTopLeft(find.textContaining('Amal bajarilmadi.')).dy,
      lessThan(150),
    );
    await tester.pump(const Duration(seconds: 6));
    expect(find.textContaining('Amal bajarilmadi.'), findsNothing);
  });
}

class _ObservableStore extends CrmStore {
  bool get listening => hasListeners;
}
