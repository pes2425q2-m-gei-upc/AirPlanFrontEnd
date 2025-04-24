import 'dart:io';

void main() async {
  final lcovFile = File('coverage/lcov.info');
  if (!await lcovFile.exists()) {
    print('Error: Primero ejecuta "flutter test --coverage"');
    exit(1);
  }

  final lines = await lcovFile.readAsLines();
  final htmlContent = generateHtml(lines);

  await Directory('coverage/html').create(recursive: true);
  await File('coverage/html/index.html').writeAsString(htmlContent);
  print('Reporte HTML generado en: coverage/html/index.html');
}

String generateHtml(List<String> lcovLines) {
  final buffer =
      StringBuffer()..writeln('''
<!DOCTYPE html>
<html>
<head>
  <title>Cobertura de Pruebas</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 2em; }
    h1 { color: #333; }
    .file { margin-bottom: 2em; padding: 1em; border: 1px solid #ddd; }
    .covered { color: green; }
    .uncovered { color: red; }
    table { border-collapse: collapse; width: 100%; }
    th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }
  </style>
</head>
<body>
  <h1>Reporte de Cobertura</h1>
''');

  String currentFile = '';
  for (final line in lcovLines) {
    if (line.startsWith('SF:')) {
      currentFile = line.substring(3);
      buffer.writeln(
        '<div class="file"><h2>${currentFile.replaceAll('\\', '/')}</h2>',
      );
    } else if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      final lineNumber = parts[0];
      final hits = int.parse(parts[1]);
      buffer.writeln(
        hits > 0
            ? '<div class="covered">✓ Línea $lineNumber (ejecutada $hits veces)</div>'
            : '<div class="uncovered">✗ Línea $lineNumber</div>',
      );
    } else if (line == 'end_of_record') {
      buffer.writeln('</div>');
    }
  }

  buffer.writeln('</body></html>');
  return buffer.toString();
}
