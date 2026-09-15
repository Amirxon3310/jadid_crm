enum AppRole { admin, teacher, student }

enum AttendanceStatus { present, late, absent }

enum HomeworkStatus { waiting, submitted, accepted, returned }

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.role,
    this.membershipId = '',
    this.organizationId = '',
    this.phone = '',
    this.createdAt,
    this.firstName = '',
    this.lastName = '',
    this.age,
    this.gender,
    this.branch = '',
    this.contactEmail = '',
    this.avatarPath,
    this.studyStatus = 'studying',
    this.graduatedAt,
  });

  final String id;
  final String name;
  final AppRole role;
  final String membershipId;
  final String organizationId;
  final String phone;
  final DateTime? createdAt;
  final String firstName;
  final String lastName;
  final int? age;
  final String? gender;
  final String branch;
  final String contactEmail;
  final String? avatarPath;
  final String studyStatus;
  final DateTime? graduatedAt;
  String get displayFirstName =>
      firstName.isNotEmpty ? firstName : name.split(' ').first;
  String get displayLastName =>
      lastName.isNotEmpty ? lastName : name.split(' ').skip(1).join(' ');
  AppUser withProfile(
    Map<String, dynamic> values, {
    AppRole? role,
    String? outcome,
  }) {
    final first = values['first_name'] as String? ?? displayFirstName;
    final last = values['last_name'] as String? ?? displayLastName;
    return AppUser(
      id: id,
      name: '$first $last'.trim(),
      role: role ?? this.role,
      membershipId: membershipId,
      organizationId: organizationId,
      phone: values['phone'] as String? ?? phone,
      createdAt: createdAt,
      firstName: first,
      lastName: last,
      age: values.containsKey('age') ? values['age'] as int? : age,
      gender: values.containsKey('gender')
          ? values['gender'] as String?
          : gender,
      branch: values['branch'] as String? ?? branch,
      contactEmail: values['contact_email'] as String? ?? contactEmail,
      avatarPath: values.containsKey('avatar_path')
          ? values['avatar_path'] as String?
          : avatarPath,
      studyStatus: outcome ?? studyStatus,
      graduatedAt: outcome == 'studying'
          ? null
          : graduatedAt ?? (outcome != null ? DateTime.now() : null),
    );
  }
}

class Student {
  const Student({
    required this.id,
    required this.name,
    required this.groupId,
    required this.phone,
    this.enrollmentId = '',
    this.membershipId = '',
    this.completed = false,
    this.left = false,
    this.enrolledFrom,
    this.enrolledUntil,
  });

  final String id;
  final String name;
  final String groupId;
  final String phone;
  final String enrollmentId;
  final String membershipId;
  final bool completed;
  final bool left;
  // The enrollment's own date range, so a journal can tell "absent" apart
  // from "wasn't in this group yet/anymore" on a given lesson's date.
  final DateTime? enrolledFrom;
  final DateTime? enrolledUntil;
  bool get active => !completed && !left;
  String get status => left
      ? 'left'
      : completed
      ? 'completed'
      : 'active';
  String get statusLabel => left
      ? 'Ketgan'
      : completed
      ? 'Tugatgan'
      : 'Aktiv';
  bool enrolledOn(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    if (enrolledFrom != null && day.isBefore(enrolledFrom!)) return false;
    if (enrolledUntil != null && day.isAfter(enrolledUntil!)) return false;
    return true;
  }

  Student copyWith({
    String? name,
    String? phone,
    bool? completed,
    bool? left,
  }) => Student(
    id: id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    groupId: groupId,
    enrollmentId: enrollmentId,
    membershipId: membershipId,
    completed: completed ?? this.completed,
    left: left ?? this.left,
    enrolledFrom: enrolledFrom,
    enrolledUntil: enrolledUntil,
  );
}

class StudyGroup {
  const StudyGroup({
    required this.id,
    required this.name,
    required this.course,
    required this.teacherId,
    required this.teacherName,
    required this.schedule,
    required this.room,
    this.organizationId = '',
    this.teacherMembershipId = '',
    this.status = 'active',
    this.weekDays = const [],
    this.lessonStartTime = '',
    this.lessonEndTime = '',
  });

  final String id;
  final String name;
  final String course;
  final String teacherId;
  final String teacherName;
  final String schedule;
  final String room;
  final String organizationId;
  final String teacherMembershipId;
  final String status;
  final List<int> weekDays;
  // "HH:mm", or '' when the group has no fixed lesson time yet.
  final String lessonStartTime;
  final String lessonEndTime;
  bool get active => status == 'active';
  String get statusLabel => switch (status) {
    'completed' => 'Tugatilgan',
    'frozen' => 'Muzlatilgan',
    _ => 'Faol',
  };
  StudyGroup copyWith({
    String? id,
    String? name,
    String? course,
    String? teacherId,
    String? teacherMembershipId,
    String? teacherName,
    String? schedule,
    String? room,
    String? status,
    List<int>? weekDays,
    String? lessonStartTime,
    String? lessonEndTime,
  }) => StudyGroup(
    id: id ?? this.id,
    name: name ?? this.name,
    course: course ?? this.course,
    teacherId: teacherId ?? this.teacherId,
    teacherName: teacherName ?? this.teacherName,
    teacherMembershipId: teacherMembershipId ?? this.teacherMembershipId,
    schedule: schedule ?? this.schedule,
    room: room ?? this.room,
    organizationId: organizationId,
    status: status ?? this.status,
    weekDays: List.unmodifiable(weekDays ?? this.weekDays),
    lessonStartTime: lessonStartTime ?? this.lessonStartTime,
    lessonEndTime: lessonEndTime ?? this.lessonEndTime,
  );
}

class Lesson {
  const Lesson({
    required this.id,
    required this.groupId,
    required this.topic,
    required this.startsAt,
    this.status = 'planned',
  });

  final String id;
  final String groupId;
  final String topic;
  final DateTime startsAt;
  final String status;
  Lesson withStatus(String value) => Lesson(
    id: id,
    groupId: groupId,
    topic: topic,
    startsAt: startsAt,
    status: value,
  );
}

class Homework {
  Homework({
    required this.id,
    required this.groupId,
    required this.title,
    required this.description,
    required this.dueDate,
    this.lessonId,
    this.filePath,
    this.fileName,
  });

  final String id;
  final String groupId;
  final String title;
  // Attached reference file (task sheet, worksheet, etc.), optional.
  final String? filePath;
  final String? fileName;
  final String description;
  final DateTime dueDate;
  final String? lessonId;
}

class HomeworkResult {
  HomeworkResult({
    required this.homeworkId,
    required this.studentId,
    this.answer = '',
    this.status = HomeworkStatus.waiting,
    this.score,
    this.comment = '',
  });

  final String homeworkId;
  final String studentId;
  String answer;
  HomeworkStatus status;
  int? score;
  String comment;
}

class LessonCheckin {
  const LessonCheckin({
    required this.lessonId,
    required this.teacherId,
    required this.photoPath,
    required this.checkedAt,
  });
  final String lessonId, teacherId, photoPath;
  final DateTime checkedAt;
}
