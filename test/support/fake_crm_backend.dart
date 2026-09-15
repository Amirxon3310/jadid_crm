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
    authOptions: const AuthClientOptions(autoRefreshToken: false),
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
    if (path.contains('/auth/')) {
      if (path.endsWith('/logout')) return http.Response('', 204);
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
    if (path.endsWith('/rpc/group_rankings')) return json(<String, dynamic>{});
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
      return json(tables[path.split('/').last]!);
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
