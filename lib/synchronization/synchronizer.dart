import 'package:meta/meta.dart';

abstract class Synchronizer {
  Future<void> acquire();

  Future<void> release();

  @useResult
  Future<bool> tryAcquire(Duration timeout);
}
