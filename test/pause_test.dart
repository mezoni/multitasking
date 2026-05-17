import 'dart:async';

import 'package:multitasking/misc/pause.dart';
import 'package:multitasking/multitasking.dart';
import 'package:test/test.dart';

void main() {
  test('Pause token: runPausable()', () async {
    final pts = PauseTokenSource();
    final token = pts.token;
    final stream = Stream.periodic(const Duration(milliseconds: 100), (count) {
      return count;
    });

    var count = 0;
    final StreamSubscription<int> sub;
    sub = stream.listen((event) {
      count = event;
    });

    final completer = Completer<void>();
    unawaited(token.runPausable(sub.pause, sub.resume, () => completer.future));
    await Task.sleep(500);
    await pts.pause();
    final count2 = count;
    await Task.sleep(500);
    expect(count, equals(count2), reason: 'pause does not works');
    await pts.resume();
    await Task.sleep(500);
    expect(count, isNot(count2), reason: 'resume does not works');
    await sub.cancel();
    completer.complete();
  });

  test('PauseToken: wait()', () async {
    final pts = PauseTokenSource();
    final token = pts.token;
    var cancel = false;
    var count = 0;
    unawaited(() async {
      while (!cancel) {
        count++;
        await Task.sleep(100);
        await token.wait();
      }
    }());

    await Task.sleep(500);
    await pts.pause();
    final count2 = count;
    await Task.sleep(500);
    expect(count, equals(count2), reason: 'pause does not works');
    await pts.resume();
    await Task.sleep(500);
    expect(count, isNot(count2), reason: 'resume does not works');
    cancel = true;
  });

  test('PauseToken: wait(token)', () async {
    final cts = CancellationTokenSource();
    final token = cts.token;
    final pts = PauseTokenSource();
    final pause = pts.token;
    await pts.pause();
    Timer(Duration(milliseconds: 500), cts.cancel);
    Object? error;
    try {
      await pause.wait(token: token);
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
  });

  test('PauseToken: isPaused', () async {
    final pts = PauseTokenSource();
    final token = pts.token;
    expect(token.isPaused, isFalse, reason: 'token.isPaused');
    await pts.pause();
    expect(token.isPaused, isTrue, reason: 'token.isPaused');
    await pts.resume();
    expect(token.isPaused, isFalse, reason: 'token.isPaused');
  });
}
