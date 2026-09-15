import 'dart:async';
import 'package:flutter/material.dart';
import 'app_notice.dart';
import '../data/optimistic_queue.dart';

String shortDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

String shortTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

Future<void> runCrmAction(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (context.mounted && success != null) {
      showAppNotice(context, success);
    }
  } catch (error) {
    if (error is MutationCancelled) return;
    if (context.mounted) {
      showAppNotice(context, crmActionError(error), isError: true);
    }
  }
}

/// The text a failed action shows. A StateError or ArgumentError the app
/// raised itself already says what went wrong, in Uzbek, so it is shown as
/// written; anything else gets the general advice.
String crmActionError(Object error) {
  final message = switch (error) {
    ArgumentError(:final message) => '$message',
    StateError(:final message) => message,
    _ => '',
  };
  // Dart's own lookup failures ("No element", "Too many elements") are not
  // written for anyone to read.
  if (message.isEmpty ||
      message.startsWith('No element') ||
      message.startsWith('Too many elements') ||
      message.startsWith('Bad state')) {
    return 'Amal bajarilmadi. Ulanish va ruxsatlarni tekshirib, '
        'qayta urinib ko‘ring.';
  }
  return message;
}

/// Keep form controllers alive until the dialog's closing animation finishes.
Future<T?> showFormDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  required VoidCallback onDisposed,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<T>(
    context: context,
    builder: builder,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
  );
  unawaited(route.completed.then((_) => onDisposed()));
  return navigator.push(route);
}
