import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeCrmBackend {
  final calls = <http.Request>[];
  bool failWrites = false;
  String authId = 'admin';
  int writeNumber = 0;
  final failWriteNumbers = <int>{};

  /// What Auth answers instead of a session, verbatim as Supabase words it.
  String? authError;

  /// Sign-in and sign-up requests, kept apart from the data calls.
  final authCalls = <http.Request>[];

  /// Functions that answer with an error, by name and status.
  final rpcErrors = <String, int>{};

  /// What group_classmates answers with.
  List<Map<String, dynamic>> classmates = const [];

  /// What member_login answers with.
  String? memberLogin = 'ali_karimov';

  /// Edge function invocations, and the ones this project has deployed.
  final functionCalls = <http.Request>[];
  final deployedFunctions = <String>{};

  /// Columns, per table, a database predating their migration would not
  /// have yet. Selecting one by name fails the way PostgREST does.
  final missingColumns = <String, Set<String>>{};

  /// Tables whose delete policy a database predating it would not have.
  final deleteBlocked = <String>{};

  /// Functions a database predating their migration would not have yet.
  final missingFunctions = <String>{};

  /// Memberships delete_member was asked to remove.
  final deletedMembers = <int>[];

  /// Tables a database predating their migration would not have yet.
  final missingTables = <String>{};
  Completer<void>? writeGate;
  Completer<void>? readGate;
  int nextId = 100;
  final tables = <String, List<Map<String, dynamic>>>{
    'lesson_checkins': [],
    'branches': [],
    'payments': [],
    'profiles': [
      {
        'id': 'admin',
        'full_name': 'Admin Test',
        'first_name': 'Admin',
        'last_name': 'Test',
      },
      {
        'id': 'teacher',
        'full_name': 'Teacher Test',
        'first_name': 'Teacher',
        'last_name': 'Test',
        'phone': '111',
      },
      {
        'id': 'student',
        'full_name': 'Student Test',
        'first_name': 'Student',
        'last_name': 'Test',
        'phone': '222',
      },
    ],
    'memberships': [
      {
        'id': 1,
        'profile_id': 'admin',
        'organization_id': 'org',
        'role': 'admin',
        'study_status': 'studying',
      },
      {
        'id': 2,
        'profile_id': 'teacher',
        'organization_id': 'org',
        'role': 'teacher',
        'study_status': 'studying',
      },
      {
        'id': 3,
        'profile_id': 'student',
        'organization_id': 'org',
        'role': 'student',
        'study_status': 'studying',
      },
    ],
    'groups': [
      {
        'id': 10,
        'organization_id': 'org',
        'name': 'Existing group',
        'course': 'Course',
        'teacher_membership_id': 2,
        'schedule_text': 'Mon',
        'room': '1',
      },
    ],
    'enrollments': [
      {'id': 20, 'group_id': 10, 'student_membership_id': 3},
    ],
    'lessons': [],
    'assignments': [],
    'attendance': [],
    'assignment_results': [],
    'score_awards': [],
  };
  late final client = SupabaseClient(
    'https://example.test',
    'test-key',
    authOptions: const AuthClientOptions(
      authFlowType: AuthFlowType.implicit,
      autoRefreshToken: false,
    ),
    httpClient: MockClient(_handle),
  );

  Future<void> signIn() => client.auth
      .signInWithPassword(email: 'test@example.test', password: 'test')
      .then((_) {});
  Future<http.Response> _handle(http.Request request) async {
    http.Response json(Object? data, {int status = 200}) => http.Response(
      jsonEncode(data),
      status,
      headers: {'content-type': 'application/json'},
      request: request,
    );
    final path = request.url.path;
    // No edge function is deployed here, which is what most projects look
    // like: the app must fall back rather than fail.
    if (path.contains('/functions/v1/')) {
      functionCalls.add(request);
      if (!deployedFunctions.contains(path.split('/').last)) {
        return json({'error': 'Function not found'}, status: 404);
      }
      return json({'ok': true});
    }
    if (path.contains('/auth/')) {
      authCalls.add(request);
      if (path.endsWith('/logout')) return http.Response('', 204);
      if (authError != null)
        return json({'message': authError, 'code': 422}, status: 422);
      return json({
        'access_token': 'test-token',
        'refresh_token': 'refresh-token',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': authId,
          'aud': 'authenticated',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-01-01T00:00:00Z',
        },
      });
    }
    calls.add(request);
    for (final entry in rpcErrors.entries) {
      if (path.endsWith('/rpc/${entry.key}')) {
        return json({
          'message': 'Denied',
          'code': '42501',
        }, status: entry.value);
      }
    }
    if (path.endsWith('/rpc/group_rankings')) return json(<String, dynamic>{});
    if (path.endsWith('/rpc/group_classmates')) return json(classmates);
    if (path.endsWith('/rpc/member_login')) return json(memberLogin);
    if (path.endsWith('/rpc/student_rankings'))
      return json({
        'coins': 0,
        'center_rank': 1,
        'groups': {'10': 1},
      });
    if (path.endsWith('/rpc/dashboard_metrics'))
      return json({
        'current': {
          'employees': 2,
          'students': 1,
          'graduates': 0,
          'success_rate': 0,
        },
        'previous': {
          'employees': 1,
          'students': 2,
          'graduates': 0,
          'success_rate': 0,
        },
      });
    if (request.method == 'GET') {
      await readGate?.future;
      final table = path.split('/').last;
      final select = request.url.queryParameters['select'] ?? '*';
      for (final column in missingColumns[table] ?? const <String>{}) {
        if (select.split(',').contains(column))
          return json({
            'code': '42703',
            'message': 'column $table.$column does not exist',
          }, status: 400);
      }
      if (missingTables.contains(table))
        return json({
          'code': 'PGRST205',
          'message':
              "Could not find the table 'public.$table' in the schema cache",
        }, status: 404);
      return json(tables[table]!);
    }
    final reject = failWriteNumbers.contains(++writeNumber) || failWrites;
    await writeGate?.future;
    if (reject && request.method != 'DELETE')
      return json({'message': 'Denied', 'code': '42501'}, status: 403);
    if (path.contains('/storage/')) {
      return json(
        request.method == 'DELETE' ? [] : {'Key': path.split('/object/').last},
      );
    }
    if (request.method == 'DELETE') {
      final table = path.split('/').last;
      // A table without a delete policy: row security returns nothing.
      if (deleteBlocked.contains(table)) return json(<Object>[]);
      final filters = {
        for (final entry in request.url.queryParameters.entries)
          if (entry.value.startsWith('eq.'))
            entry.key: entry.value.substring(3),
      };
      final removed = tables[table]!
          .where(
            (row) => filters.entries.every((f) => '${row[f.key]}' == f.value),
          )
          .toList();
      tables[table]!.removeWhere(removed.contains);
      return json(removed);
    }
    final decoded = jsonDecode(request.body);
    if (decoded is List) {
      final rows = decoded
          .map(
            (r) => <String, dynamic>{
              ...Map<String, dynamic>.from(r as Map),
              'id': nextId++,
            },
          )
          .toList();
      tables[path.split('/').last]!.addAll(rows);
      return json(rows);
    }
    final payload = decoded as Map<String, dynamic>;
    if (path.endsWith('/rpc/check_in_lesson')) return json(null);
    if (path.endsWith('/rpc/set_enrollment_status')) {
      final row = tables['enrollments']!.firstWhere(
        (e) => e['id'] == payload['p_enrollment_id'],
      );
      row['study_status'] = payload['p_status'];
      row['ends_on'] = payload['p_status'] == 'active' ? null : '2026-09-15';
      return json(null);
    }
    if (path.endsWith('/rpc/set_enrollment_completed')) {
      tables['enrollments']!.firstWhere(
        (e) => e['id'] == payload['p_enrollment_id'],
      )['ends_on'] = payload['p_completed'] == true
          ? '2026-09-14'
          : null;
      return json(null);
    }
    if (path.endsWith('/rpc/delete_member')) {
      if (missingFunctions.contains('delete_member'))
        return json({
          'code': 'PGRST202',
          'message': 'Could not find the function public.delete_member',
        }, status: 404);
      final id = payload['p_membership_id'];
      deletedMembers.add(id as int);
      tables['memberships']!.removeWhere((m) => m['id'] == id);
      tables['enrollments']!.removeWhere(
        (e) => e['student_membership_id'] == id,
      );
      tables['groups']!
          .where((g) => g['teacher_membership_id'] == id)
          .forEach((g) => g['teacher_membership_id'] = null);
      return json(null);
    }
    if (path.endsWith('/rpc/save_profile')) {
      final member = tables['memberships']!.firstWhere(
        (m) => m['id'] == payload['p_membership_id'],
      );
      final profile = tables['profiles']!.firstWhere(
        (p) => p['id'] == member['profile_id'],
      );
      profile.addAll(Map<String, dynamic>.from(payload['p_profile']));
      if (payload['p_role'] != null) member['role'] = payload['p_role'];
      if (payload['p_outcome'] != null)
        member['study_status'] = payload['p_outcome'];
      return json(null);
    }
    final table = path.split('/').last;
    final row = <String, dynamic>{...payload, 'id': nextId++};
    if (table == 'enrollments') {
      final existing = tables[table]!
          .where(
            (r) =>
                r['group_id'] == row['group_id'] &&
                r['student_membership_id'] == row['student_membership_id'],
          )
          .firstOrNull;
      if (existing != null) {
        row['id'] = existing['id'];
        tables[table]!.remove(existing);
      }
    }
    tables[table]!.add(row);
    return json(row);
  }
}
