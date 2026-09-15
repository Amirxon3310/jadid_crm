// Migrations a feature depends on, kept free of Flutter so the data layer
// can raise one without reaching into the UI.

/// Raised when a feature needs a migration the database has not had applied.
/// It carries the migration itself so the notice can hand over the SQL.
class MigrationMissing implements Exception {
  const MigrationMissing({
    required this.title,
    required this.explanation,
    required this.asset,
  });

  final String title;
  final String explanation;

  /// Path of the migration bundled as an asset, shown verbatim.
  final String asset;

  @override
  String toString() => explanation;
}

/// The score_awards table: rewards and penalties.
const scoreAwardsMigration = MigrationMissing(
  title: 'Ball qo‘shish uchun bir marta sozlash',
  explanation:
      'Qo‘shimcha ball uchun bazada alohida jadval kerak, u hali '
      'qo‘llanmagan. Quyidagi SQL’ni nusxalab, Supabase → SQL '
      'Editor’ga qo‘ying va bir marta “Run” bosing. Keyin shu '
      'sahifani yangilang.',
  asset: 'supabase/migrations/20260916140000_score_awards.sql',
);

/// delete_member plus the columns a pupil's answer file needs.
const memberRemovalMigration = MigrationMissing(
  title: 'O‘chirish uchun bir marta sozlash',
  explanation:
      'Foydalanuvchini o‘chirish va uy vazifaga fayl biriktirish uchun '
      'bazada yangi funksiya va ustunlar kerak, ular hali qo‘llanmagan. '
      'Quyidagi SQL’ni nusxalab, Supabase → SQL Editor’ga qo‘ying va bir '
      'marta “Run” bosing. Keyin shu sahifani yangilang.',
  asset:
      'supabase/migrations/20260917060000_member_removal_and_answer_files.sql',
);

/// 0–100 review scores, several files per homework, and deleting homework.
const homeworkReviewMigration = MigrationMissing(
  title: 'Uy vazifa uchun bir marta sozlash',
  explanation:
      'Uy vazifani 0–100 ball bilan tekshirish, bir nechta fayl biriktirish '
      'va vazifani o‘chirish uchun bazada yangi ustunlar va ruxsatlar kerak, '
      'ular hali qo‘llanmagan. Quyidagi SQL’ni nusxalab, Supabase → SQL '
      'Editor’ga qo‘ying va bir marta “Run” bosing. Keyin shu sahifani '
      'yangilang.',
  asset: 'supabase/migrations/20260917120000_homework_review_and_files.sql',
);
