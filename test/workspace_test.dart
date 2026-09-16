import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadid_crm/app_router.dart';
import 'package:jadid_crm/core/helpers.dart';
import 'package:jadid_crm/data/crm_store.dart';
import 'package:jadid_crm/data/models.dart';

void main() {
  testWidgets('workspace listens to replacement store', (tester) async {
    final oldStore = _ObservableStore();
    final newStore = _ObservableStore();
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: buildRouter(oldStore)),
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: buildRouter(newStore)),
    );
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
    // An error from the network, with nothing readable to say.
    pending.completeError(Exception('socket closed'));
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

  testWidgets('an error the app wrote itself is shown as written', (
    tester,
  ) async {
    final pending = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => runCrmAction(context, () => pending.future),
              child: const Text('Save'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Save'));
    await tester.pump();
    pending.completeError(StateError('Guruh faol emas.'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // The generic advice would hide the one thing that explains the refusal.
    expect(find.text('Guruh faol emas.'), findsOneWidget);
    expect(find.textContaining('Amal bajarilmadi.'), findsNothing);
  });

  test('Dart\'s own lookup failures keep the general advice', () {
    expect(crmActionError(StateError('No element')), startsWith('Amal'));
    expect(crmActionError(Exception('x')), startsWith('Amal'));
    expect(crmActionError(ArgumentError('Login band.')), 'Login band.');
  });
}

class _ObservableStore extends CrmStore {
  bool get listening => hasListeners;
}
