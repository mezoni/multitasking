import 'package:multitasking/multitasking.dart';
import 'package:multitasking/work/work.dart';
import 'package:test/test.dart';

void main() {
  _testExecutionContext();
}

Future<void> _delay(int milliseconds) {
  return Future.delayed(Duration(milliseconds: milliseconds));
}

void _testExecutionContext() {
  test('ExecutionContext: result', () async {
    Future<int> f() async {
      return 42;
    }

    Object? result;
    Object? error;
    final context = Work.create(f);
    try {
      result = await context.run();
    } catch (e) {
      error = e;
    }

    expect(error, isNull, reason: 'error');
    expect(result, equals(42), reason: 'result');
  });

  test('ExecutionContext: terminate using token', () async {
    Future<int> f() async {
      final token = Task.token;
      for (var i = 0; i < 10; i++) {
        await _delay(100);
        token.throwIfCanceled();
      }

      return 42;
    }

    Object? result;
    Object? error;
    final cts = CancellationTokenSource(Duration(milliseconds: 100));
    final context = Work.create(f, token: cts.token);
    try {
      result = await context.run();
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
    expect(result, isNull, reason: 'result');
  });
}
