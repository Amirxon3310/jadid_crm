import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_notice.dart';
import '../core/app_theme.dart';
import '../core/helpers.dart';
import '../core/navigation.dart';
import '../core/user_avatar.dart';
import '../data/crm_store.dart';
import '../data/models.dart';

// ---------------------------------------------------------------------------
// Shared reading of a homework's state.

String homeworkStatusLabel(HomeworkStatus status) => switch (status) {
  HomeworkStatus.waiting => 'Bajarilmagan',
  HomeworkStatus.submitted => 'Kutayapti',
  HomeworkStatus.accepted => 'Qabul qilindi',
  HomeworkStatus.returned => 'Qaytarildi',
};

/// Done green, waiting on the teacher yellow, not done (or sent back) red.
Color homeworkStatusColor(HomeworkStatus status) => switch (status) {
  HomeworkStatus.waiting => AppColors.penaltyRed,
  HomeworkStatus.submitted => AppColors.warning,
  HomeworkStatus.accepted => AppColors.rewardGreen,
  HomeworkStatus.returned => AppColors.penaltyRed,
};

const _monthsShort = [
  'Yan',
  'Fev',
  'Mar',
  'Apr',
  'May',
  'Iyn',
  'Iyl',
  'Avg',
  'Sen',
  'Okt',
  'Noy',
  'Dek',
];

/// "15 Sen, 2026" on the centre's clock.
String _day(DateTime time) {
  final local = tashkentDate(time);
  return '${local.day.toString().padLeft(2, '0')} '
      '${_monthsShort[local.month - 1]}, ${local.year}';
}

String _time(DateTime time) {
  final local = tashkentDate(time);
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String _dayTime(DateTime time) => '${_day(time)} ${_time(time)}';

Lesson? _lessonOf(CrmStore store, Homework homework) =>
    homework.lessonId == null
    ? null
    : store.lessons.where((l) => l.id == homework.lessonId).firstOrNull;

/// The heading a homework is known by: its lesson's topic, or what it asks.
String _topicOf(CrmStore store, Homework homework) =>
    _lessonOf(store, homework)?.topic ?? homework.title;

typedef _Split = ({
  int pupils,
  int waiting,
  int returned,
  int accepted,
  int missing,
});

_Split _splitOf(CrmStore store, Homework homework) {
  var waiting = 0, returned = 0, accepted = 0, missing = 0;
  final pupils = store.studentsOf(homework.groupId);
  for (final pupil in pupils) {
    switch (store.resultFor(homework.id, pupil.id).status) {
      case HomeworkStatus.submitted:
        waiting++;
      case HomeworkStatus.returned:
        returned++;
      case HomeworkStatus.accepted:
        accepted++;
      case HomeworkStatus.waiting:
        missing++;
    }
  }
  return (
    pupils: pupils.length,
    waiting: waiting,
    returned: returned,
    accepted: accepted,
    missing: missing,
  );
}

void _openDetail(BuildContext context, CrmStore store, Homework homework) =>
    goTo(
      context,
      homeworkPath(homework.id),
      fallback: (_) =>
          HomeworkDetailPage(store: store, homeworkId: homework.id),
    );

// ---------------------------------------------------------------------------
// The group's homework tab: one table, newest first.

class GroupHomeworkTab extends StatelessWidget {
  const GroupHomeworkTab({super.key, required this.store, required this.group});

  final CrmStore store;
  final StudyGroup group;

  @override
  Widget build(BuildContext context) {
    final staff = store.activeRole != AppRole.student;
    final canManage = staff && store.canManageGroup(group.id);
    final homeworks = store.homeworksOf(group.id)
      ..sort(
        (a, b) =>
            (b.createdAt ?? b.dueDate).compareTo(a.createdAt ?? a.dueDate),
      );
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const title = Text(
                'Uy vazifalari',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              );
              if (!canManage || !group.active) return title;
              final button = FilledButton.icon(
                onPressed: () => showHomeworkForm(context, store, group),
                icon: const Icon(Icons.add),
                label: const Text('Uy vazifa qo‘shish'),
              );
              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [title, const SizedBox(height: 10), button],
                );
              }
              return Row(
                children: [
                  const Expanded(child: title),
                  button,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          if (homeworks.isEmpty)
            const EmptyState(
              text: 'Uy vazifasi berilmagan',
              icon: Icons.assignment_outlined,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: staff
                      ? _staffTable(context, homeworks, canManage)
                      : _pupilTable(context, homeworks),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static const _heading = TextStyle(
    color: AppColors.muted,
    fontWeight: FontWeight.w600,
    fontSize: 13,
  );

  Widget _staffTable(
    BuildContext context,
    List<Homework> homeworks,
    bool canManage,
  ) => DataTable(
    showCheckboxColumn: false,
    columnSpacing: 22,
    dataRowMinHeight: 64,
    dataRowMaxHeight: 78,
    headingTextStyle: _heading,
    columns: [
      const DataColumn(label: Text('#')),
      const DataColumn(label: Text('Mavzu')),
      const DataColumn(
        numeric: true,
        label: Tooltip(
          message: 'O‘quvchilar',
          child: Icon(Icons.person_outline_rounded, color: AppColors.muted),
        ),
      ),
      const DataColumn(
        numeric: true,
        label: Tooltip(
          message: 'Tekshirilishi kutilmoqda',
          child: Icon(Icons.timer_outlined, color: AppColors.warning),
        ),
      ),
      const DataColumn(
        numeric: true,
        label: Tooltip(
          message: 'Qabul qilingan',
          child: Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.rewardGreen,
          ),
        ),
      ),
      const DataColumn(label: Text('Berilgan vaqt')),
      const DataColumn(label: Text('Tugash vaqti')),
      const DataColumn(label: Text('Dars sanasi')),
      if (canManage) const DataColumn(label: SizedBox.shrink()),
    ],
    rows: [
      for (final (index, homework) in homeworks.indexed)
        _staffRow(context, index, homework, canManage),
    ],
  );

  DataRow _staffRow(
    BuildContext context,
    int index,
    Homework homework,
    bool canManage,
  ) {
    final split = _splitOf(store, homework);
    final lesson = _lessonOf(store, homework);
    return DataRow(
      onSelectChanged: (_) => _openDetail(context, store, homework),
      cells: [
        DataCell(Text('${index + 1}')),
        DataCell(
          _TopicCell(
            topic: lesson?.topic ?? homework.title,
            task: lesson == null ? null : homework.title,
            // Answers are waiting on the teacher: the row asks to be opened.
            highlight: split.waiting > 0,
          ),
        ),
        DataCell(Text('${split.pupils}')),
        DataCell(
          Text(
            '${split.waiting}',
            style: TextStyle(
              color: split.waiting > 0 ? AppColors.warning : AppColors.muted,
              fontWeight: split.waiting > 0 ? FontWeight.w700 : null,
            ),
          ),
        ),
        DataCell(
          Text(
            '${split.accepted}',
            style: TextStyle(
              color: split.accepted > 0
                  ? AppColors.rewardGreen
                  : AppColors.muted,
              fontWeight: split.accepted > 0 ? FontWeight.w600 : null,
            ),
          ),
        ),
        DataCell(
          homework.createdAt == null
              ? const Text('—')
              : _TwoLines(homework.createdAt!),
        ),
        DataCell(_TwoLines(homework.dueDate)),
        DataCell(Text(lesson == null ? '—' : _day(lesson.startsAt))),
        if (canManage)
          DataCell(
            _HomeworkMenu(store: store, group: group, homework: homework),
          ),
      ],
    );
  }

  Widget _pupilTable(BuildContext context, List<Homework> homeworks) {
    final me = store.activeUser.id;
    return DataTable(
      showCheckboxColumn: false,
      columnSpacing: 24,
      dataRowMinHeight: 64,
      dataRowMaxHeight: 78,
      headingTextStyle: _heading,
      columns: const [
        DataColumn(label: Text('#')),
        DataColumn(label: Text('Mavzu')),
        DataColumn(label: Text('Holat')),
        DataColumn(label: Text('Ball'), numeric: true),
        DataColumn(label: Text('Tugash vaqti')),
        DataColumn(label: Text('Dars sanasi')),
      ],
      rows: [
        for (final (index, homework) in homeworks.indexed)
          () {
            final result = store.resultFor(homework.id, me);
            final lesson = _lessonOf(store, homework);
            final overdue =
                !result.hasAnswer && homework.dueDate.isBefore(DateTime.now());
            return DataRow(
              onSelectChanged: (_) => _openDetail(context, store, homework),
              cells: [
                DataCell(Text('${index + 1}')),
                DataCell(
                  _TopicCell(
                    topic: lesson?.topic ?? homework.title,
                    task: lesson == null ? null : homework.title,
                    highlight: false,
                  ),
                ),
                DataCell(_StatusChip(result.status)),
                DataCell(_ScoreText(result.score)),
                DataCell(
                  _TwoLines(
                    homework.dueDate,
                    color: overdue ? AppColors.penaltyRed : null,
                  ),
                ),
                DataCell(Text(lesson == null ? '—' : _day(lesson.startsAt))),
              ],
            );
          }(),
      ],
    );
  }
}

class _TopicCell extends StatelessWidget {
  const _TopicCell({
    required this.topic,
    required this.task,
    required this.highlight,
  });

  final String topic;
  final String? task;
  final bool highlight;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 220, maxWidth: 440),
    child: Container(
      padding: highlight
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 7)
          : EdgeInsets.zero,
      decoration: highlight
          ? BoxDecoration(
              color: AppColors.warning.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: .45),
              ),
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            topic,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
          if (task != null)
            Text(
              task!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
        ],
      ),
    ),
  );
}

/// The date on top, the time beneath it.
class _TwoLines extends StatelessWidget {
  const _TwoLines(this.time, {this.color});
  final DateTime time;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(_day(time), style: TextStyle(color: color)),
      Text(
        _time(time),
        style: TextStyle(fontSize: 12, color: color ?? AppColors.muted),
      ),
    ],
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status, {this.label});
  final HomeworkStatus status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final color = homeworkStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .45)),
      ),
      child: Text(
        label ?? homeworkStatusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A review score, green once it passes and red below.
class _ScoreText extends StatelessWidget {
  const _ScoreText(this.score, {this.size = 14});
  final int? score;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (score == null) {
      return Text(
        '—',
        style: TextStyle(color: AppColors.muted, fontSize: size),
      );
    }
    return Text(
      '$score',
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: score! >= homeworkPassScore
            ? AppColors.rewardGreen
            : AppColors.penaltyRed,
      ),
    );
  }
}

class _HomeworkMenu extends StatelessWidget {
  const _HomeworkMenu({
    required this.store,
    required this.group,
    required this.homework,
    this.onDeleted,
  });

  final CrmStore store;
  final StudyGroup group;
  final Homework homework;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Amallar',
    icon: const Icon(Icons.more_vert_rounded, color: AppColors.muted),
    onSelected: (value) async {
      if (value == 'edit') {
        await showHomeworkForm(context, store, group, editing: homework);
      }
      if (value == 'delete' &&
          await _confirmDelete(context, store, homework) &&
          context.mounted) {
        onDeleted?.call();
      }
    },
    itemBuilder: (_) => const [
      PopupMenuItem(
        value: 'edit',
        child: Row(
          children: [
            Icon(Icons.edit_outlined, size: 20),
            SizedBox(width: 10),
            Text('Tahrirlash'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: AppColors.danger,
            ),
            SizedBox(width: 10),
            Text('O‘chirish', style: TextStyle(color: AppColors.danger)),
          ],
        ),
      ),
    ],
  );
}

/// Asks first, naming how many answers go with the homework. True once the
/// delete has been started.
Future<bool> _confirmDelete(
  BuildContext context,
  CrmStore store,
  Homework homework,
) async {
  final split = _splitOf(store, homework);
  final answered = split.pupils - split.missing;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
      title: const Text('Uy vazifani o‘chirasizmi?'),
      content: SizedBox(
        width: 420,
        child: Text(
          '“${homework.title}” butunlay o‘chadi'
          '${answered == 0 ? '.' : ', unga yuborilgan $answered ta javob va baholari bilan birga.'}'
          '\n\nBu amalni qaytarib bo‘lmaydi.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Bekor qilish'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('O‘chirish'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  await runCrmAction(
    context,
    () => store.deleteHomework(homework.id),
    success: 'Uy vazifa o‘chirildi',
  );
  return true;
}

// ---------------------------------------------------------------------------
// Adding and editing a homework.

DateTime _defaultDue() {
  final day = DateTime.now().add(const Duration(days: 7));
  return DateTime(day.year, day.month, day.day, 23, 59);
}

Future<void> showHomeworkForm(
  BuildContext context,
  CrmStore store,
  StudyGroup group, {
  Homework? editing,
}) async {
  final choices = store
      .lessonsOf(group.id)
      .where((l) => l.status != 'cancelled')
      .toList();
  if (editing == null && choices.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Avval darsni boshlang'),
        content: const Text(
          'Uy vazifasi darsga bog‘lanadi. Davomat bo‘limida bugungi dars '
          'nomini kiriting.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Yopish'),
          ),
        ],
      ),
    );
    return;
  }
  final task = TextEditingController(text: editing?.title ?? '');
  var lessonId = editing?.lessonId ?? choices.first.id;
  var dueDate = editing?.dueDate ?? _defaultDue();
  final files = <PickedFile>[];
  final saved = await showFormDialog<bool>(
    context: context,
    onDisposed: task.dispose,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: Text(
          editing == null ? 'Uy vazifa qo‘shish' : 'Uy vazifani tahrirlash',
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (editing == null) ...[
                  DropdownButtonFormField<String>(
                    initialValue: lessonId,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(16),
                    decoration: const InputDecoration(
                      labelText: 'Qaysi dars uchun?',
                      prefixIcon: Icon(Icons.menu_book_outlined, size: 20),
                    ),
                    items: [
                      for (final lesson in choices)
                        DropdownMenuItem(
                          value: lesson.id,
                          child: Text(
                            '${_day(lesson.startsAt)} • ${lesson.topic}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) =>
                        update(() => lessonId = value ?? lessonId),
                  ),
                  const SizedBox(height: 14),
                ],
                TextField(
                  controller: task,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Izoh (nima qilish kerak)',
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: Text('Tugash vaqti: ${_dayTime(dueDate)}'),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () async {
                    final today = DateUtils.dateOnly(DateTime.now());
                    final date = await showDatePicker(
                      context: context,
                      initialDate: dueDate,
                      // An overdue homework being edited keeps its date on
                      // the calendar.
                      firstDate: dueDate.isBefore(today) ? dueDate : today,
                      lastDate: today.add(const Duration(days: 730)),
                    );
                    if (date != null && context.mounted) {
                      update(
                        () => dueDate = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          23,
                          59,
                        ),
                      );
                    }
                  },
                ),
                if (editing == null) ...[
                  const SizedBox(height: 8),
                  FileDropArea(files: files, onChanged: () => update(() {})),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () {
              if (task.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: Text(editing == null ? 'Qo‘shish' : 'Saqlash'),
          ),
        ],
      ),
    ),
  );
  if (saved != true || !context.mounted) return;
  final text = task.text.trim();
  await runCrmAction(
    context,
    () => editing == null
        ? store.addHomework(
            group.id,
            text,
            '',
            dueDate,
            lessonId: lessonId,
            files: List.of(files),
          )
        : store.updateHomework(editing.id, title: text, dueDate: dueDate),
    success: editing == null ? 'Uy vazifa qo‘shildi' : 'Saqlandi',
  );
}

// ---------------------------------------------------------------------------
// Files.

/// The homework-files bucket refuses anything larger.
const _maxFileBytes = 10 * 1024 * 1024;

/// The tap-to-upload area, with the files picked so far beneath it.
class FileDropArea extends StatelessWidget {
  const FileDropArea({super.key, required this.files, required this.onChanged});

  final List<PickedFile> files;
  final VoidCallback onChanged;

  Future<void> _pick(BuildContext context) async {
    final picked = await FilePicker.pickFiles();
    for (final file in picked) {
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxFileBytes) {
        if (context.mounted) {
          showAppNotice(
            context,
            '${file.name} 10 MB dan katta — yuklab bo‘lmaydi.',
            isError: true,
          );
        }
        continue;
      }
      files.add(PickedFile(file.name, bytes));
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Material(
        color: AppColors.panel(context),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _pick(context),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: .35),
                width: 1.2,
              ),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  size: 34,
                  color: AppColors.primary,
                ),
                SizedBox(height: 8),
                Text(
                  'Fayl yuklash uchun shu yerni bosing',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 4),
                Text(
                  'Rasm, PDF, video yoki hujjat — har biri 10 MB gacha',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
      if (files.isNotEmpty) ...[
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (index, file) in files.indexed)
              InputChip(
                avatar: const Icon(Icons.attach_file_rounded, size: 16),
                label: Text(file.name, overflow: TextOverflow.ellipsis),
                onDeleted: () {
                  files.removeAt(index);
                  onChanged();
                },
              ),
          ],
        ),
      ],
    ],
  );
}

/// Signed links live five minutes; one is reused for four, so thumbnails do
/// not refetch on every rebuild yet never show an expired link.
final _signedUrls = <String, (DateTime, Future<String>)>{};

Future<String> _signedUrl(CrmStore store, String path) {
  final cached = _signedUrls[path];
  if (cached != null &&
      DateTime.now().difference(cached.$1) < const Duration(minutes: 4)) {
    return cached.$2;
  }
  final url = store.homeworkFileUrl(path);
  _signedUrls[path] = (DateTime.now(), url);
  url.then<void>((_) {}, onError: (Object _) => _signedUrls.remove(path));
  return url;
}

/// A row of files: images as thumbnails, anything else as its type.
class _FileStrip extends StatelessWidget {
  const _FileStrip({required this.store, required this.files});
  final CrmStore store;
  final List<HomeworkFile> files;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [for (final file in files) _FileTile(store: store, file: file)],
  );
}

class _FileTile extends StatelessWidget {
  const _FileTile({required this.store, required this.file});
  final CrmStore store;
  final HomeworkFile file;

  @override
  Widget build(BuildContext context) {
    // A file still uploading has no path to open yet.
    final ready = store.isOnline && file.path.isNotEmpty;
    final kind = _FileKind(file);
    return Tooltip(
      message: file.name,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: ready
            ? () => runCrmAction(context, () async {
                final url = await _signedUrl(store, file.path);
                await launchUrl(Uri.parse(url));
              })
            : null,
        child: SizedBox(
          width: 124,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 124,
                  height: 88,
                  color: AppColors.panel(context),
                  child: ready && file.isImage
                      ? FutureBuilder<String>(
                          future: _signedUrl(store, file.path),
                          builder: (context, snapshot) => snapshot.hasData
                              ? Image.network(
                                  snapshot.data!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => kind,
                                )
                              : kind,
                        )
                      : kind,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                ready ? file.name : '${file.name} • yuklanmoqda',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileKind extends StatelessWidget {
  const _FileKind(this.file);
  final HomeworkFile file;

  @override
  Widget build(BuildContext context) {
    final extension = file.name.contains('.')
        ? file.name.split('.').last.toUpperCase()
        : 'FAYL';
    final icon = switch (extension) {
      'PDF' => Icons.picture_as_pdf_outlined,
      'MP4' || 'MOV' || 'WEBM' => Icons.movie_outlined,
      'PNG' || 'JPG' || 'JPEG' || 'GIF' || 'WEBP' => Icons.image_outlined,
      _ => Icons.description_outlined,
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(
            extension,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One homework: what was asked, and who has answered.

class HomeworkDetailPage extends StatefulWidget {
  const HomeworkDetailPage({
    super.key,
    required this.store,
    required this.homeworkId,
  });

  final CrmStore store;
  final String homeworkId;

  @override
  State<HomeworkDetailPage> createState() => _HomeworkDetailPageState();
}

class _HomeworkDetailPageState extends State<HomeworkDetailPage> {
  HomeworkStatus tab = HomeworkStatus.submitted;

  CrmStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    store.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant HomeworkDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != store) {
      oldWidget.store.removeListener(_refresh);
      store.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    store.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final homework = store.homeworks
        .where((h) => h.id == store.resolveId(widget.homeworkId))
        .firstOrNull;
    if (homework == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                ),
              ),
              const Expanded(
                child: Center(child: Text('Uy vazifa topilmadi.')),
              ),
            ],
          ),
        ),
      );
    }
    final group = store.groupById(homework.groupId);
    final staff = store.activeRole != AppRole.student;
    final canManage = staff && store.canManageGroup(group.id);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    title: _topicOf(store, homework),
                    subtitle: group.name,
                    trailing: canManage
                        ? _HomeworkMenu(
                            store: store,
                            group: group,
                            homework: homework,
                            onDeleted: () => Navigator.pop(context),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _InfoCard(store: store, group: group, homework: homework),
                  const SizedBox(height: 16),
                  if (staff)
                    _submissions(context, homework, canManage)
                  else
                    _PupilAnswer(store: store, homework: homework),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _submissions(BuildContext context, Homework homework, bool canManage) {
    final split = _splitOf(store, homework);
    final tabs = [
      (HomeworkStatus.submitted, 'Kutayotganlar', split.waiting),
      (HomeworkStatus.returned, 'Qaytarilganlar', split.returned),
      (HomeworkStatus.accepted, 'Qabul qilinganlar', split.accepted),
      (HomeworkStatus.waiting, 'Bajarilmagan', split.missing),
    ];
    final pupils = [
      for (final pupil in store.studentsOf(homework.groupId))
        if (store.resultFor(homework.id, pupil.id).status == tab) pupil,
    ];
    final reviewed =
        tab == HomeworkStatus.accepted || tab == HomeworkStatus.returned;
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (status, label, count) in tabs)
                  _TabButton(
                    label: label,
                    count: count,
                    color: homeworkStatusColor(status),
                    selected: tab == status,
                    onTap: () => setState(() => tab = status),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 6),
          if (pupils.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Text(
                'Bu ro‘yxatda hech kim yo‘q',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'O‘quvchi ismi',
                      style: GroupHomeworkTab._heading,
                    ),
                  ),
                  const SizedBox(
                    width: 190,
                    child: Text(
                      'Jo‘natilgan vaqt',
                      style: GroupHomeworkTab._heading,
                    ),
                  ),
                  if (reviewed)
                    const SizedBox(
                      width: 60,
                      child: Text('Ball', style: GroupHomeworkTab._heading),
                    ),
                  const SizedBox(width: 28),
                ],
              ),
            ),
            for (final pupil in pupils)
              _PupilRow(
                store: store,
                homework: homework,
                pupil: pupil,
                showScore: reviewed,
                onOpen: canManage || reviewed || tab == HomeworkStatus.submitted
                    ? () => showHomeworkReview(context, store, homework, pupil)
                    : null,
              ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle, this.trailing});
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .07),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Orqaga',
          onPressed: () => goBack(context, '/homeworks'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.store,
    required this.group,
    required this.homework,
  });

  final CrmStore store;
  final StudyGroup group;
  final Homework homework;

  @override
  Widget build(BuildContext context) {
    final lesson = _lessonOf(store, homework);
    final overdue = homework.dueDate.isBefore(DateTime.now());
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 44,
            runSpacing: 16,
            children: [
              _Fact('Mavzu', _topicOf(store, homework)),
              _Fact('Guruh', group.name),
              if (homework.createdAt != null)
                _Fact('Berilgan vaqt', _dayTime(homework.createdAt!)),
              _Fact(
                'Tugash vaqti',
                _dayTime(homework.dueDate),
                color: overdue ? AppColors.penaltyRed : null,
              ),
              if (lesson != null) _Fact('Dars sanasi', _day(lesson.startsAt)),
            ],
          ),
          const Divider(height: 32),
          const _Label('Izoh'),
          const SizedBox(height: 4),
          SelectableText(homework.title, style: const TextStyle(fontSize: 15)),
          if (homework.files.isNotEmpty) ...[
            const SizedBox(height: 16),
            const _Label('Uy vazifa fayllari'),
            const SizedBox(height: 8),
            _FileStrip(store: store, files: homework.files),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      _Label(label),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    ],
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 12, color: AppColors.muted));
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 2.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? null : AppColors.muted,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              constraints: const BoxConstraints(minWidth: 22),
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _PupilRow extends StatelessWidget {
  const _PupilRow({
    required this.store,
    required this.homework,
    required this.pupil,
    required this.showScore,
    required this.onOpen,
  });

  final CrmStore store;
  final Homework homework;
  final Student pupil;
  final bool showScore;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final result = store.resultFor(homework.id, pupil.id);
    final user = store.users.where((u) => u.id == pupil.id).firstOrNull;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            if (user != null)
              UserAvatar(store: store, user: user, radius: 16)
            else
              CircleAvatar(
                radius: 16,
                child: Text(pupil.name.isEmpty ? '?' : pupil.name[0]),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                pupil.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(
              width: 190,
              child: Text(
                result.submittedAt == null
                    ? '—'
                    : _dayTime(result.submittedAt!),
              ),
            ),
            if (showScore) SizedBox(width: 60, child: _ScoreText(result.score)),
            SizedBox(
              width: 28,
              child: onOpen == null
                  ? null
                  : const Icon(Icons.chevron_right, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reviewing one pupil's answer, in a panel that slides in from the right.

Future<void> showHomeworkReview(
  BuildContext context,
  CrmStore store,
  Homework homework,
  Student pupil,
) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Yopish',
  barrierColor: Colors.black.withValues(alpha: .35),
  transitionDuration: const Duration(milliseconds: 220),
  pageBuilder: (dialogContext, _, _) => Align(
    alignment: Alignment.centerRight,
    child: _ReviewPanel(
      store: store,
      homeworkId: homework.id,
      pupil: pupil,
      host: context,
    ),
  ),
  transitionBuilder: (_, animation, _, child) => SlideTransition(
    position: Tween(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
    child: child,
  ),
);

class _ReviewPanel extends StatefulWidget {
  const _ReviewPanel({
    required this.store,
    required this.homeworkId,
    required this.pupil,
    required this.host,
  });

  final CrmStore store;
  final String homeworkId;
  final Student pupil;

  /// The page underneath: the save notice shows there once the panel closes.
  final BuildContext host;

  @override
  State<_ReviewPanel> createState() => _ReviewPanelState();
}

class _ReviewPanelState extends State<_ReviewPanel> {
  late final HomeworkResult initial = widget.store.resultFor(
    widget.homeworkId,
    widget.pupil.id,
  );
  late int score = initial.score ?? homeworkPassScore;
  late final scoreText = TextEditingController(text: '$score');
  late final comment = TextEditingController(text: initial.comment);
  final files = <PickedFile>[];

  @override
  void dispose() {
    scoreText.dispose();
    comment.dispose();
    super.dispose();
  }

  void _setScore(int value, {bool fromField = false}) {
    setState(() => score = value.clamp(0, 100));
    // Typing drives the slider; the slider rewrites the field.
    if (!fromField) scoreText.text = '$score';
  }

  Future<void> _send() async {
    final store = widget.store;
    final host = widget.host;
    final sent = (
      score: score,
      comment: comment.text.trim(),
      files: [...files],
    );
    Navigator.pop(context);
    if (!host.mounted) return;
    await runCrmAction(
      host,
      () => store.reviewHomework(
        homeworkId: widget.homeworkId,
        studentId: widget.pupil.id,
        score: sent.score,
        comment: sent.comment,
        files: sent.files,
      ),
      success: sent.score >= homeworkPassScore
          ? 'Qabul qilindi'
          : 'Qayta bajarishga qaytarildi',
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final width = MediaQuery.sizeOf(context).width;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 16,
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width < 520 ? width : 500,
        height: double.infinity,
        child: SafeArea(
          child: ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              final homework = store.homeworks
                  .where((h) => h.id == store.resolveId(widget.homeworkId))
                  .firstOrNull;
              if (homework == null) {
                return const Center(child: Text('Uy vazifa topilmadi.'));
              }
              final result = store.resultFor(homework.id, widget.pupil.id);
              final canReview =
                  store.canManageGroup(homework.groupId) && result.hasAnswer;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: homeworkStatusLabel(result.status),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const TextSpan(
                                  text: '  ›  Uy vazifa',
                                  style: TextStyle(color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Yopish',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Section(
                            title: 'Uy vazifasi',
                            children: [
                              const _Label('Izoh'),
                              const SizedBox(height: 4),
                              Text(homework.title),
                              if (homework.files.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                const _Label('Uy vazifa fayllari'),
                                const SizedBox(height: 8),
                                _FileStrip(store: store, files: homework.files),
                              ],
                            ],
                          ),
                          const SizedBox(height: 14),
                          _Section(
                            title: widget.pupil.name,
                            children: [
                              Wrap(
                                spacing: 28,
                                runSpacing: 12,
                                crossAxisAlignment: WrapCrossAlignment.end,
                                children: [
                                  _Fact(
                                    'Vaqti',
                                    result.submittedAt == null
                                        ? '—'
                                        : _dayTime(result.submittedAt!),
                                  ),
                                  _Fact(
                                    'Fayllar soni',
                                    '${result.files.length}',
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const _Label('Status'),
                                      const SizedBox(height: 4),
                                      _StatusChip(result.status),
                                    ],
                                  ),
                                ],
                              ),
                              if (result.files.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                _FileStrip(store: store, files: result.files),
                              ],
                              if (result.answer.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                _Quote(
                                  label: 'Uy vazifa izohi',
                                  text: result.answer,
                                ),
                              ],
                              if (!result.hasAnswer) ...[
                                const SizedBox(height: 12),
                                const Text(
                                  'O‘quvchi hali javob yubormagan.',
                                  style: TextStyle(color: AppColors.muted),
                                ),
                              ],
                              if (result.reviewFiles.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                const _Label('Ustoz yuborgan fayllar'),
                                const SizedBox(height: 8),
                                _FileStrip(
                                  store: store,
                                  files: result.reviewFiles,
                                ),
                              ],
                            ],
                          ),
                          if (canReview) ...[
                            const SizedBox(height: 14),
                            _reviewForm(context),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (canReview)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Bekor qilish'),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            onPressed: _send,
                            child: const Text('Yuborish'),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _reviewForm(BuildContext context) {
    final passes = score >= homeworkPassScore;
    final color = passes ? AppColors.rewardGreen : AppColors.penaltyRed;
    return _Section(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: .25)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$homeworkPassScore–100 ball qo‘yilgan vazifa “Qabul qilindi”, '
                  '0–${homeworkPassScore - 1} ball qo‘yilgani “Qaytarildi” '
                  'hisoblanadi.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text('Ball', style: TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            _StatusChip(
              passes ? HomeworkStatus.accepted : HomeworkStatus.returned,
              label: passes ? 'Qabul qilinadi' : 'Qaytariladi',
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: color,
                      thumbColor: color,
                      inactiveTrackColor: color.withValues(alpha: .18),
                      overlayColor: color.withValues(alpha: .12),
                    ),
                    child: Slider(
                      value: score.toDouble(),
                      max: 100,
                      divisions: 100,
                      label: '$score',
                      onChanged: (value) => _setScore(value.round()),
                    ),
                  ),
                  // The pass mark, under its place on the track.
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Align(
                      alignment: Alignment(2 * homeworkPassScore / 100 - 1, 0),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 8,
                            child: VerticalDivider(
                              width: 2,
                              thickness: 2,
                              color: AppColors.muted,
                            ),
                          ),
                          Text(
                            'O‘tish bali',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 70,
              child: TextField(
                key: const ValueKey('review-score'),
                controller: scoreText,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                decoration: const InputDecoration(isDense: true),
                onChanged: (text) {
                  final value = int.tryParse(text);
                  if (value != null) _setScore(value, fromField: true);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Fayllar', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        FileDropArea(files: files, onChanged: () => setState(() {})),
        const SizedBox(height: 16),
        TextField(
          controller: comment,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Izohingiz'),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({this.title, required this.children});
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.panel(context),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Text(
            title!,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
        ],
        ...children,
      ],
    ),
  );
}

/// A note set off by a bar on its left.
class _Quote extends StatelessWidget {
  const _Quote({required this.label, required this.text});
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(10),
      border: const Border(
        left: BorderSide(color: AppColors.primary, width: 3),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        const SizedBox(height: 4),
        SelectableText(
          text,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// A pupil's own answer to one homework.

class _PupilAnswer extends StatefulWidget {
  const _PupilAnswer({required this.store, required this.homework});
  final CrmStore store;
  final Homework homework;

  @override
  State<_PupilAnswer> createState() => _PupilAnswerState();
}

class _PupilAnswerState extends State<_PupilAnswer> {
  late final note = TextEditingController(
    text: widget.store
        .resultFor(widget.homework.id, widget.store.activeUser.id)
        .answer,
  );
  final files = <PickedFile>[];

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final sent = [...files];
    await runCrmAction(
      context,
      () => widget.store.submitHomework(
        widget.homework.id,
        widget.store.activeUser.id,
        note.text.trim(),
        files: sent,
      ),
      success: 'Javob yuborildi',
    );
    if (mounted) setState(files.clear);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final homework = widget.homework;
    final me = store.activeUser.id;
    final result = store.resultFor(homework.id, me);
    final ended =
        !store.studentById(me, homework.groupId).active ||
        !store.groupById(homework.groupId).active;
    final locked = ended || result.status == HomeworkStatus.accepted;
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Mening javobim',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              _StatusChip(result.status),
            ],
          ),
          if (result.score != null ||
              result.comment.isNotEmpty ||
              result.reviewFiles.isNotEmpty) ...[
            const SizedBox(height: 14),
            _Section(
              title: 'Ustoz bahosi',
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _ScoreText(result.score, size: 28),
                    const Text(
                      ' / 100',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
                if (result.comment.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _Quote(label: 'Ustoz izohi', text: result.comment),
                ],
                if (result.reviewFiles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _FileStrip(store: store, files: result.reviewFiles),
                ],
              ],
            ),
          ],
          if (result.hasAnswer) ...[
            const SizedBox(height: 14),
            _Section(
              title: 'Yuborilgan javob',
              children: [
                if (result.submittedAt != null)
                  _Fact('Jo‘natilgan vaqt', _dayTime(result.submittedAt!)),
                if (result.files.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _FileStrip(store: store, files: result.files),
                ],
                if (result.answer.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _Quote(label: 'Izohim', text: result.answer),
                ],
              ],
            ),
          ],
          const SizedBox(height: 18),
          if (locked)
            Text(
              ended
                  ? 'Bu guruhdagi o‘qish tugagan.'
                  : 'Javobingiz qabul qilingan.',
              style: const TextStyle(color: AppColors.muted),
            )
          else ...[
            Text(
              result.hasAnswer ? 'Qayta yuborish' : 'Javob yuborish',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            FileDropArea(files: files, onChanged: () => setState(() {})),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Izohingiz'),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _send,
                child: const Text('Yuborish'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
