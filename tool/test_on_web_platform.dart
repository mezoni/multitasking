import 'dart:convert';
import 'dart:io';

void main() async {
  final pathSeparator = Platform.pathSeparator;
  final exclude = ['test/isolated_work_test.dart'].map((e) {
    return e.replaceAll('/', pathSeparator);
  });
  for (final entity in Directory('test').listSync()) {
    final stat = entity.statSync();
    if (stat.type != FileSystemEntityType.file) {
      continue;
    }

    final path = entity.path;
    if (exclude.contains(path)) {
      continue;
    }

    print('Test: $path');
    final process = await Process.start(
      'dart',
      ['test', '-p', 'chrome', path],
    );
    process.stdout.transform(utf8.decoder).listen(stdout.write);
    process.stderr.transform(utf8.decoder).listen(stderr.write);
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw StateError('Test failed: ${entity.path}');
    }
  }
}
