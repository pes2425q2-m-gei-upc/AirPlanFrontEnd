import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

void main() {
  // Leer archivo JSON como bytes
  final jsonFile = File('test-results.json');
  final Uint8List fileBytes = jsonFile.readAsBytesSync();

  // Decodificar los bytes como UTF-16 LE manualmente
  final String fileContent = decodeUtf16Le(fileBytes);

  // Dividir el contenido en líneas
  final lines = LineSplitter.split(fileContent);

  final passedTests = <String>[];
  final failedTests = <String>[];
  String? currentTestName;

  for (final line in lines) {
    // Ignorar líneas vacías o inválidas
    if (line.trim().isEmpty) {
      continue;
    }

    try {
      final data = jsonDecode(line);

      if (data['type'] == 'testStart') {
        currentTestName = data['test']['name'];
      } else if (data['type'] == 'testDone') {
        if (currentTestName != null) {
          if (data['result'] == 'success') {
            passedTests.add(currentTestName);
          } else {
            failedTests.add(currentTestName);
          }
        }
      }
    } catch (e) {
      // Ignorar líneas que no se puedan decodificar
      print('Línea no válida ignorada: $line');
    }
  }

  // Generar el contenido HTML
  final htmlContent = '''
  <!DOCTYPE html>
  <html>
  <head>
    <title>Resultados de Pruebas</title>
    <style>
      body { font-family: Arial, sans-serif; margin: 20px; }
      h1 { color: #333; }
      .section { margin-bottom: 30px; }
      .passed { color: green; }
      .failed { color: red; }
      .test { margin: 5px 0; padding: 5px; border-radius: 3px; }
      .stats { 
        background: #f5f5f5; 
        padding: 15px; 
        border-radius: 5px;
        margin-bottom: 20px;
      }
    </style>
  </head>
  <body>
    <h1>Reporte de Pruebas Unitarias</h1>
    
    <div class="stats">
      <h2>Estadísticas</h2>
      <p>Total pruebas: ${passedTests.length + failedTests.length}</p>
      <p class="passed">Pruebas exitosas: ${passedTests.length}</p>
      <p class="failed">Pruebas fallidas: ${failedTests.length}</p>
      <p>Tasa de éxito: ${((passedTests.length / (passedTests.length + failedTests.length)) * 100).toStringAsFixed(2)}%</p>
    </div>
    
    <div class="section">
      <h2 class="failed">Pruebas Fallidas (${failedTests.length})</h2>
      ${failedTests.map((test) => '<div class="test failed">✗ $test</div>').join()}
    </div>
    
    <div class="section">
      <h2 class="passed">Pruebas Exitosas (${passedTests.length})</h2>
      ${passedTests.map((test) => '<div class="test passed">✓ $test</div>').join()}
    </div>
  </body>
  </html>
  ''';

  // Guardar el reporte en un archivo HTML
  File('test-report.html').writeAsStringSync(htmlContent);
  print('Reporte generado en: test-report.html');
}

// Decodificar bytes de UTF-16 LE a String
String decodeUtf16Le(Uint8List bytes) {
  final codeUnits = Uint16List.view(bytes.buffer);
  return String.fromCharCodes(codeUnits);
}
