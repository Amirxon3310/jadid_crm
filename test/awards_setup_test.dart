import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The setup notice reads this file at runtime and offers it for copying,
  // so a wrong path in pubspec would leave that dialog stuck on "loading".
  test('the awards migration ships as an asset the notice can read', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final sql = await rootBundle.loadString(
      'supabase/migrations/20260916140000_score_awards.sql',
    );
    expect(sql, contains('create table public.score_awards'));
    expect(sql, contains('score_awards_read'));
    expect(sql, contains('score_awards_add'));
    // It must be the whole migration, totals included.
    expect(sql, contains('private.coin_totals'));
  });
}
