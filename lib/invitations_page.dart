import 'package:flutter/material.dart';

// Simulación de almacenamiento persistente
List<Map<String, String>> globalInvitations = [
  {"id": "1", "name": "Actividad 1"},
  {"id": "2", "name": "Actividad 2"},
];

class InvitationsPage extends StatefulWidget {
  const InvitationsPage({super.key});

  @override
  State<InvitationsPage> createState() => _InvitationsPageState();
}

class _InvitationsPageState extends State<InvitationsPage> {
  late List<Map<String, String>> invitations;

  @override
  void initState() {
    super.initState();
    // Cargar las invitaciones desde el almacenamiento global
    invitations = List.from(globalInvitations);
  }

  void _acceptInvitation(String id) {
    setState(() {
      invitations.removeWhere((invitation) => invitation["id"] == id);
      globalInvitations.removeWhere((invitation) => invitation["id"] == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Invitación aceptada")),
    );
  }

  void _rejectInvitation(String id) {
    setState(() {
      invitations.removeWhere((invitation) => invitation["id"] == id);
      globalInvitations.removeWhere((invitation) => invitation["id"] == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Invitación rechazada")),
    );
  }

  void _goToActivityDetails(String id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActivityDetailsPage(activityId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Invitaciones a Actividades"),
      ),
      body: invitations.isEmpty
          ? const Center(
        child: Text("No tienes invitaciones para unirte a actividades"),
      )
          : ListView.builder(
        itemCount: invitations.length,
        itemBuilder: (context, index) {
          final invitation = invitations[index];
          return ListTile(
            title: GestureDetector(
              onTap: () => _goToActivityDetails(invitation["id"]!),
              child: Text(
                invitation["name"]!,
                style: const TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () => _acceptInvitation(invitation["id"]!),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => _rejectInvitation(invitation["id"]!),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ActivityDetailsPage extends StatelessWidget {
  final String activityId;

  const ActivityDetailsPage({super.key, required this.activityId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Detalles de Actividad $activityId"),
      ),
      body: Center(
        child: Text("Detalles de la actividad con ID: $activityId"),
      ),
    );
  }
}