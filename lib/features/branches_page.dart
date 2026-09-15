import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/helpers.dart';
import '../data/crm_store.dart';
import '../data/models.dart';

class BranchesPage extends StatelessWidget {
  const BranchesPage({super.key, required this.store});
  final CrmStore store;
  @override
  Widget build(BuildContext context) {
    if (store.activeRole != AppRole.admin) return const SizedBox.shrink();
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.icon(
            onPressed: () => _add(context),
            icon: const Icon(Icons.add),
            label: const Text('Filial qo‘shish'),
          ),
          const SizedBox(height: 20),
          if (store.branches.isEmpty)
            const EmptyState(
              text: 'Hali filial qo‘shilmagan',
              icon: Icons.location_on_outlined,
            ),
          for (final branch in store.branches)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: AppColors.softBlue,
                child: Icon(
                  Icons.location_on_outlined,
                  color: AppColors.primary,
                ),
              ),
              title: Text(branch),
            ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final text = TextEditingController();
    final form = GlobalKey<FormState>();
    final saved = await showFormDialog<bool>(
      context: context,
      onDisposed: text.dispose,
      builder: (context) => AlertDialog(
        title: const Text('Yangi filial'),
        content: Form(
          key: form,
          child: TextFormField(
            controller: text,
            autofocus: true,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Filial nomi'),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Nomini kiriting'
                : store.branches.any(
                    (b) => b.toLowerCase() == v.trim().toLowerCase(),
                  )
                ? 'Bu filial mavjud'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Qo‘shish'),
          ),
        ],
      ),
    );
    final name = text.text.trim();
    if (saved == true && context.mounted)
      await runCrmAction(
        context,
        () => store.addBranch(name),
        success: 'Filial qo‘shildi.',
      );
  }
}
