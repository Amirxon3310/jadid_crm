import 'dart:async';

class MutationCancelled implements Exception {}

/// Keeps a confirmed snapshot and replays outstanding edits over it. A rejected
/// request therefore cannot overwrite a newer edit or an unrelated pending row.
class OptimisticQueue<S extends Object> {
  OptimisticQueue({
    required this.capture,
    required this.restore,
    required this.notify,
  });
  final S Function() capture;
  final void Function(S) restore;
  final void Function() notify;
  final _pending = <_Edit>[];
  S? _confirmed;
  bool _running = false, _disposed = false;
  S? get confirmed => _confirmed;
  bool get isBusy => _pending.isNotEmpty;

  Future<void> run<T>({
    required void Function() apply,
    required Future<T> Function() send,
    void Function(T)? reconcile,
  }) {
    if (_disposed) return Future.error(MutationCancelled());
    final before = capture();
    if (_pending.isEmpty) _confirmed = before;
    final edit = _Edit(
      apply,
      () async => await send(),
      (value) => reconcile?.call(value as T),
    );
    try {
      apply();
    } catch (error, stack) {
      restore(before);
      if (_pending.isEmpty) _confirmed = null;
      return Future.error(error, stack);
    }
    _pending.add(edit);
    // Callers still receive errors; this also handles cancellation when the
    // screen owning a request has already been disposed.
    edit.done.future.ignore();
    notify();
    if (!_running) unawaited(_drain());
    return edit.done.future;
  }

  Future<void> _drain() async {
    _running = true;
    while (_pending.isNotEmpty && !_disposed) {
      final edit = _pending.first;
      Object? response, failure;
      StackTrace? stack;
      try {
        response = await edit.send();
      } catch (error, trace) {
        failure = error;
        stack = trace;
      }
      if (_disposed) return;
      restore(_confirmed!);
      if (failure == null) {
        try {
          edit.apply();
          edit.reconcile(response);
          _confirmed = capture();
        } catch (error, trace) {
          restore(_confirmed!);
          failure = error;
          stack = trace;
        }
      }
      _pending.removeAt(0);
      for (final pending in List<_Edit>.of(_pending)) {
        final before = capture();
        try {
          pending.apply();
        } catch (error, trace) {
          // For example, a lesson whose new group was rejected cannot be sent.
          restore(before);
          _pending.remove(pending);
          pending.done.completeError(error, trace);
        }
      }
      notify();
      if (failure == null) {
        edit.done.complete();
      } else {
        edit.done.completeError(failure, stack);
      }
    }
    _confirmed = null;
    _running = false;
  }

  void dispose() {
    _disposed = true;
    for (final edit in _pending) {
      if (!edit.done.isCompleted) edit.done.completeError(MutationCancelled());
    }
    _pending.clear();
  }
}

class _Edit {
  _Edit(this.apply, this.send, this.reconcile);
  final void Function() apply;
  final Future<Object?> Function() send;
  final void Function(Object?) reconcile;
  final done = Completer<void>();
}
