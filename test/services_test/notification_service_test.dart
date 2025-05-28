import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airplan/services/notification_service.dart';

void main() {
  late NotificationService service;
  late BuildContext testContext;

  setUp(() {
    service = NotificationService();
  });

  Future<void> pumpTestApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            testContext = context;
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );
  }

  testWidgets('showSuccess displays a green notification and auto-dismisses', (
    tester,
  ) async {
    await pumpTestApp(tester);

    service.showSuccess(testContext, 'Success!');

    // Begin animation in
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // animation in

    // Notification should be visible
    final textFinder = find.text('Success!');
    expect(textFinder, findsOneWidget);
    final container = tester.widget<Container>(
      find.ancestor(of: textFinder, matching: find.byType(Container)),
    );
    expect((container.decoration as BoxDecoration).color, Colors.green);

    // Wait for auto-dismiss timer and reverse animation
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300)); // animation out

    expect(find.text('Success!'), findsNothing);
  });

  testWidgets('showError displays a red notification', (tester) async {
    await pumpTestApp(tester);
    service.showError(testContext, 'Error occurred');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Error occurred'), findsOneWidget);
    final container = tester.widget<Container>(
      find.ancestor(
        of: find.text('Error occurred'),
        matching: find.byType(Container),
      ),
    );
    expect((container.decoration as BoxDecoration).color, Colors.red);
    // Auto-dismiss after duration
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Error occurred'), findsNothing);
  });

  testWidgets('showInfo displays a blue notification', (tester) async {
    await pumpTestApp(tester);
    service.showInfo(testContext, 'Info message');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Info message'), findsOneWidget);
    final container = tester.widget<Container>(
      find.ancestor(
        of: find.text('Info message'),
        matching: find.byType(Container),
      ),
    );
    expect((container.decoration as BoxDecoration).color, Colors.blue);
    // Auto-dismiss after duration
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Info message'), findsNothing);
  });

  testWidgets('showWarning displays an amber notification', (tester) async {
    await pumpTestApp(tester);
    NotificationService.showWarning(testContext, 'Warning!');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Warning!'), findsOneWidget);
    final container = tester.widget<Container>(
      find.ancestor(
        of: find.text('Warning!'),
        matching: find.byType(Container),
      ),
    );
    expect((container.decoration as BoxDecoration).color, Colors.amber);
    // Auto-dismiss after duration
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Warning!'), findsNothing);
  });

  testWidgets('manually tap close dismisses the notification', (tester) async {
    await pumpTestApp(tester);
    service.showSuccess(testContext, 'TapClose');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('TapClose'), findsOneWidget);
    // Tap close icon
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('TapClose'), findsNothing);
  });
  testWidgets('notificaciones con mensajes largos se muestran correctamente', (tester) async {
    await pumpTestApp(tester);

    const mensajeLargo = 'Este es un mensaje de notificación muy largo que debería'
        ' ajustarse correctamente dentro del contenedor de la notificación sin'
        ' sobrepasar los límites de la pantalla y manteniendo una buena legibilidad';

    service.showInfo(testContext, mensajeLargo);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(mensajeLargo), findsOneWidget);

    // Verificar que el contenedor tiene el Flexible widget para manejar texto largo
    final textWidget = tester.widget<Text>(find.text(mensajeLargo));
    expect(
        find.ancestor(of: find.byWidget(textWidget), matching: find.byType(Flexible)),
        findsOneWidget
    );

    // Auto-dismiss después del tiempo
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(mensajeLargo), findsNothing);
  });

  testWidgets('múltiples notificaciones se muestran apiladas correctamente', (tester) async {
    await pumpTestApp(tester);

    // Mostrar varias notificaciones
    service.showSuccess(testContext, 'Primera notificación');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    service.showInfo(testContext, 'Segunda notificación');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    service.showError(testContext, 'Tercera notificación');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verificar que las tres notificaciones están visibles
    expect(find.text('Primera notificación'), findsOneWidget);
    expect(find.text('Segunda notificación'), findsOneWidget);
    expect(find.text('Tercera notificación'), findsOneWidget);

    // Verificar diferentes colores para cada notificación
    final containers = tester.widgetList<Container>(
        find.byWidgetPredicate((widget) =>
        widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color != null
        )
    );

    final colors = containers.map((c) => (c.decoration as BoxDecoration).color).toList();
    expect(colors.contains(Colors.green), isTrue);
    expect(colors.contains(Colors.blue), isTrue);
    expect(colors.contains(Colors.red), isTrue);
  });

  testWidgets('animaciones de entrada y salida funcionan correctamente', (tester) async {
    await pumpTestApp(tester);

    service.showSuccess(testContext, 'Notificación con animación');

    // Verificar animación de entrada (inicio)
    await tester.pump();
    var opacityWidget = tester.widget<FadeTransition>(
        find.byType(FadeTransition)
    );
    expect(opacityWidget.opacity.value, lessThan(1.0));

    // Verificar animación de entrada (completada)
    await tester.pump(const Duration(milliseconds: 300));
    opacityWidget = tester.widget<FadeTransition>(
        find.byType(FadeTransition)
    );
    expect(opacityWidget.opacity.value, equals(1.0));

    // Cerrar manualmente
    await tester.tap(find.byIcon(Icons.close));

    // Verificar que el widget se ha eliminado
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Notificación con animación'), findsNothing);
  });
}
