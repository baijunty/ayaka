import 'dart:async';

class Debounce {
  Timer? _timer;
  Debounce({Timer? timer}) : _timer = timer;

  Future<T> runDebounce<T>(FutureOr<T> Function() run, {Duration? duration}) {
    if (_timer?.isActive ?? false) _timer?.cancel();
    Completer<T> completer = Completer();
    _timer = Timer(duration ?? const Duration(milliseconds: 500), () async {
      try {
        var v = await run();
        completer.complete(v);
      } catch (e) {
        completer.completeError(e);
      }
    });
    return completer.future;
  }

  void dispose() {
    _timer?.cancel();
  }
}
