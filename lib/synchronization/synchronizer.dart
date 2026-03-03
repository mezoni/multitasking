abstract class Synchronizer {
  Future<void> acquire();

  Future<void> release();

  Future<bool> tryAcquire(Duration timeout);
}
