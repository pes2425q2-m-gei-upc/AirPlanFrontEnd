import 'package:flutter/material.dart';
import 'invitations_service.dart';

class InvitationsPage extends StatefulWidget {
  final String username;

  const InvitationsPage({super.key, required this.username});

  @override
  State<InvitationsPage> createState() => _InvitationsPageState();
}

class _InvitationsPageState extends State<InvitationsPage> {
  late Future<List<Map<String, dynamic>>> _invitationsFuture;

  @override
  void initState() {
    super.initState();
    _invitationsFuture = InvitationsService.fetchInvitations(widget.username);
  }

  // Acceptar una invitació
  Future<void> _acceptInvitation(int activityId) async {
    try {
      await InvitationsService.acceptInvitation(activityId, widget.username);
      setState(() {
        _invitationsFuture = InvitationsService.fetchInvitations(widget.username);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitación aceptada')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al aceptar la invitación')),
      );
    }
  }

  // Rebutjar una invitació
  Future<void> _rejectInvitation(int activityId) async {
    try {
      await InvitationsService.rejectInvitation(activityId, widget.username);
      setState(() {
        _invitationsFuture = InvitationsService.fetchInvitations(widget.username);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitación rechazada')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al rechazar la invitación')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invitaciones a Actividades'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _invitationsFuture,
        builder: (context, snapshot) {
          print('Snapshot error: $snapshot.hasEerror');
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar las invitaciones'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No tienes invitaciones para unirte a actividades'),
            );
          }

          if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
            final invitations = snapshot.data!;
            return ListView.builder(
              itemCount: invitations.length,
              itemBuilder: (context, index) {
                final invitation = invitations[index];
                return ListTile(
                  title: Text(invitation['nom'] ?? 'Sin nombre'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => _acceptInvitation(invitation['id']),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => _rejectInvitation(invitation['id']),
                      ),
                    ],
                  ),
                );
              },
            );
          } else {
            return const Center(
              child: Text('No tienes invitaciones para unirte a actividades'),
            );
          }
        },
      ),
    );
  }
}