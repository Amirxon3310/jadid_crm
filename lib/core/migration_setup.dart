import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_notice.dart';
import 'migration.dart';
import 'app_theme.dart';

/// Shows the migration's SQL with a copy button, so an admin can paste it
/// into Supabase → SQL Editor and run it once.
Future<void> showMigrationSetup(
  BuildContext context,
  MigrationMissing missing,
) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    icon: const Icon(Icons.storage_rounded, color: AppColors.warning),
    title: Text(missing.title),
    content: SizedBox(
      width: 560,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(missing.explanation),
          const SizedBox(height: 14),
          // Straight from the migration file, so what is copied here is
          // exactly what the repository would apply.
          FutureBuilder<String>(
            future: rootBundle.loadString(missing.asset),
            builder: (context, snapshot) {
              final sql = snapshot.data;
              if (sql == null) {
                // A plain line rather than a spinner: nothing here should
                // animate forever if the file cannot be read.
                return const SizedBox(
                  height: 60,
                  child: Center(child: Text('SQL yuklanmoqda…')),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 220,
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.ink.withValues(alpha: .06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        sql,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.rewardGreen,
                    ),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: sql));
                      if (context.mounted) {
                        showAppNotice(context, 'SQL nusxalandi');
                      }
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('SQL’ni nusxalash'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialogContext),
        child: const Text('Yopish'),
      ),
    ],
  ),
);
