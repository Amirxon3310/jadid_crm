import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadid_crm/app_router.dart';
import 'package:jadid_crm/core/app_theme.dart';
import 'package:jadid_crm/data/crm_store.dart';
import 'package:jadid_crm/data/models.dart';
import 'package:jadid_crm/features/profile_page.dart';
import 'support/fake_crm_backend.dart';

void main() {
  testWidgets(
    'sidebar has no overflow on intermediate or reversed animation frames',
    (tester) async {
      final store = CrmStore()..changeRole(AppRole.admin);
      addTearDown(store.dispose);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final width in [1000.0, 1536.0]) {
        tester.view.physicalSize = Size(width, 1092);
        await tester.pumpWidget(
          MaterialApp.router(
            theme: buildTheme(),
            routerConfig: buildRouter(store),
          ),
        );
        await tester.pumpAndSettle();
        for (var i = 0; i < 4; i++) {
          await tester.tap(find.byKey(const ValueKey('sidebar-toggle')));
          for (var frame = 0; frame < (i == 2 ? 4 : 14); frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            final sidebar = tester.getRect(
              find.byKey(const ValueKey('sidebar-navigation')),
            );
            final toggle = tester.getRect(
              find.byKey(const ValueKey('sidebar-toggle')),
            );
            expect(
              toggle.center.dx,
              closeTo(
                sidebar.width < 210
                    ? sidebar.center.dx
                    : sidebar.right - 26 - toggle.width / 2,
                1,
              ),
            );
            expect(
              tester.takeException(),
              isNull,
              reason: 'width $width, toggle $i, frame $frame',
            );
          }
        }
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
  testWidgets(
    'account menu opens own profile and admin can select another user',
    (tester) async {
      final store = CrmStore()..changeRole(AppRole.admin);
      addTearDown(store.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1536, 1092);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: buildTheme(),
          routerConfig: buildRouter(store),
        ),
      );
      await tester.tap(find.byTooltip('Profil va sozlamalar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Mening profilim'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfilePage), findsOneWidget);
      expect(find.text('Rasm yuklash'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).first).enabled,
        isTrue,
      );
      await tester.tap(find.byTooltip('Profil va sozlamalar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Foydalanuvchilar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ali Karimov'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ProfilePage>(find.byType(ProfilePage)).userId,
        'student-1',
      );
      expect(find.text('O‘qish holati'), findsOneWidget);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('student fields are locked for teacher except study status', (
    tester,
  ) async {
    final store = CrmStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfilePage(store: store, userId: 'student-1'),
          ),
        ),
      ),
    );
    for (final field in tester.widgetList<TextFormField>(
      find.byType(TextFormField),
    )) {
      expect(field.enabled, isFalse);
    }
    final dropdowns = tester.widgetList<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    expect(dropdowns.last.onChanged, isNotNull);
    expect(
      tester
          .widget<DropdownButtonFormField<AppRole>>(
            find.byType(DropdownButtonFormField<AppRole>),
          )
          .onChanged,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
  });
  for (final keepDraft in [false, true]) {
    testWidgets(
      'rejected profile save rolls back; keep newer draft: $keepDraft',
      (tester) async {
        final backend = FakeCrmBackend();
        late CrmStore store;
        await tester.runAsync(() async {
          await backend.signIn();
          store = CrmStore.online(backend.client, enableLiveUpdates: false);
          await store.load();
        });
        addTearDown(store.dispose);
        addTearDown(backend.client.dispose);
        backend.writeGate = Completer<void>();
        backend.failWrites = true;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1536, 1092);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ProfilePage(store: store, userId: 'admin'),
              ),
            ),
          ),
        );
        final field = find.byType(TextFormField).first;
        await tester.enterText(field, 'Rejected');
        await tester.pump();
        await tester.tap(find.text('O‘zgarishlarni saqlash'));
        await tester.pump();
        expect(store.activeUser.displayFirstName, 'Rejected');
        expect(find.byType(CircularProgressIndicator), findsNothing);
        if (keepDraft) {
          await tester.enterText(field, 'Unsaved');
          await tester.pump();
        }
        backend.writeGate!.complete();
        await tester.pumpAndSettle();
        expect(store.activeUser.displayFirstName, 'Admin');
        expect(
          tester.widget<TextFormField>(field).controller!.text,
          keepDraft ? 'Unsaved' : 'Admin',
        );
        expect(
          find.text('Profil saqlanmadi. Oldingi holat tiklandi.'),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'profile save keeps fields usable and reports confirmation after completion',
    (tester) async {
      final store = _PendingStore()..changeRole(AppRole.admin);
      addTearDown(store.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1536, 1092);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProfilePage(store: store, userId: 'admin-1'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('O‘zgarishlarni saqlash'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).first).enabled,
        isTrue,
      );
      expect(find.text('Profil saqlandi.'), findsNothing);
      await tester.tap(find.text('O‘zgarishlarni saqlash'));
      expect(store.calls, 1);
      store.pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Profil saqlandi.'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Profil saqlandi.')).dy,
        lessThan(150),
      );
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpWidget(const SizedBox());
    },
  );
}

class _PendingStore extends CrmStore {
  final pending = Completer<void>();
  int calls = 0;
  @override
  Future<void> saveProfile(
    AppUser user,
    Map<String, dynamic> fields, {
    String? outcome,
    AppRole? role,
    Uint8List? avatarBytes,
    bool removeAvatar = false,
  }) {
    calls++;
    return pending.future;
  }
}
