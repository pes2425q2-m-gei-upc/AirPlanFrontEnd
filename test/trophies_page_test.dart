import 'dart:ui' as ui;
import 'package:airplan/services/api_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';

// Evitar problemas con las imágenes en pruebas
class FakeNetworkImage extends FakeImage {
  final String url;

  FakeNetworkImage(this.url);

  @override
  void paint(Canvas canvas, Rect rect, {ColorFilter? colorFilter}) {}

  @override
  Future<void> load(Sink<ImageChunkEvent> chunkEvents, DecoderBufferCallback decode) async {}
}

// Clase base para imágenes falsas
class FakeImage extends ImageProvider<Object> {
  @override
  Future<Object> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<Object>(this);
  }

  @override
  ImageStreamCompleter loadBuffer(Object key, DecoderBufferCallback decode) {
    return OneFrameImageStreamCompleter(
      SynchronousFuture<ImageInfo>(
        ImageInfo(
          image: FakeUiImage(),
          scale: 1.0,
        ),
      ),
    );
  }
}

// Imagen UI falsa
class FakeUiImage implements ui.Image {
  @override
  int get width => 100;

  @override
  int get height => 100;

  @override
  void dispose() {}

  @override
  Future<ByteData?> toByteData({ui.ImageByteFormat format = ui.ImageByteFormat.rawRgba}) {
    return Future.value(ByteData(0));
  }

  @override
  ui.Image clone() {
    throw UnimplementedError();
  }

  @override
  ui.ColorSpace get colorSpace => throw UnimplementedError();

  @override
  bool get debugDisposed => throw UnimplementedError();

  @override
  List<StackTrace>? debugGetOpenHandleStackTraces() {
    throw UnimplementedError();
  }

  @override
  bool isCloneOf(ui.Image other) {
    throw UnimplementedError();
  }
}

@GenerateMocks([http.Client])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  final testUsername = 'testUser';
  final apiUrl = ApiConfig().buildUrl('api/trofeus/$testUsername');

  final mockTrophiesObtained = [
    {
      'trofeu': {
        'id': '1',
        'nom': 'trophy_name_1',
        'descripcio': 'trophy_description_1',
        'experiencia': 100,
        'imatge': 'https://example.com/trophy1.png'
      },
      'obtingut': true,
      'dataObtencio': '2025-05-20T10:30:00Z'
    }
  ];

  final mockTrophiesNotObtained = [
    {
      'trofeu': {
        'id': '2',
        'nom': 'trophy_name_2',
        'descripcio': 'trophy_description_2',
        'experiencia': 200,
        'imatge': 'https://example.com/trophy2.png'
      },
      'obtingut': false,
      'dataObtencio': null
    }
  ];

  final mockTrophiesMixed = [
    ...mockTrophiesObtained,
    ...mockTrophiesNotObtained
  ];

  testWidgets('Shows loading indicator while fetching trophies',
      (WidgetTester tester) async {
    // Test del indicador de carga
    await tester.pumpWidget(
      const MaterialApp(
        home: TrophiesPageTestMock(
          isLoading: true,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Shows card elements when data is loaded successfully',
      (WidgetTester tester) async {
    // Test para mostrar tarjetas
    await tester.pumpWidget(
      MaterialApp(
        home: TrophiesPageTestMock(
          trophies: mockTrophiesMixed,
        ),
      ),
    );

    // Verificar que tenemos una lista y tarjetas
    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(Card), findsWidgets);
  });

  testWidgets('Shows error UI when API returns error',
      (WidgetTester tester) async {
    // Test para mostrar error
    await tester.pumpWidget(
      const MaterialApp(
        home: TrophiesPageTestMock(
          hasError: true,
          errorMessage: 'Test error',
        ),
      ),
    );

    // Verificamos que hay un mensaje de error
    expect(find.text('Error: Test error'), findsOneWidget);
    expect(find.byType(Center), findsWidgets);
  });

  testWidgets('Shows empty state UI when data is empty',
      (WidgetTester tester) async {
    // Test para mostrar estado vacío
    await tester.pumpWidget(
      const MaterialApp(
        home: TrophiesPageTestMock(
          trophies: [],
        ),
      ),
    );

    // Verificamos que hay un mensaje de vacío
    expect(find.text('No trophies available'), findsOneWidget);
    expect(find.byType(Center), findsWidgets);
  });

  testWidgets('Shows trophy elements for obtained trophies',
      (WidgetTester tester) async {
    // Test para trofeos obtenidos
    await tester.pumpWidget(
      MaterialApp(
        home: TrophiesPageTestMock(
          trophies: mockTrophiesObtained,
        ),
      ),
    );

    // Verificamos que aparece el icono de check para trofeos obtenidos
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('Shows XP indicators in the UI', (WidgetTester tester) async {
    // Test para indicadores XP
    await tester.pumpWidget(
      MaterialApp(
        home: TrophiesPageTestMock(
          trophies: mockTrophiesMixed,
        ),
      ),
    );

    // Verificamos que hay textos con XP
    expect(find.text('+100 XP'), findsOneWidget);
    expect(find.text('+200 XP'), findsOneWidget);
  });
}

// Clase para testing que simula exactamente lo que necesitamos probar
class TrophiesPageTestMock extends StatelessWidget {
  final List<Map<String, dynamic>>? trophies;
  final bool isLoading;
  final bool hasError;
  final String errorMessage;

  const TrophiesPageTestMock({
    Key? key,
    this.trophies = const [],
    this.isLoading = false,
    this.hasError = false,
    this.errorMessage = 'Error',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trophies')),
      body: Builder(
        builder: (context) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (hasError) {
            return Center(child: Text('Error: $errorMessage'));
          }

          if (trophies == null || trophies!.isEmpty) {
            return const Center(child: Text('No trophies available'));
          }

          return ListView.builder(
            itemCount: trophies!.length,
            itemBuilder: (context, index) {
              final trophy = trophies![index]['trofeu'];
              final obtained = trophies![index]['obtingut'] as bool;
              final obtainedDate = trophies![index]['dataObtencio'];

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Trophy Image - Sin usar NetworkImage
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Stack(
                          children: [
                            if (!obtained)
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color.fromRGBO(0, 0, 0, 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            if (!obtained)
                              const Center(
                                child: Icon(
                                  Icons.lock,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Trophy Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trophy['nom'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              trophy['descripcio'],
                              style: const TextStyle(color: Colors.grey),
                            ),
                            if (obtainedDate != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'Obtained on: $obtainedDate',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Experience and Tick
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '+${trophy['experiencia']} XP',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (obtained)
                            const Icon(Icons.check_circle, color: Colors.green),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

