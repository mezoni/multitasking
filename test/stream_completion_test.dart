import 'package:multitasking/multitasking.dart';
import 'package:test/test.dart';

void main() {
  group('StreamCompletion Tests', () {
    late StreamCompletion completion;

    setUp(() {
      completion = StreamCompletion();
    });

    test('should return StreamStatusDone when onDone is triggered', () async {
      completion.onDone();
      completion.terminate();

      final status = await completion.wait();
      expect(status, isA<StreamStatusDone>());
    });

    test('should return StreamStatusCanceled when onCancel is triggered',
        () async {
      completion.onCancel();
      completion.terminate();

      final status = await completion.wait();
      expect(status, isA<StreamStatusCanceled>());
    });

    test('should return StreamStatusError when onError is triggered', () async {
      final exception = Exception('Test error');
      final trace = StackTrace.current;

      completion.onError(exception, trace);
      completion.onError(exception, trace);
      completion.terminate();

      final status = await completion.wait();
      expect(status, isA<StreamStatusError>());

      final errorStatus = status as StreamStatusError;
      expect(errorStatus.error, exception);
      expect(errorStatus.stackTrace, trace);
    });

    test(
        'should return StreamStatusDone when onDone is triggered after onError',
        () async {
      final exception = Exception('Test error');
      final trace = StackTrace.current;

      completion.onError(exception, trace);
      completion.onError(exception, trace);
      completion.onDone();
      completion.terminate();

      final status = await completion.wait();
      expect(status, isA<StreamStatusDone>());
    });

    test('should throw StateError if terminate is called without status', () {
      expect(() => completion.terminate(), throwsStateError);
    });

    test('should throw StateError if onDone triggered more than once', () {
      expect(() {
        completion.onDone();
        completion.onDone();
      }, throwsStateError);
    });

    test('should throw StateError if onCancel triggered more than once', () {
      expect(() {
        completion.onCancel();
        completion.onCancel();
      }, throwsStateError);
    });

    test('should throw StateError and become immutable after terminate()',
        () async {
      completion.onDone();
      completion.terminate();

      expect(() => completion.terminate(), throwsStateError);

      expect(() => completion.onCancel(), throwsStateError);
      expect(() => completion.onDone(), throwsStateError);
      expect(() => completion.onError(Exception(), StackTrace.empty),
          throwsStateError);
    });
  });

  test(
      'should return "canceled" when StreamStatusCanceled().toString() is called',
      () async {
    expect(StreamStatusCanceled().toString(), equals('canceled'));
  });

  test('should return "done" when StreamStatusDone().toString() is called',
      () async {
    expect(StreamStatusDone().toString(), equals('done'));
  });

  test('should return "error" when StreamStatusDone().toString() is called',
      () async {
    expect(StreamStatusError(Exception(), StackTrace.empty).toString(),
        equals('error'));
  });
}
