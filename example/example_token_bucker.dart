import 'dart:async';
import 'dart:io';

import 'package:multitasking/misc/speed_meter.dart';
import 'package:multitasking/misc/token_bucket.dart';

void main() {
  final meter = SpeedMeter();
  final bucket = TokenBucket(capacity: 1, rate: 100);
  var allowed = 0;
  var rejected = 0;
  meter.resume();
  Timer.periodic(Duration(milliseconds: 1000), (timer) {
    final rate = meter.speed.toStringAsFixed(2);
    final sec = (meter.elapsedMicroseconds / 1e6).toStringAsFixed(2);
    stdout.write(
        '\r\x1b[2K$sec sec $allowed ops, rejected: $rejected ops, rate: $rate op/sec');
  });

  final list = <(int, int)>[];
  Timer.periodic(Duration(milliseconds: 1), (_) {
    if (bucket.allowRequest()) {
      meter.add(1);
      if (list.length <= 100) {
        //list.add((meter.elapsedMicroseconds, 1));
      } else {
        //print(meter.elapsedMicroseconds);
        //print(list.join('\n'));
      }

      allowed++;
    } else {
      rejected++;
    }
  });
}
