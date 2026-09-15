import 'package:flutter_test/flutter_test.dart';
import 'package:jadid_crm/data/crm_store.dart';
import 'package:jadid_crm/data/models.dart';

void main() {
  test('har bir rol faqat ruxsatli guruhlarni ko‘radi', () {
    final store = CrmStore();

    expect(store.visibleGroups.length, 2);

    store.changeRole(AppRole.admin);
    expect(store.visibleGroups.length, 3);

    store.changeRole(AppRole.student);
    expect(store.visibleGroups.length, 1);
    expect(store.visibleGroups.single.id, 'g1');
  });

  test('davomat saqlanadi', () async {
    final store = CrmStore();
    await store.saveAttendance('l1', {'student-1': AttendanceStatus.present});

    expect(store.attendance['l1']?['student-1'], AttendanceStatus.present);
  });

  test('o‘quvchi vazifa yuboradi, ustoz tekshiradi', () async {
    final store = CrmStore();

    await store.submitHomework('h1', 'student-1', 'Tayyor javob');
    expect(store.resultFor('h1', 'student-1').status, HomeworkStatus.submitted);

    await store.reviewHomework(
      homeworkId: 'h1',
      studentId: 'student-1',
      accepted: true,
      score: 5,
      comment: 'Yaxshi',
    );
    expect(store.resultFor('h1', 'student-1').status, HomeworkStatus.accepted);
    expect(store.resultFor('h1', 'student-1').score, 5);
  });

  test('qaytarilgan vazifa qayta yuborilganda eski baho tozalanadi', () async {
    final store = CrmStore();
    await store.reviewHomework(
      homeworkId: 'h1',
      studentId: 'student-1',
      accepted: false,
      score: 2,
      comment: 'Qayta bajaring',
    );
    await store.submitHomework('h1', 'student-1', 'Yangi javob');
    final result = store.resultFor('h1', 'student-1');
    expect(result.status, HomeworkStatus.submitted);
    expect(result.score, isNull);
    expect(result.comment, isEmpty);
  });

  test('biriktirish o‘quvchi va guruh bo‘yicha tanlanadi', () async {
    final store = CrmStore();
    store.students.add(
      const Student(
        id: 'student-1',
        name: 'Ali',
        groupId: 'g2',
        phone: '',
        enrollmentId: 'second',
      ),
    );
    expect(store.studentById('student-1', 'g2').enrollmentId, 'second');
    expect(store.studentById('student-1', 'g1').groupId, 'g1');
    await store.saveAttendance('l2', {'student-1': AttendanceStatus.late});
    expect(store.attendance['l2']?['student-1'], AttendanceStatus.late);
  });

  test('boshqa guruh o‘quvchisiga davomat yozilmaydi', () async {
    final store = CrmStore();
    await expectLater(
      store.saveAttendance('l1', {'student-5': AttendanceStatus.present}),
      throwsStateError,
    );
    expect(store.attendance.containsKey('l1'), isFalse);
  });

  test('qabul qilingan javob qayta yozilmaydi', () async {
    final store = CrmStore();
    await store.reviewHomework(
      homeworkId: 'h1',
      studentId: 'student-1',
      accepted: true,
      score: 5,
      comment: 'Yaxshi',
    );
    await expectLater(
      store.submitHomework('h1', 'student-1', 'Boshqa javob'),
      throwsStateError,
    );
    expect(store.resultFor('h1', 'student-1').status, HomeworkStatus.accepted);
  });
}
