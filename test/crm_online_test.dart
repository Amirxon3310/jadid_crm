import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jadid_crm/data/crm_store.dart';
import 'package:jadid_crm/data/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late CrmStore store;
  late List<http.Request> writes;
  late bool failWrites;

  setUp(() async {
    writes = [];
    failWrites = false;
    client = SupabaseClient(
      'https://example.test',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/auth/')) {
          return http.Response(
            jsonEncode({
              'access_token': 'test-token',
              'refresh_token': 'refresh-token',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': 'user-1',
                'aud': 'authenticated',
                'app_metadata': <String, dynamic>{},
                'user_metadata': <String, dynamic>{},
                'created_at': '2026-01-01T00:00:00Z',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        writes.add(request);
        return http.Response(
          failWrites ? '{"message":"Denied","code":"42501"}' : '{"id":1}',
          failWrites ? 403 : 200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    await client.auth.signInWithPassword(
      email: 'user@example.test',
      password: 'test',
    );
    store = CrmStore.online(client, enableLiveUpdates: false);
    store.users.add(
      const AppUser(
        id: 'user-1',
        name: 'User',
        role: AppRole.teacher,
        membershipId: '1',
        organizationId: 'org',
      ),
    );
    store.groups.add(
      const StudyGroup(
        id: '2',
        name: 'Second',
        course: 'Course',
        teacherId: 'user-1',
        teacherName: 'User',
        schedule: '',
        room: '',
        organizationId: 'org',
      ),
    );
    store.students.addAll([
      const Student(
        id: 'student',
        name: 'Student',
        groupId: '1',
        phone: '',
        enrollmentId: '10',
      ),
      const Student(
        id: 'student',
        name: 'Student',
        groupId: '2',
        phone: '',
        enrollmentId: '20',
      ),
    ]);
    store.lessons.add(
      Lesson(id: '3', groupId: '2', topic: 'Topic', startsAt: DateTime.now()),
    );
    store.checkins.add(
      LessonCheckin(
        lessonId: '3',
        teacherId: 'user-1',
        photoPath: 'test.jpg',
        checkedAt: DateTime.now(),
      ),
    );
    store.homeworks.add(
      Homework(
        id: '4',
        groupId: '2',
        title: 'Task',
        description: '',
        dueDate: DateTime(2026),
      ),
    );
  });

  tearDown(() async {
    store.dispose();
    await client.dispose();
  });

  test(
    'online writes use enrollment of the lesson and assignment group',
    () async {
      await store.saveAttendance('3', {'student': AttendanceStatus.present});
      expect(
        (jsonDecode(writes.last.body) as List).single['enrollment_id'],
        20,
      );
      await store.submitHomework('4', 'student', 'Answer');
      final payload = jsonDecode(writes.last.body) as Map;
      expect(payload['enrollment_id'], 20);
      for (final key in ['score', 'reviewed_by', 'reviewed_at']) {
        expect(payload.containsKey(key), isTrue);
        expect(payload[key], isNull);
      }
      await store.reviewHomework(
        homeworkId: '4',
        studentId: 'student',
        accepted: false,
        score: 2,
        comment: 'Retry',
      );
      expect(writes.last.url.queryParameters['enrollment_id'], 'eq.20');
    },
  );

  test('failed writes preserve attendance, answer and review state', () async {
    store.attendance['3'] = {'student': AttendanceStatus.late};
    final result = store.resultFor('4', 'student');
    result.answer = 'Old answer';
    result.status = HomeworkStatus.returned;
    result.score = 2;
    result.comment = 'Retry';
    failWrites = true;
    await expectLater(
      store.saveAttendance('3', {'student': AttendanceStatus.present}),
      throwsA(isA<PostgrestException>()),
    );
    expect(store.attendance['3']?['student'], AttendanceStatus.late);
    await expectLater(
      store.submitHomework('4', 'student', 'New answer'),
      throwsA(isA<PostgrestException>()),
    );
    expect(result.answer, 'Old answer');
    expect(result.status, HomeworkStatus.returned);
    expect(result.score, 2);
    await expectLater(
      store.reviewHomework(
        homeworkId: '4',
        studentId: 'student',
        accepted: true,
        score: 5,
        comment: 'OK',
      ),
      throwsA(isA<PostgrestException>()),
    );
    expect(result.status, HomeworkStatus.returned);
    expect(result.comment, 'Retry');
  });
}
