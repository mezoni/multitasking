import 'package:multitasking/misc/countdown_timer.dart';
import 'package:test/test.dart';

void main() {
  _testCountdownTimer();
}

Future<void> _delay(int ms) {
  return Future.delayed(Duration(milliseconds: ms));
}

void _testCountdownTimer() {
  test('CountdownTimer: start() and stop()', () async {
    final t = CountdownTimer(Duration(seconds: 10), () {
      //
    });

    t.start();
    t.stop();
    final elapsedMicroseconds = t.elapsedMicroseconds;
    final remainingMicroseconds = t.remainingMicroseconds;
    expect(elapsedMicroseconds == t.elapsedMicroseconds, true,
        reason: 'elapsedMicroseconds != t.elapsedMicroseconds');
    expect(remainingMicroseconds == t.remainingMicroseconds, true,
        reason: 'remainingMicroseconds != t.remainingMicroseconds');
    t.start();
    expect(elapsedMicroseconds != t.elapsedMicroseconds, true,
        reason: 'elapsedMicroseconds == t.elapsedMicroseconds');
    expect(remainingMicroseconds != t.remainingMicroseconds, true,
        reason: 'remainingMicroseconds == t.remainingMicroseconds');
    t.cancel();
  });

  test('CountdownTimer: cancel)', () async {
    var isCalled = false;
    final t = CountdownTimer(Duration(milliseconds: 500), () {
      isCalled = true;
    });

    t.start();
    t.cancel();
    final elapsedMicroseconds = t.elapsedMicroseconds;
    final remainingMicroseconds = t.remainingMicroseconds;
    expect(elapsedMicroseconds == t.elapsedMicroseconds, true,
        reason: 'elapsedMicroseconds != t.elapsedMicroseconds');
    expect(remainingMicroseconds == t.remainingMicroseconds, true,
        reason: 'remainingMicroseconds != t.remainingMicroseconds');
    await _delay(750);
    expect(elapsedMicroseconds == t.elapsedMicroseconds, true,
        reason: 'elapsedMicroseconds != t.elapsedMicroseconds');
    expect(remainingMicroseconds == t.remainingMicroseconds, true,
        reason: 'remainingMicroseconds != t.remainingMicroseconds');
    expect(elapsedMicroseconds == t.elapsedMicroseconds, true,
        reason: 'elapsedMicroseconds != t.elapsedMicroseconds');
    expect(isCalled, false, reason: 'isCalled != false');
  });

  test('CountdownTimer: reset()', () async {
    var t = CountdownTimer(Duration(seconds: 10), () {});
    t.start();
    await _delay(500);
    final elapsedMicroseconds = t.elapsedMicroseconds;
    final remainingMicroseconds = t.remainingMicroseconds;
    t.reset();
    expect(elapsedMicroseconds > t.elapsedMicroseconds, true,
        reason: 'elapsedMicroseconds <=t.elapsedMicroseconds');
    expect(remainingMicroseconds < t.remainingMicroseconds, true,
        reason: 'remainingMicroseconds >= t.remainingMicroseconds');
    t.cancel();
    var isCalled = false;
    t = CountdownTimer(Duration(milliseconds: 500), () {
      isCalled = true;
    });
    t.start();
    await _delay(400);
    t.reset();
    await _delay(400);
    expect(isCalled, false, reason: 'isCalled != false');
    await _delay(400);
    expect(isCalled, true, reason: 'isCalled != true');
  });

  test('CountdownTimer: elapsedMicroseconds and remainingMicroseconds',
      () async {
    final t = CountdownTimer(Duration(milliseconds: 250), () {});
    t.start();
    await _delay(300);
    expect(t.elapsedMicroseconds, 250 * 1000,
        reason: 't.elapsedMicroseconds != 250 * 1000');
    expect(t.remainingMicroseconds, 0, reason: 't.remainingMicroseconds != 0');
  });

  test('CountdownTimer: set duration', () async {
    var t = CountdownTimer(Duration(milliseconds: 250), () {});
    t.start();
    t.duration = Duration(milliseconds: 350);
    await _delay(450);
    var elapsedMicroseconds = t.elapsedMicroseconds;
    expect(elapsedMicroseconds, 350 * 1000,
        reason: 'elapsedMicroseconds != 350 * 1000');
    expect(t.remainingMicroseconds, 0, reason: 't.remainingMicroseconds != 0');

    t = CountdownTimer(Duration(milliseconds: 250), () {});
    t.start();
    t.duration = Duration(milliseconds: 150);
    await _delay(250);
    elapsedMicroseconds = t.elapsedMicroseconds;
    expect(elapsedMicroseconds, 150 * 1000,
        reason: 'elapsedMicroseconds != 150 * 1000');
    expect(t.remainingMicroseconds, 0, reason: 't.remainingMicroseconds != 0');

    t = CountdownTimer(Duration(milliseconds: 150), () {});
    t.start();
    await _delay(10);
    t.duration = Duration(milliseconds: 1);
    await _delay(75);
    elapsedMicroseconds = t.elapsedMicroseconds;
    expect(elapsedMicroseconds > 1 * 1000 && elapsedMicroseconds < 150 * 1000,
        true,
        reason:
            'elapsedMicroseconds <= 1 * 1000 || elapsedMicroseconds >= 150 * 1000');
    expect(t.remainingMicroseconds == 0, true,
        reason: 't.remainingMicroseconds != 0');
  });
}
