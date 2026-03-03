import 'dart:collection';

import 'package:multitasking/multitasking.dart';
import 'package:multitasking/synchronization/binary_semaphore.dart';
import 'package:multitasking/synchronization/condition_variable.dart';

Future<void> main(List<String> args) async {
  final lock = BinarySemaphore();
  final notEmpty = ConditionVariable(lock);
  final notFull = ConditionVariable(lock);
  const capacity = 4;
  final products = Queue<int>();
  var productId = 0;
  var produced = 0;
  var consumed = 0;
  const count = 3;

  final producer = Task.run(name: 'producer', () async {
    for (var i = 0; i < count; i++) {
      await Future<void>.delayed(Duration(milliseconds: 50));
      final product = productId++;
      produced++;
      _message('produced: $product');
      _message('lock.acquire()');
      await lock.acquire();
      _message('lock.acquired)');
      try {
        while (products.length == capacity) {
          _message('notFull.wait()');
          await notFull.wait();
        }

        _message('added product: $product');
        products.add(product);
        _message('products: $products');
        _message('notEmpty.notifyAll()');
        await notEmpty.notifyAll();
      } finally {
        _message('lock.release()');
        await lock.release();
      }
    }
  });

  final consumer = Task.run(name: 'consumer', () async {
    for (var i = 0; i < count; i++) {
      int? product;
      _message('lock.acquire()');
      await lock.acquire();
      _message('lock.acquired');
      try {
        while (products.isEmpty) {
          _message('notEmpty.wait()');
          await notEmpty.wait();
        }

        product = products.removeFirst();
        _message('removed product: $product');
        _message('products: $products');
        _message('notFull.notifyAll()');
        await notFull.notifyAll();
      } finally {
        _message('lock.release()');
        await lock.release();
      }

      await Future<void>.delayed(Duration(milliseconds: 200));
      _message('consumed product: $product');
      consumed++;
    }
  });

  await Task.waitAll([consumer, producer]);

  _message('produced: $produced');
  _message('consumed: $consumed');
}

void _message(String text) {
  print('${Task.current}: $text');
}
