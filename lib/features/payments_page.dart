import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_theme.dart';
import '../core/helpers.dart';
import '../data/crm_store.dart';
import '../data/models.dart';

String paymentAmount(int value) =>
    '${value.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ')} so‘m';
String paymentMethod(String value) => switch (value) {
  'cash' => 'Naqd',
  'card' => 'Karta',
  _ => 'Bank o‘tkazmasi',
};

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key, required this.store});
  final CrmStore store;
  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final admin = store.activeRole == AppRole.admin;
    if (!admin && store.activeRole != AppRole.student)
      return const SizedBox.shrink();
    String name(String id) =>
        store.users.where((u) => u.id == id).firstOrNull?.name ?? 'O‘quvchi';
    final records =
        store.payments
            .where(
              (p) =>
                  (admin || p.studentId == store.activeUser.id) &&
                  '${name(p.studentId)} ${shortDate(p.paidOn)} ${p.note}'
                      .toLowerCase()
                      .contains(query.toLowerCase()),
            )
            .toList()
          ..sort((a, b) => b.paidOn.compareTo(a.paidOn));
    final total = records.fold(0, (sum, p) => sum + p.amount);
    return Surface(
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 24,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Jami to‘lovlar',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    paymentAmount(total),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              if (admin)
                FilledButton.icon(
                  onPressed: store.users.any((u) => u.role == AppRole.student)
                      ? () => _add(context)
                      : null,
                  icon: const Icon(Icons.add),
                  label: const Text('To‘lov qo‘shish'),
                ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            decoration: InputDecoration(
              hintText: admin
                  ? 'O‘quvchi, sana yoki izoh bo‘yicha qidirish'
                  : 'Sana yoki izoh bo‘yicha qidirish',
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => query = value),
          ),
          const SizedBox(height: 20),
          if (records.isEmpty)
            const EmptyState(
              text: 'To‘lovlar topilmadi',
              icon: Icons.receipt_long_outlined,
            ),
          for (final payment in records)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: .045),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 24,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        paymentAmount(payment.amount),
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (admin)
                        Text(
                          name(payment.studentId),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${shortDate(payment.paidOn)} • ${paymentMethod(payment.method)}',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  if (payment.groupId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        store.groups
                                .where((g) => g.id == payment.groupId)
                                .firstOrNull
                                ?.name ??
                            'Guruh',
                      ),
                    ),
                  if (payment.note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(payment.note),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final store = widget.store;
    final students =
        store.users.where((u) => u.role == AppRole.student).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    var student = students.first.id;
    String? group;
    var method = 'cash';
    var paidOn = DateTime.now();
    final amount = TextEditingController(), note = TextEditingController();
    final form = GlobalKey<FormState>();
    final saved = await showFormDialog<bool>(
      context: context,
      onDisposed: () {
        amount.dispose();
        note.dispose();
      },
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) {
          final groups = store.groups
              .where(
                (g) => store.students.any(
                  (s) => s.id == student && s.groupId == g.id,
                ),
              )
              .toList();
          return AlertDialog(
            title: const Text('To‘lov qo‘shish'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Form(
                  key: form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: student,
                        isExpanded: true,
                        borderRadius: BorderRadius.circular(18),
                        decoration: const InputDecoration(
                          labelText: 'O‘quvchi',
                        ),
                        items: students
                            .map(
                              (s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(
                                  s.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => update(() {
                          student = v!;
                          group = null;
                        }),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: amount,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Summa (so‘m)',
                        ),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          return n == null || n <= 0 || n > 1000000000000
                              ? 'Musbat summa kiriting'
                              : null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        key: ValueKey('payment-$student-$group'),
                        initialValue: group ?? '',
                        isExpanded: true,
                        borderRadius: BorderRadius.circular(18),
                        decoration: const InputDecoration(labelText: 'Guruh'),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('Guruhsiz'),
                          ),
                          ...groups.map(
                            (g) => DropdownMenuItem(
                              value: g.id,
                              child: Text(
                                g.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            update(() => group = v == '' ? null : v),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: method,
                        borderRadius: BorderRadius.circular(18),
                        decoration: const InputDecoration(
                          labelText: 'To‘lov usuli',
                        ),
                        items: ['cash', 'card', 'transfer']
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text(paymentMethod(m)),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => update(() => method = v!),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('To‘lov sanasi'),
                        subtitle: Text(shortDate(paidOn)),
                        trailing: const Icon(Icons.calendar_month_outlined),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: paidOn,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) update(() => paidOn = date);
                        },
                      ),
                      TextFormField(
                        controller: note,
                        maxLength: 500,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Izoh (ixtiyoriy)',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: const Text('Bekor qilish'),
              ),
              FilledButton(
                onPressed: () {
                  if (form.currentState!.validate())
                    Navigator.pop(dialog, true);
                },
                child: const Text('Saqlash'),
              ),
            ],
          );
        },
      ),
    );
    final value = int.tryParse(amount.text) ?? 0, details = note.text.trim();
    if (saved == true && context.mounted)
      await runCrmAction(
        context,
        () => store.addPayment(
          studentId: student,
          amount: value,
          paidOn: paidOn,
          method: method,
          groupId: group,
          note: details,
        ),
        success: 'To‘lov saqlandi.',
      );
  }
}
