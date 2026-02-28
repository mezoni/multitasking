import 'dart:io';

Future<void> main(List<String> args) async {
  const repo = 'https://github.com/mezoni/multitasking/blob/main';
  const inputPath = 'tool/README.in.md';
  const outputPath = 'README.md';
  var contents = File(inputPath).readAsStringSync();
  final exampleRe = RegExp(
      '(?<=BEGIN_EXAMPLE)(((?!END_EXAMPLE).)*)(?=END_EXAMPLE)',
      dotAll: true);
  for (final match in exampleRe.allMatches(contents)) {
    final body = match.group(0)!.trim();
    final path = 'example/$body.dart';
    final code = File(path).readAsStringSync();
    print('Running: $path');
    final process = await Process.start(Platform.executable, [path]);
    final output = <String>[];
    process.stdout.listen((event) {
      output.add(String.fromCharCodes(event));
    });
    process.stderr.listen((event) {
      output.add(String.fromCharCodes(event));
    });

    await process.exitCode;
    final from = '''
BEGIN_EXAMPLE
$body
END_EXAMPLE''';

    contents = contents.replaceAll(from, '''
[$path]($repo/$path)

```dart
$code
```

Output:

```txt
${output.join('')}
```''');
  }

  File(outputPath).writeAsStringSync(contents);
}

void main_(List<String> args) {
  const inputPath = 'tool/README.in.md';
  const outputPath = 'README.md';
  var contents = File(inputPath).readAsStringSync();
  final exampleRe = RegExp(
      '(?<=BEGIN_EXAMPLE)(((?!END_EXAMPLE).)*)(?=END_EXAMPLE)',
      dotAll: true);
  for (final match in exampleRe.allMatches(contents)) {
    final body = match.group(0)!.trim();
    final path = 'example/$body.dart';
    final code = File(path).readAsStringSync();
    print('Running: $path');
    final process = Process.runSync(Platform.executable, [path]);
    final output = process.stdout;
    final from = '''
BEGIN_EXAMPLE
$body
END_EXAMPLE''';

    contents = contents.replaceAll(from, '''
```dart
$code
```

Output:

```txt
$output
```''');
  }

  File(outputPath).writeAsStringSync(contents);
}
