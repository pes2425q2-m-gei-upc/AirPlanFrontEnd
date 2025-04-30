import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_helpers.dart';
import 'package:airplan/activity_details_page.dart'; // Asegúrate de importar la página correcta

void main() {
  setUp(() {
    // Inicializar los mocks antes de cada test
    FirebaseTestSetup.setupFirebaseMocks();
  });

  // Widget de prueba para ActivityDetailsPage
  Widget createActivityDetailsTestWidget({
    required bool isCreator, // Si es el creador o no
    bool showParticipantRemove = false, // Si se debe mostrar la opción de eliminar
    bool showParticipants = true, // Si los participantes están visibles
  }) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text("Activity Details")),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ActivityDetailsPage(
            isCreator: isCreator,
            showParticipantRemove: showParticipantRemove,
            showParticipants: showParticipants,
          ),
        ),
      ),
    );
  }

  testWidgets('Only creator can remove participants', (WidgetTester tester) async {
    // El creador puede eliminar participantes
    await tester.pumpWidget(createActivityDetailsTestWidget(
      isCreator: true,
      showParticipantRemove: true,
      showParticipants: true,
    ));

    // Verificar que el ícono de eliminar esté presente
    expect(find.byIcon(Icons.delete), findsNWidgets(2)); // Se espera que haya dos íconos de eliminar

    // Ahora probamos con un usuario que no es creador
    await tester.pumpWidget(createActivityDetailsTestWidget(
      isCreator: false,
      showParticipantRemove: false,
      showParticipants: true,
    ));

    // Verificar que el ícono de eliminar no esté presente
    expect(find.byIcon(Icons.delete), findsNothing); // No debe haber íconos de eliminar
  });

  testWidgets('Participant can see participants but cannot remove', (WidgetTester tester) async {
    await tester.pumpWidget(createActivityDetailsTestWidget(
      isCreator: false,
      showParticipantRemove: false,
      showParticipants: true,
    ));

    // Verificar que los participantes se muestran
    expect(find.text('Participants:'), findsOneWidget);
    expect(find.text('Participant 1'), findsOneWidget);
    expect(find.text('Participant 2'), findsOneWidget);

    // Verificar que no hay íconos de eliminar
    expect(find.byIcon(Icons.delete), findsNothing);
  });

  testWidgets('Creator can see and remove participants', (WidgetTester tester) async {
    await tester.pumpWidget(createActivityDetailsTestWidget(
      isCreator: true,
      showParticipantRemove: true,
      showParticipants: true,
    ));

    // Verificar que el creador puede ver y eliminar
    expect(find.byIcon(Icons.delete), findsNWidgets(2)); // Deberían aparecer los íconos de eliminar
  });

  // Test para verificar la visibilidad de participantes
  testWidgets('Creator and participant can hide/show participants list', (WidgetTester tester) async {
    // El creador puede ocultar/mostrar participantes
    await tester.pumpWidget(createActivityDetailsTestWidget(
      isCreator: true,
      showParticipantRemove: true,
      showParticipants: true,
    ));

    // Verificar que los participantes están inicialmente visibles
    expect(find.text('Participants:'), findsOneWidget);
    expect(find.text('Participant 1'), findsOneWidget);
    expect(find.text('Participant 2'), findsOneWidget);

    // Tapear el botón de ocultar participantes
    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pump();

    // Verificar que los participantes se ocultaron
    expect(find.text('Participants:'), findsNothing);
    expect(find.text('Participant 1'), findsNothing);
    expect(find.text('Participant 2'), findsNothing);

    // Ahora, mostrar nuevamente los participantes
    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pump();

    // Verificar que los participantes se muestran de nuevo
    expect(find.text('Participants:'), findsOneWidget);
    expect(find.text('Participant 1'), findsOneWidget);
    expect(find.text('Participant 2'), findsOneWidget);
  });

  // Test para eliminar un participante
  testWidgets('Creator can remove a participant from the list', (WidgetTester tester) async {
    // El creador ve la lista de participantes
    await tester.pumpWidget(createActivityDetailsTestWidget(
      isCreator: true,
      showParticipantRemove: true,
      showParticipants: true,
    ));

    // El creador elimina a un participante
    await tester.tap(find.byIcon(Icons.delete).first);
    await tester.pump();

    // Verificar que el participante eliminado ya no está en la lista
    expect(find.text('Participant 1'), findsNothing); // "Participant 1" ha sido eliminado
    expect(find.text('Participant 2'), findsOneWidget); // "Participant 2" sigue en la lista
  });
}

class ActivityDetailsPage extends StatefulWidget {
  final bool isCreator;
  final bool showParticipantRemove;
  final bool showParticipants;

  const ActivityDetailsPage({
    Key? key,
    required this.isCreator,
    required this.showParticipantRemove,
    required this.showParticipants,
  }) : super(key: key);

  @override
  _ActivityDetailsPageState createState() => _ActivityDetailsPageState();
}

class _ActivityDetailsPageState extends State<ActivityDetailsPage> {
  List<String> participants = ['Participant 1', 'Participant 2'];
  bool showParticipants = true;

  @override
  void initState() {
    super.initState();
    showParticipants = widget.showParticipants;
  }

  void toggleParticipantsVisibility() {
    setState(() {
      showParticipants = !showParticipants;
    });
  }

  void removeParticipant(String participant) {
    setState(() {
      participants.remove(participant);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Opción para ocultar/mostrar participantes
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: Icon(showParticipants ? Icons.visibility : Icons.visibility_off),
              onPressed: toggleParticipantsVisibility,
            ),
          ],
        ),
        // Mostrar participantes si showParticipants es true
        if (showParticipants)
          Column(
            children: [
              Text('Participants:', style: TextStyle(fontSize: 16)),
              if (widget.isCreator)
                ...participants.map((participant) {
                  return ListTile(
                    title: Text(participant),
                    trailing: widget.showParticipantRemove
                        ? IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () {
                        removeParticipant(participant);
                      },
                    )
                        : null,
                  );
                }).toList(),
              if (!widget.isCreator)
                ...participants.map((participant) {
                  return ListTile(
                    title: Text(participant),
                    trailing: null, // Los participantes no pueden eliminar
                  );
                }).toList(),
            ],
          ),
      ],
    );
  }
}

