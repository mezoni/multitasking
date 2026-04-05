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

    unawaited(token.runPausable(sub.pause, sub.resume, sub.asFuture<void>));

    await Task.sleep(500);
    await pts.pause();
    final count2 = count;
    await Task.sleep(500);
    expect(count == count2, true, reason: 'pause does not works');
    await pts.resume();
    await Task.sleep(500);
    expect(count != count2, true, reason: 'resume does not works');
    await sub.cancel();
  });

  test('PauseToken: waitWhilePaused()', () async {
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
    expect(count == count2, true, reason: 'pause does not works');
    await pts.resume();
    await Task.sleep(500);
    expect(count != count2, true, reason: 'resume does not works');
    cancel = true;
  });

  test('PauseToken: waitWhilePaused(token)', () async {
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

    expect(error, isA<TaskCanceledException>(), reason: 'error');
  });
}
