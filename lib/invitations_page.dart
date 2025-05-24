import 'package:easy_localization/easy_localization.dart';
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
        _invitationsFuture = InvitationsService.fetchInvitations(
          widget.username,
        );
      });
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(
          actualContext,
        ).showSnackBar(SnackBar(content: Text('invitation_accepted'.tr())));
      }
    } catch (e) {
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(actualContext).showSnackBar(
          SnackBar(content: Text('error_accepting_invitation'.tr())),
        );
      }
    }
  }

  // Rebutjar una invitació
  Future<void> _rejectInvitation(int activityId) async {
    try {
      await InvitationsService.rejectInvitation(activityId, widget.username);
      setState(() {
        _invitationsFuture = InvitationsService.fetchInvitations(
          widget.username,
        );
      });
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(
          actualContext,
        ).showSnackBar(SnackBar(content: Text('invitation_rejected'.tr())));
      }
    } catch (e) {
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(actualContext).showSnackBar(
          SnackBar(content: Text('error_rejecting_invitation'.tr())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('activity_invitations_title'.tr())),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _invitationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('error_loading_invitations'.tr()));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('no_activity_invitations'.tr()));
          }

          if (snapshot.hasData &&
              snapshot.data != null &&
              snapshot.data!.isNotEmpty) {
            final invitations = snapshot.data!;
            return ListView.builder(
              itemCount: invitations.length,
              itemBuilder: (context, index) {
                final invitation = invitations[index];
                return ListTile(
                  title: Text(invitation['nom'] ?? 'unnamed_activity'.tr()),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => _acceptInvitation(invitation['id']),
                        tooltip: 'accept_invitation_tooltip'.tr(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => _rejectInvitation(invitation['id']),
                        tooltip: 'reject_invitation_tooltip'.tr(),
                      ),
                    ],
                  ),
                );
              },
            );
          } else {
            return Center(child: Text('no_activity_invitations'.tr()));
          }
        },
      ),
    );
  }
}
