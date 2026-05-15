import 'dart:convert';
import 'dart:io';

void main() async {
  final pathSeparator = Platform.pathSeparator;
  final exclude = [
    'test/isolated_work_test.dart',
    'test/task_finalizer_test.dart',
  ].map((e) {
    return e.replaceAll('/', pathSeparator);
  });
  final files = Directory('test')
      .listSync()
      .where((e) => e.statSync().type == FileSystemEntityType.file)
      .map((e) => e.path)
      .where((e) => !exclude.contains(e))
      .toList();
  files.sort();
  for (final file in files) {
    print('Test: $file');
    final process = await Process.start(
      'dart',
      ['test', '-p', 'chrome', file],
    );
    process.stdout.transform(utf8.decoder).listen(stdout.write);
    process.stderr.transform(utf8.decoder).listen(stderr.write);
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw StateError('Test failed: $file');
    }
  }
}
