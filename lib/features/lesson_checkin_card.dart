import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/helpers.dart';
import '../core/camera/selfie_camera.dart';
import '../data/crm_store.dart';
import '../data/models.dart';

class LessonCheckinCard extends StatelessWidget {
  const LessonCheckinCard({
    super.key,
    required this.store,
    required this.lesson,
  });
  final CrmStore store;
  final Lesson lesson;
  @override
  Widget build(BuildContext context) {
    final teacher = store.groupById(lesson.groupId).teacherId;
    final checkin = store.checkinFor(lesson, teacherId: teacher);
    final canCapture = store.isCheckinDay(lesson);
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.softBlue(context),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(
            checkin == null
                ? Icons.camera_alt_outlined
                : Icons.check_circle_outline,
            color: AppColors.primary,
          ),
          Text(
            checkin != null
                ? 'Ustoz darsga kelgan • ${shortTime(checkin.checkedAt.toLocal())}'
                : canCapture
                ? 'Avval suratga tushing, keyin davomatni belgilang.'
                : 'Suratli davomat faqat belgilangan dars kuni ochiladi.',
          ),
          if (checkin != null)
            TextButton(
              onPressed: () => runCrmAction(context, () async {
                final bytes = store.checkinImages[checkin.photoPath];
                final url = bytes == null
                    ? await store.checkinUrl(checkin.photoPath)
                    : null;
                if (!context.mounted) return;
                await showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Darsdagi surat'),
                    content: SizedBox(
                      width: 480,
                      child: bytes != null
                          ? Image.memory(bytes)
                          : Image.network(url!),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Yopish'),
                      ),
                    ],
                  ),
                );
              }),
              child: const Text('Suratni ko‘rish'),
            ),
          if (checkin == null && store.activeRole == AppRole.teacher)
            FilledButton.icon(
              onPressed: !canCapture
                  ? null
                  : () => runCrmAction(context, () async {
                      final photo = await captureSelfie(context);
                      if (photo != null)
                        await store.checkInLesson(lesson, photo);
                    }),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Suratga tushish'),
            ),
        ],
      ),
    );
  }
}
